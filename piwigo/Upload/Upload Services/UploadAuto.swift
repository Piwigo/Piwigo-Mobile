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
    func appendAutoUploadRequests() {
        // Check access to Photo Library album
        guard let collectionID = Model.sharedInstance()?.autoUploadAlbumId, !collectionID.isEmpty,
           let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [collectionID], options: nil).firstObject else {
            // Cannot access local album
            Model.sharedInstance().autoUploadAlbumId = ""               // Unknown source Photos album
            disableAutoUpload(withTitle: NSLocalizedString("settings_autoUploadSourceInvalid", comment:"Invalid source album"), message: NSLocalizedString("settings_autoUploadSourceInfo", comment: "Please select the album or sub-album from which photos and videos of your device will be auto-uploaded."))
            return
        }

        // Check existence of Piwigo album
        guard let categoryId = Model.sharedInstance()?.autoUploadCategoryId, categoryId != NSNotFound else {
            // Cannot access local album
            Model.sharedInstance().autoUploadCategoryId = NSNotFound    // Unknown destination Piwigo album
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
                                            .finishing, .finishingError, .finished, .moderated]
        let (imageIDs, _) = uploadsProvider.getAutoUploadRequestsIn(states: states)

        // Determine which local images are still not considered for upload
        var uploadRequestsToAppend = [UploadProperties]()
        fetchedImages.enumerateObjects { image, idx, stop in
            if !imageIDs.contains(image.localIdentifier) {
                var uploadRequest = UploadProperties(localIdentifier: image.localIdentifier,
                                                     category: categoryId)
                uploadRequest.markedForAutoUpload = true
                uploadRequest.tagIds = Model.sharedInstance()?.autoUploadTagIds ?? ""
                uploadRequest.comment = Model.sharedInstance()?.autoUploadComments ?? ""
                uploadRequestsToAppend.append(uploadRequest)
            }
        }
        
        // Are there images to upload?
        if uploadRequestsToAppend.count == 0 {
            // Nothing to add to the upload queue - Job done
            return
        }

        // Record upload requests in database
        self.uploadsProvider.importUploads(from: uploadRequestsToAppend.compactMap{ $0 }) { error in
            // Job done in background task
            if self.isExecutingBackgroundUploadTask { return }

            // Restart uploader if no error
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

            // Inform user
            DispatchQueue.main.async {
                // Look for the presented view controller
                if var topViewController = UIApplication.shared.keyWindow?.rootViewController {
                    while let presentedViewController = topViewController.presentedViewController {
                        topViewController = presentedViewController
                    }
                    topViewController.dismissPiwigoError(withTitle: NSLocalizedString("CoreDataFetch_UploadCreateFailed", comment: "Failed to create a new Upload object."), message: error.localizedDescription) {
                        // Restart UploadManager activities
                        if UploadManager.shared.isPaused {
                            UploadManager.shared.isPaused = false
                            UploadManager.shared.backgroundQueue.async {
                                UploadManager.shared.findNextImageToUpload()
                            }
                        }
                    }
                }
            }
        }
    }
    
    func disableAutoUpload(withTitle title:String = "", message:String = "") {
        // Disable auto-uploading
        Model.sharedInstance().isAutoUploadActive = false
        Model.sharedInstance().saveToDisk()
        
        // Collect objectIDs of images being considered for auto-uploading
        let states: [kPiwigoUploadState] = [.waiting, .preparingError,
                                            .preparingFail, .formatError, .prepared,
                                            .uploadingError, .uploaded,
                                            .finishingError]
        let (_, objectIDs) = uploadsProvider.getAutoUploadRequestsIn(states: states)

        // Remove waiting upload requests marked for auto-upload from the upload queue
        if !objectIDs.isEmpty {
            uploadsProvider.delete(uploadRequests: objectIDs)
        }

        // Job done in background task
        if isExecutingBackgroundUploadTask || title.isEmpty { return }
        
        // Look for the presented view controller
        DispatchQueue.main.async {
            if let topViewController = UIApplication.shared.keyWindow?.rootViewController,
               topViewController is UINavigationController,
               let visibleVC = (topViewController as! UINavigationController).visibleViewController,
               let autoUploadVC = visibleVC as? AutoUploadViewController {
                // Inform the user if needed
                autoUploadVC.dismissPiwigoError(withTitle: title, message: message) {
                    // Change switch button state
                    autoUploadVC.autoUploadTableView.reloadSections(IndexSet(integer: 0), with: .automatic)
                }
            } else {
                // Restart UploadManager activities
                if UploadManager.shared.isPaused {
                    UploadManager.shared.isPaused = false
                    UploadManager.shared.backgroundQueue.async {
                        UploadManager.shared.findNextImageToUpload()
                    }
                }
            }
        }
    }
}
