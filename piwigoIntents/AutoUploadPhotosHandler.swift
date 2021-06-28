//
//  AutoUploadPhotosHandler.swift
//  piwigoIntents
//
//  Created by Eddy Lelièvre-Berna on 03/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import Photos
import piwigoKit

@available(iOSApplicationExtension 13.0, *)
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
        
        // Is auto-uploading enabled?
        if !UploadVars.isAutoUploadActive {
            let errorMsg = NSLocalizedString("AutoUploadError_Disabled",
                                             comment: "Auto-uploading is disabled in the app settings.")
            completion(AutoUploadPhotosIntentResponse.failure(error: errorMsg))
            return
        }
        
        // Append auto-upload requests
        let errorMsg = appendAutoUploadRequests()
        if !errorMsg.isEmpty {
            completion(AutoUploadPhotosIntentResponse.failure(error: errorMsg))
            return
        }
        
        // Reset flags and requests to prepare and transfer
        UploadManager.shared.isUploading = Set<NSManagedObjectID>()
        UploadManager.shared.uploadRequestsToPrepare = Set<NSManagedObjectID>()
        UploadManager.shared.uploadRequestsToTransfer = Set<NSManagedObjectID>()

        // First, find auto-upload requests whose transfer did fail
        let failedUploads = uploadsProvider.getAutoUploadRequestsIn(states: [.uploadingError]).1
        if failedUploads.count > 0, failedUploads.count < 2 {
            // Will relaunch transfers with one which failed
            UploadManager.shared.uploadRequestsToTransfer = Set(failedUploads[..<min(UploadManager.shared.maxNberOfUploadsPerBckgTask, failedUploads.count)])
            print("\(UploadUtilities.debugFormatter.string(from: Date())) >•• collected \(UploadManager.shared.uploadRequestsToTransfer.count) failed uploads")
        }

        // Second, find auto-upload requests ready for transfer
        let preparedUploads = uploadsProvider.getAutoUploadRequestsIn(states: [.prepared]).1
        if UploadManager.shared.uploadRequestsToTransfer.count == 0,
           preparedUploads.count > 0 {
            // Will relaunch transfers with a prepared upload
            UploadManager.shared.uploadRequestsToTransfer = UploadManager.shared.uploadRequestsToTransfer
                .union(Set(preparedUploads[..<min(UploadManager.shared.maxNberOfUploadsPerBckgTask,preparedUploads.count)]))
            print("\(UploadUtilities.debugFormatter.string(from: Date())) >•• collected \(min(UploadManager.shared.maxNberOfUploadsPerBckgTask,preparedUploads.count)) prepared uploads)")
        }
        
        // Finally, get list of auto-upload requests to prepare
        let diff = UploadManager.shared.maxNberOfUploadsPerBckgTask -
            UploadManager.shared.uploadRequestsToTransfer.count
        if diff > 0 {
            let requestsToPrepare = uploadsProvider.getAutoUploadRequestsIn(states: [.waiting]).1
            print("\(UploadUtilities.debugFormatter.string(from: Date())) >•• collected \(min(diff, requestsToPrepare.count)) uploads to prepare")
            UploadManager.shared.uploadRequestsToPrepare = Set(requestsToPrepare[..<min(diff, requestsToPrepare.count)])
        }
        let nberOfPhotos = UploadManager.shared.uploadRequestsToPrepare.count

        // Create the operation queue
        let uploadQueue = OperationQueue()
        uploadQueue.maxConcurrentOperationCount = 1
        
        // Initialise list of operations
        var uploadOperations = [BlockOperation]()

        // Resume transfers started in the foreground
        let resumeOperation = BlockOperation {
            UploadManager.shared.resumeTransfers()
        }
        uploadOperations.append(resumeOperation)
        
        // Add image preparation which will be followed by transfer operations
        for _ in 0..<UploadManager.shared.maxNberOfUploadsPerBckgTask {
            let uploadOperation = BlockOperation {
                // Transfer image
                UploadManager.shared.appendUploadRequestsToPrepareToBckgTask()
            }
            uploadOperation.addDependency(uploadOperations.last!)
            uploadOperations.append(uploadOperation)
        }

        // Start the operation
        print("    > Start upload operations in background task...");
        uploadQueue.addOperations(uploadOperations, waitUntilFinished: true)

        completion(AutoUploadPhotosIntentResponse.success(nberPhotos: NSNumber(value: nberOfPhotos)))
    }


    // MARK: - Add / Remove Auto-Upload Requests
    private func appendAutoUploadRequests() -> String {
        // Check access to Photo Library album
        let collectionID = UploadVars.autoUploadAlbumId
        guard !collectionID.isEmpty,
           let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [collectionID], options: nil).firstObject else {
            // Cannot access local album
            UploadVars.autoUploadAlbumId = ""               // Unknown source Photos album
            disableAutoUpload()
            let message = String(format: "%@: %@", NSLocalizedString("settings_autoUploadSourceInvalid", comment:"Invalid source album"), NSLocalizedString("settings_autoUploadSourceInfo", comment: "Please select the album or sub-album from which photos and videos of your device will be auto-uploaded."))
            return message
        }

        // Check existence of Piwigo album
        let categoryId = UploadVars.autoUploadCategoryId
        guard categoryId != NSNotFound else {
            // Cannot access local album
            UploadVars.autoUploadCategoryId = NSNotFound    // Unknown destination Piwigo album
            disableAutoUpload()
            let message = String(format: "%@: %@", NSLocalizedString("settings_autoUploadDestinationInvalid", comment:"Invalid destination album"), NSLocalizedString("settings_autoUploadSourceInfo", comment: "Please select the album or sub-album into which photos and videos will be auto-uploaded."))
            return message
        }

        // Collect IDs of images to upload
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeHiddenAssets = false
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetchedImages = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        if fetchedImages.count == 0 {
            // Nothing to add to the upload queue - Job done
            return ""
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
        let serverFileTypes = UploadVars.serverFileTypes
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
                uploadRequest.tagIds = UploadVars.autoUploadTagIds
                uploadRequest.comment = UploadVars.autoUploadComments
                uploadRequestsToAppend.append(uploadRequest)
            }
        }

        // Are there images to upload?
        if uploadRequestsToAppend.count == 0 {
            // Nothing to add to the upload queue - Job done
            return ""
        }

        // Record upload requests in database
        uploadsProvider.importUploads(from: uploadRequestsToAppend.compactMap{ $0 }) {_ in }
        return ""
    }

    private func disableAutoUpload() {
        // Disable auto-uploading
        UploadVars.isAutoUploadActive = false
        
        // Collect objectIDs of images being considered for auto-uploading
        let states: [kPiwigoUploadState] = [.waiting, .preparingError,
                                            .preparingFail, .formatError, .prepared,
                                            .uploadingError, .uploaded,
                                            .finishingError]
        let (_, objectIDs) = uploadsProvider.getAutoUploadRequestsIn(states: states)

        // Remove non-completed upload requests marked for auto-upload from the upload queue
        if !objectIDs.isEmpty {
            uploadsProvider.delete(uploadRequests: objectIDs) { error in
                // Job done
            }
        }
    }
}
