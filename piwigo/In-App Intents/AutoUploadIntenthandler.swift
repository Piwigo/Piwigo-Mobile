//
//  AutoUploadIntenthandler.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 21/07/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Intents
import Photos
import piwigoKit

@available(iOS 14.0, *)
class AutoUploadIntentHandler: NSObject, AutoUploadIntentHandling {

    // MARK: - Core Data
    /**
     The UploadsProvider that collects upload data, saves it to Core Data,
     and serves it to the uploader.
     */
    lazy var uploadsProvider: UploadsProvider = {
        let provider : UploadsProvider = UploadsProvider()
        return provider
    }()

    
    // MARK: - Handle Intent
    func handle(intent: AutoUploadIntent, completion: @escaping (AutoUploadIntentResponse) -> Void) {
        
        // Is auto-uploading enabled?
        if !UploadVars.isAutoUploadActive {
            let errorMsg = NSLocalizedString("AutoUploadError_Disabled",
                                             comment: "Auto-uploading is disabled in the app settings.")
            completion(AutoUploadIntentResponse.failure(error: errorMsg))
            return
        }
        
        // Check access to Photo Library album
        let collectionID = UploadVars.autoUploadAlbumId
        guard !collectionID.isEmpty,
           let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [collectionID], options: nil).firstObject else {
            // Cannot access local album
            UploadVars.autoUploadAlbumId = ""               // Unknown source Photos album
            disableAutoUpload()
            let message = String(format: "%@: %@", NSLocalizedString("settings_autoUploadSourceInvalid", comment:"Invalid source album"), NSLocalizedString("settings_autoUploadSourceInfo", comment: "Please select the album or sub-album from which photos and videos of your device will be auto-uploaded."))
            completion(AutoUploadIntentResponse.failure(error: message))
            return
        }

        // Check existence of Piwigo album
        let categoryId = UploadVars.autoUploadCategoryId
        guard categoryId != NSNotFound else {
            // Cannot access local album
            UploadVars.autoUploadCategoryId = NSNotFound    // Unknown destination Piwigo album
            disableAutoUpload()
            let message = String(format: "%@: %@", NSLocalizedString("settings_autoUploadDestinationInvalid", comment:"Invalid destination album"), NSLocalizedString("settings_autoUploadSourceInfo", comment: "Please select the album or sub-album into which photos and videos will be auto-uploaded."))
            completion(AutoUploadIntentResponse.failure(error: message))
            return
        }

        // Collect IDs of images in collection
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeHiddenAssets = false
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetchedImages = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        
        // Extract images not already in the upload queue
        UploadManager.shared.backgroundQueue.async { [unowned self] in
            var uploadRequestsToAppend = [UploadProperties]()
            if fetchedImages.count > 0 {
                // Collect localIdentifiers of uploaded and not yet uploaded images in the Upload cache
                let states: [kPiwigoUploadState] = [.waiting, .preparing, .preparingError,
                                                    .preparingFail, .formatError, .prepared,
                                                    .uploading, .uploadingError, .uploaded,
                                                    .finishing, .finishingError, .finished,
                                                    .moderated, .deleted]
                let imageIDs = self.uploadsProvider.getRequests(inStates: states).0

                // Determine which local images are still not considered for upload
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
            }
            
            // Relaunch transfers if there is no new image to append to the upload queue
            let photosToPrepare = uploadRequestsToAppend.compactMap{ $0 }.count
            if photosToPrepare == 0 {
                // Create the operation queue
                let uploadQueue = OperationQueue()
                uploadQueue.maxConcurrentOperationCount = 1
                
                // Add operation setting flags and selecting upload requests
                let initOperation = BlockOperation {
                    // Initialse variables and determine upload requests to prepare and transfer
                    UploadManager.shared.initialiseBckgTask(autoUploadOnly: true)
                }

                // Initialise list of operations
                var uploadOperations = [BlockOperation]()
                uploadOperations.append(initOperation)

                // Resume transfers
                let resumeOperation = BlockOperation {
                    // Transfer image
                    UploadManager.shared.resumeTransfers()
                }
                resumeOperation.addDependency(uploadOperations.last!)
                uploadOperations.append(resumeOperation)

                // Save the database when the operation completes
                let lastOperation = uploadOperations.last!
                lastOperation.completionBlock = {
                    debugPrint("    > In-app intent completed with success.")
                }

                // Start the operations
                print("    > In-app intent restarts transfers...");
                uploadQueue.addOperations(uploadOperations, waitUntilFinished: false)

                completion(AutoUploadIntentResponse.success(photos: NSNumber(value: 0)))
                return
            }

            // Append auto-upload requests to database
            self.uploadsProvider.importUploads(from: uploadRequestsToAppend.compactMap{ $0 }) { error in

                // Update app badge and Upload button in root/default album
                // Considers only uploads to the server to which the user is logged in
                let states: [kPiwigoUploadState] = [.waiting, .preparing, .preparingError,
                                                    .preparingFail, .formatError, .prepared,
                                                    .uploading, .uploadingError, .uploaded,
                                                    .finishing, .finishingError]
                UploadManager.shared.nberOfUploadsToComplete = self.uploadsProvider.getRequests(inStates: states).0.count

                // Show an alert if there was an error.
                guard let error = error else {

                    // Create the operation queue
                    let uploadQueue = OperationQueue()
                    uploadQueue.maxConcurrentOperationCount = 1
                    
                    // Add operation setting flags and selecting upload requests
                    let initOperation = BlockOperation {
                        // Initialse variables and determine upload requests to prepare and transfer
                        UploadManager.shared.initialiseBckgTask(autoUploadOnly: true)
                    }

                    // Initialise list of operations
                    var uploadOperations = [BlockOperation]()
                    uploadOperations.append(initOperation)

                    // Resume transfers
                    let resumeOperation = BlockOperation {
                        // Transfer image
                        UploadManager.shared.resumeTransfers()
                    }
                    resumeOperation.addDependency(uploadOperations.last!)
                    uploadOperations.append(resumeOperation)

                    // Add first image preparation which will be followed by transfer operations
                    // We prepare only one image due to the 10s limit.
                    let uploadOperation = BlockOperation {
                        // Transfer image
                        UploadManager.shared.appendUploadRequestsToPrepareToBckgTask()
                    }
                    uploadOperation.addDependency(uploadOperations.last!)
                    uploadOperations.append(uploadOperation)
                    
                    // Save the database when the operation completes
                    let lastOperation = uploadOperations.last!
                    lastOperation.completionBlock = {
                        debugPrint("    > In-app intent completed with success.")
                    }

                    // Start the operations
                    debugPrint("    > In-app intent resumes transfers and append upload requests...");
                    uploadQueue.addOperations(uploadOperations, waitUntilFinished: true)

                    // Inform user that the shortcut was excuted with success
                    completion(AutoUploadIntentResponse.success(photos: NSNumber(value: photosToPrepare)))
                    return
                }
                
                // Error encountered…
                DispatchQueue.main.async {
                    let errorMsg = String(format: "%@: %@", NSLocalizedString("CoreDataFetch_UploadCreateFailed", comment: "Failed to create a new Upload object."), error.localizedDescription)
                    completion(AutoUploadIntentResponse.failure(error: errorMsg))
                }
            }
        }
    }

    private func disableAutoUpload() {
        // Disable auto-uploading
        UploadVars.isAutoUploadActive = false
        
        // Collect objectIDs of images being considered for auto-uploading
        UploadManager.shared.backgroundQueue.async { [unowned self] in
            let states: [kPiwigoUploadState] = [.waiting, .preparingError,
                                                .preparingFail, .formatError, .prepared,
                                                .uploadingError, .uploaded,
                                                .finishingError]
            let objectIDs = uploadsProvider.getRequests(inStates: states, markedForAutoUpload: true).1

            // Remove non-completed upload requests marked for auto-upload from the upload queue
            if !objectIDs.isEmpty {
                uploadsProvider.delete(uploadRequests: objectIDs) { error in
                    // Job done
                }
            }
        }
    }
}
