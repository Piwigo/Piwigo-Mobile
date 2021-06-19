//
//  AutoUploadPhotosHandler.swift
//  piwigoIntents
//
//  Created by Eddy Lelièvre-Berna on 03/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import Photos
import piwigoKit

class AutoUploadPhotosHandler: NSObject, AutoUploadPhotosIntentHandling {
    
    // MARK: - Core Data
    /**
     The UploadsProvider that collects upload data, saves it to Core Data,
     and serves it to the uploader.
     */
    lazy var uploadsProvider: UploadsProvider = {
        let provider : UploadsProvider = UploadsProvider()
        return provider
    }()

    func handle(intent: AutoUploadPhotosIntent, completion: @escaping (AutoUploadPhotosIntentResponse) -> Void) {
        print("•••>> handling AutoUploadPhotos shortcut…")
        
        
        

        completion(AutoUploadPhotosIntentResponse.success(nberPhotos: 23))
    }


    // MARK: - Add Auto-Upload Requests
    func appendAutoUploadRequests() {
        // Check access to Photo Library album
        let collectionID = UploadVars.shared.autoUploadAlbumId
        guard !collectionID.isEmpty,
           let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [collectionID], options: nil).firstObject else {
            // Cannot access local album
            UploadVars.shared.autoUploadAlbumId = ""               // Unknown source Photos album
//            disableAutoUpload(withTitle: NSLocalizedString("settings_autoUploadSourceInvalid", comment:"Invalid source album"), message: NSLocalizedString("settings_autoUploadSourceInfo", comment: "Please select the album or sub-album from which photos and videos of your device will be auto-uploaded."))
            return
        }

        // Check existence of Piwigo album
        let categoryId = UploadVars.shared.autoUploadCategoryId
        guard categoryId != NSNotFound else {
            // Cannot access local album
            UploadVars.shared.autoUploadCategoryId = NSNotFound    // Unknown destination Piwigo album
//            disableAutoUpload(withTitle: NSLocalizedString("settings_autoUploadDestinationInvalid", comment:"Invalid destination album"), message: NSLocalizedString("settings_autoUploadSourceInfo", comment: "Please select the album or sub-album into which photos and videos will be auto-uploaded."))
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
        let (imageIDs, _) = uploadsProvider.getAutoUploadRequestsIn(states: states)

        // Determine which local images are still not considered for upload
        var uploadRequestsToAppend = [UploadProperties]()
        let serverFileTypes = UploadVars.shared.serverFileTypes
        fetchedImages.enumerateObjects { image, idx, stop in
            // Keep images which had never been considered for upload
            if !imageIDs.contains(image.localIdentifier) {
                // Rejects videos if the server cannot accept them
                if image.mediaType == .video {
                    // Retrieve image file extension (slow)
                    let fileName = UploadUtilities.fileName(forImageAsset: image)
                    let fileExt = (URL(fileURLWithPath: fileName).pathExtension).lowercased()
                    // Check file format
                    let unacceptedFileFormat = !serverFileTypes.contains(fileExt)
                    let mp4NotAccepted = !serverFileTypes.contains("mp4")
                    let notConvertible = !UploadUtilities.acceptedMovieFormats.contains(fileExt)
                    if unacceptedFileFormat && (mp4NotAccepted || notConvertible) { return }
                }
                
                // Format should be acceptable, create upload request
                var uploadRequest = UploadProperties(localIdentifier: image.localIdentifier,
                                                     category: categoryId)
                uploadRequest.markedForAutoUpload = true
                uploadRequest.tagIds = UploadVars.shared.autoUploadTagIds
                uploadRequest.comment = UploadVars.shared.autoUploadComments
                uploadRequestsToAppend.append(uploadRequest)
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
            return
        }
    }
}
