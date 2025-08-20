//
//  UploadManager+Auto.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 10/04/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Photos
import piwigoKit

extension UploadManager {
    
    // MARK: - Add Auto-Upload Requests
    public func appendAutoUploadRequests() {
        // Check access to Photo Library album
        let collectionID = UploadVars.shared.autoUploadAlbumId
        guard collectionID.isEmpty == false,
           let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [collectionID], options: nil).firstObject else {
            // Cannot access local album -> Reset album ID
            UploadVars.shared.autoUploadAlbumId = ""               // Unknown source Photos album

            // Delete remaining upload requests and inform user
            disableAutoUpload(withTitle: NSLocalizedString("settings_autoUploadSourceInvalid", comment:"Invalid source album"), message: NSLocalizedString("settings_autoUploadSourceInfo", comment: "Please select the album or sub-album from which photos and videos of your device will be auto-uploaded."))
            return
        }

        // Check existence of Piwigo album
        let categoryId = UploadVars.shared.autoUploadCategoryId
        guard categoryId != Int32.min else {
            // Cannot access Piwigo album -> Reset album ID
            UploadVars.shared.autoUploadCategoryId = Int32.min    // Unknown destination Piwigo album

            // Delete remaining upload requests and inform user
            disableAutoUpload(withTitle: NSLocalizedString("settings_autoUploadDestinationInvalid", comment:"Invalid destination album"), message: NSLocalizedString("settings_autoUploadSourceInfo", comment: "Please select the album or sub-album into which photos and videos will be auto-uploaded."))
            return
        }
        
        // Get new local images to be uploaded
        let uploadRequestsToAppend = getNewRequests(inCollection: collection, toBeUploadedIn: categoryId)
            .compactMap{ $0 }
        
        // Record upload requests in database
        uploadProvider.importUploads(from: uploadRequestsToAppend) { error in
            // Job done in background task
            if self.isExecutingBackgroundUploadTask { return }

            // Restart upload manager if no error
            guard let error = error else {
                // Restart UploadManager activities
                UploadManager.shared.backgroundQueue.async {
                    UploadManager.shared.isPaused = false
                    UploadManager.shared.findNextImageToUpload()
                }
                return
            }

            // Error encountered, inform user
            DispatchQueue.main.async {
                let userInfo: [String : Any] = ["message" : PwgKitError.uploadCreationError.localizedDescription,
                                                "errorMsg" : error.localizedDescription];
                NotificationCenter.default.post(name: .pwgAppendAutoUploadRequestsFailed,
                                                object: nil, userInfo: userInfo)
            }
        }
    }
    
    public func getNewRequests(inCollection collection: PHAssetCollection,
                               toBeUploadedIn categoryId: Int32) -> [UploadProperties] {
        // Collect IDs of images to upload
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeHiddenAssets = false
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: #keyPath(PHAsset.creationDate), ascending: false)]
        if NetworkVars.shared.serverFileTypes.contains("mp4") {
            fetchOptions.predicate = NSPredicate(format: "(mediaType == %d) || (mediaType == %d)", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        } else {
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        }
        let fetchedImages = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        if fetchedImages.count == 0 {
            // No new photos - Job done
            return [UploadProperties]()
        }

        // Collect localIdentifiers of uploaded and not yet uploaded images in the Upload cache
        var imageIDs = (uploads.fetchedObjects ?? []).map({$0.localIdentifier})
        imageIDs.append(contentsOf: (completed.fetchedObjects ?? []).map({$0.localIdentifier}))

        // Determine which local images are still not considered for upload
        var uploadRequestsToAppend = [UploadProperties]()
        fetchedImages.enumerateObjects { image, _, stop in
            // Keep images which had never been considered for upload
            if !imageIDs.contains(image.localIdentifier) {
                // Create upload request
                var uploadRequest = UploadProperties(localIdentifier: image.localIdentifier,
                                                     category: categoryId)
                uploadRequest.markedForAutoUpload = true
                uploadRequest.tagIds = UploadVars.shared.autoUploadTagIds
                uploadRequest.comment = UploadVars.shared.autoUploadComments
                uploadRequestsToAppend.append(uploadRequest)

                // Check if we have reached the max number of requests to append
                if uploadRequestsToAppend.count >= UploadManager.shared.maxNberOfAutoUploadsPerCheck {
                    stop.pointee = true
                }
            }
        }
        
        // Return properties of new upload requests
        return uploadRequestsToAppend
    }
    
    
    // MARK: - Delete Auto-Upload Requests
    @objc func stopAutoUploader(_ notification: Notification?) {
        disableAutoUpload()
    }
    
    public func disableAutoUpload(withTitle title:String = "", message:String = "") {
        // Something to do?
        if !UploadVars.shared.isAutoUploadActive { return }
        // Disable auto-uploading
        UploadVars.shared.isAutoUploadActive = false
        
        // If the Settings or Settings/AutoUpload view is displayed:
        /// - switch off Auto-Upload control
        /// - inform user in case of error
        if !self.isExecutingBackgroundUploadTask {
            DispatchQueue.main.async {
                let userInfo: [String : Any] = ["title"   : title,
                                                "message" : message];
                NotificationCenter.default.post(name: .pwgAutoUploadChanged,
                                                object: nil, userInfo: userInfo)
            }
        }

        // Remove non-completed upload requests marked for auto-upload from the upload queue
        let toDelete = (uploads.fetchedObjects ?? []).filter({$0.markedForAutoUpload == true})
        uploadProvider.delete(uploadRequests: toDelete) { [self] error in
            // Job done in background task
            if self.isExecutingBackgroundUploadTask { return }

            // Error encountered?
            guard let error = error else {
                // Restart UploadManager activities
                UploadManager.shared.backgroundQueue.async {
                    UploadManager.shared.isPaused = false
                    UploadManager.shared.findNextImageToUpload()
                }
                return
            }
            
            // Error encountered, inform user
            DispatchQueue.main.async {
                let userInfo: [String : Any] = ["message" : error.localizedDescription];
                NotificationCenter.default.post(name: .pwgAppendAutoUploadRequestsFailed,
                                                object: nil, userInfo: userInfo)
            }
        }
    }
}
