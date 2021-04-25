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
        // Check access Photo Library album
        guard let collectionID = Model.sharedInstance()?.autoUploadAlbumId, !collectionID.isEmpty,
           let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [collectionID], options: nil).firstObject else {
            // Cannot access local album
            Model.sharedInstance().autoUploadAlbumId = ""               // Unknown source Photos album
            Model.sharedInstance().isAutoUploadActive = false
            Model.sharedInstance().saveToDisk()
            return
        }

        // Check existence of Piwigo album
        guard let categoryId = Model.sharedInstance()?.autoUploadCategoryId, categoryId != NSNotFound else {
            // Cannot access local album
            Model.sharedInstance().autoUploadCategoryId = NSNotFound    // Unknown destination Piwigo album
            Model.sharedInstance().isAutoUploadActive = false
            Model.sharedInstance().saveToDisk()
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

        // Collect IDs of images already considered for upload
        guard let uploadIds = uploadsProvider.fetchedResultsController
                .fetchedObjects?.map({ $0.localIdentifier }) else {
            // Could not retrieve uploads
            return
        }

        // Determine which local images are still not considered for upload
        var imagesToUpload = [UploadProperties]()
        fetchedImages.enumerateObjects { image, idx, stop in
            if !uploadIds.contains(image.localIdentifier) {
                var uploadRequest = UploadProperties(localIdentifier: image.localIdentifier,
                                                     category: categoryId)
                 uploadRequest.markedForAutoUpload = true
                imagesToUpload.append(uploadRequest)
            }
        }
        if imagesToUpload.count == 0 {
            // Nothing to add to the upload queue - Job done
            return
        }

        self.uploadsProvider.importUploads(from: imagesToUpload.compactMap{ $0 }) { error in
        }
    }
}
