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
            disableAutoUpload()
            return
        }

        // Check existence of Piwigo album
        guard let categoryId = Model.sharedInstance()?.autoUploadCategoryId, categoryId != NSNotFound else {
            // Cannot access local album
            Model.sharedInstance().autoUploadCategoryId = NSNotFound    // Unknown destination Piwigo album
            disableAutoUpload()
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

        // Collect localIdentifiers of images in the Upload cache
        let (uploadIDs, _) = uploadsProvider.getAutoUploadRequests()

        // Determine which local images are still not considered for upload
        var uploadRequestsToAppend = [UploadProperties]()
        fetchedImages.enumerateObjects { image, idx, stop in
            if !uploadIDs.contains(image.localIdentifier) {
                var uploadRequest = UploadProperties(localIdentifier: image.localIdentifier,
                                                     category: categoryId)
                uploadRequest.markedForAutoUpload = true
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

            // Show an alert if there was an error.
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
                    topViewController.dismissPiwigoError(withTitle: NSLocalizedString("CoreDataFetch_UploadCreateFailed", comment: "Failed to create a new Upload object."), message: error.localizedDescription) {}
                }
            }
        }
    }
    
    func disableAutoUpload() {
        // Disable auto-uploading
        Model.sharedInstance().isAutoUploadActive = false
        Model.sharedInstance().saveToDisk()
        
        // Collect objectIDs of images being considered for auto-uploading
        let (_, objectIDs) = uploadsProvider.getAutoUploadRequests()

        // Remove waiting upload requests marked for auto-upload from the upload queue
        uploadsProvider.delete(uploadRequests: objectIDs)
    }
}
