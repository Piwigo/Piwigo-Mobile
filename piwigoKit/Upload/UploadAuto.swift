//
//  UploadAuto.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 10/04/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Photos

extension UploadManager {
    
    // MARK: - Add Auto-Upload Requests
    public func appendAutoUploadRequests() {
        // Check access to Photo Library album
        let collectionID = UploadVars.autoUploadAlbumId
        guard !collectionID.isEmpty,
           let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [collectionID], options: nil).firstObject else {
            // Cannot access local album
            UploadVars.autoUploadAlbumId = ""               // Unknown source Photos album
            disableAutoUpload(withTitle: NSLocalizedString("settings_autoUploadSourceInvalid", comment:"Invalid source album"), message: NSLocalizedString("settings_autoUploadSourceInfo", comment: "Please select the album or sub-album from which photos and videos of your device will be auto-uploaded."))
            return
        }

        // Check existence of Piwigo album
        let categoryId = UploadVars.autoUploadCategoryId
        guard categoryId != NSNotFound else {
            // Cannot access local album
            UploadVars.autoUploadCategoryId = NSNotFound    // Unknown destination Piwigo album
            disableAutoUpload(withTitle: NSLocalizedString("settings_autoUploadDestinationInvalid", comment:"Invalid destination album"), message: NSLocalizedString("settings_autoUploadSourceInfo", comment: "Please select the album or sub-album into which photos and videos will be auto-uploaded."))
            return
        }
        
        // Collect IDs of images to upload
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeHiddenAssets = false
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetchedImages = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        if fetchedImages.count == 0 {
            // Nothing to add to the upload queue - Job done
            return
        }

        // Collect localIdentifiers of uploaded and not yet uploaded images in the Upload cache
        let states: [kPiwigoUploadState] = [.waiting, .preparing, .preparingError,
                                            .preparingFail, .formatError, .prepared,
                                            .uploading, .uploadingError, .uploaded,
                                            .finishing, .finishingError, .finished,
                                            .moderated, .deleted]
        let imageIDs = uploadsProvider.getRequests(inStates: states, markedForAutoUpload: true).0

        // Determine which local images are still not considered for upload
        var uploadRequestsToAppend = [UploadProperties]()
        fetchedImages.enumerateObjects { image, _, stop in
            // Keep images which had never been considered for upload
            if !imageIDs.contains(image.localIdentifier) {
                // Create upload request
                var uploadRequest = UploadProperties(localIdentifier: image.localIdentifier,
                                                     category: categoryId)
                uploadRequest.markedForAutoUpload = true
                uploadRequest.tagIds = UploadVars.autoUploadTagIds
                uploadRequest.comment = UploadVars.autoUploadComments
                uploadRequestsToAppend.append(uploadRequest)

                // Check if we have reached the max number of requests to append
                if uploadRequestsToAppend.count >= UploadManager.shared.maxNberAutoUploadPerCheck {
                    stop.pointee = true
                }
            }
        }
        
        // Are there images to upload?
        if uploadRequestsToAppend.count == 0 {
            // Nothing to add to the upload queue - Job done
            return
        }

        // Record upload requests in database
        uploadsProvider.importUploads(from: uploadRequestsToAppend.compactMap{ $0 }) { error in
            // Job done in background task
            if self.isExecutingBackgroundUploadTask { return }

            // Restart upload manager if no error
            guard let error = error else {
                // Restart UploadManager activities
                if UploadManager.shared.isPaused {
                    UploadManager.shared.isPaused = false
                    UploadManager.shared.backgroundQueue.async {
                        UploadManager.shared.findNextImageToUpload()
                    }
                }
                return
            }

            // Error encountered, inform user
            DispatchQueue.main.async {
                let userInfo: [String : Any] = ["message" : NSLocalizedString("CoreDataFetch_UploadCreateFailed",
                                                                              comment: "Failed to create a new Upload object."),
                                                "errorMsg" : error.localizedDescription];
                NotificationCenter.default.post(name: PwgNotifications.appendAutoUploadRequestsFailed,
                                                object: nil, userInfo: userInfo)
            }
        }
    }
    
    
    // MARK: - Delete Auto-Upload Requests
    public func disableAutoUpload(withTitle title:String = "", message:String = "") {
        // Disable auto-uploading
        UploadVars.isAutoUploadActive = false
        
        // If the Settings or Settings/AutoUpload view is displayed:
        /// - switch off Auto-Upload control
        /// - inform user in case of error
        DispatchQueue.main.async {
            let userInfo: [String : Any] = ["title"   : title,
                                            "message" : message];
            NotificationCenter.default.post(name: PwgNotifications.disableAutoUpload, object: nil, userInfo: userInfo)
        }

        // Collect objectIDs of images being considered for auto-uploading
        let states: [kPiwigoUploadState] = [.waiting, .preparingError,
                                            .preparingFail, .formatError, .prepared,
                                            .uploadingError, .uploaded,
                                            .finishingError]
        let objectIDs = uploadsProvider.getRequests(inStates: states, markedForAutoUpload: true).1

        // Remove non-completed upload requests marked for auto-upload from the upload queue
        if !objectIDs.isEmpty {
            uploadsProvider.delete(uploadRequests: objectIDs) { error in
                // Job done in background task
                if self.isExecutingBackgroundUploadTask { return }

                // Error encountered?
                guard let error = error else {
                    // Restart UploadManager activities
                    if UploadManager.shared.isPaused {
                        UploadManager.shared.isPaused = false
                        UploadManager.shared.backgroundQueue.async {
                            UploadManager.shared.findNextImageToUpload()
                        }
                    }
                    return
                }
                
                // Error encountered, inform user
                DispatchQueue.main.async {
                    let userInfo: [String : Any] = ["message" : error.localizedDescription];
                    NotificationCenter.default.post(name: PwgNotifications.appendAutoUploadRequestsFailed,
                                                    object: nil, userInfo: userInfo)
                }
            }
        }
    }
}
