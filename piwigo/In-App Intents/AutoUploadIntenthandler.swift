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
        debugPrint("    > !!!!!!!!!!!!!!!!!!!!!!!!!")
        debugPrint("    > In-app intent starting...")

        // Is auto-uploading enabled?
        if !UploadVars.isAutoUploadActive {
            let errorMsg = NSLocalizedString("AutoUploadError_Disabled",
                                             comment: "Auto-uploading is disabled in the app settings.")
            completion(AutoUploadIntentResponse.failure(error: errorMsg))
            return
        }
        
        // Check access to Photo Library album
        let collectionID = UploadVars.autoUploadAlbumId
        guard collectionID.isEmpty == false,
           let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [collectionID], options: nil).firstObject else {
            // Cannot access local album -> Reset album ID
            UploadVars.autoUploadAlbumId = ""               // Unknown source Photos album
            
            // Delete remaining upload requests
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.disableAutoUpload()
            }
            
            // Inform user
            let message = String(format: "%@: %@", NSLocalizedString("settings_autoUploadSourceInvalid", comment:"Invalid source album"), NSLocalizedString("settings_autoUploadSourceInfo", comment: "Please select the album or sub-album from which photos and videos of your device will be auto-uploaded."))
            completion(AutoUploadIntentResponse.failure(error: message))
            return
        }

        // Check existence of Piwigo album
        let categoryId = UploadVars.autoUploadCategoryId
        guard categoryId != NSNotFound else {
            // Cannot access Piwigo album -> Reset album ID
            UploadVars.autoUploadCategoryId = NSNotFound    // Unknown destination Piwigo album

            // Delete remaining upload requests
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.disableAutoUpload()
            }

            // Inform user
            let message = String(format: "%@: %@", NSLocalizedString("settings_autoUploadDestinationInvalid", comment:"Invalid destination album"), NSLocalizedString("settings_autoUploadSourceInfo", comment: "Please select the album or sub-album into which photos and videos will be auto-uploaded."))
            completion(AutoUploadIntentResponse.failure(error: message))
            return
        }
        
        // Extract images not already in the upload queue
        UploadManager.shared.backgroundQueue.async { [unowned self] in
            // Get new local images to be uploaded
            let uploadRequestsToAppend = UploadManager.shared.getNewRequests(inCollection: collection,
                                                                             toBeUploadedIn: categoryId)
                .compactMap{ $0 }
            
            // Append auto-upload requests to database
            self.uploadsProvider.importUploads(from: uploadRequestsToAppend) { error in
                // Update app badge and Upload button in root/default album
                // Considers only uploads to the server to which the user is logged in
                let states: [kPiwigoUploadState] = [.waiting, .preparing, .preparingError,
                                                    .preparingFail, .formatError, .prepared,
                                                    .uploading, .uploadingError, .uploadingFail, .uploaded,
                                                    .finishing, .finishingError]
                UploadManager.shared.nberOfUploadsToComplete = self.uploadsProvider.getRequests(inStates: states).0.count

                // Show an alert if there was an error.
                guard let error = error else {
                    // Initialise upload operations
                    let uploadOperations = self.getUploadOperations()

                    // Launch upload operations
                    let uploadQueue = OperationQueue()
                    uploadQueue.maxConcurrentOperationCount = 1
                    uploadQueue.addOperations(uploadOperations, waitUntilFinished: true)

                    // Inform user that the shortcut was executed with success
                    completion(AutoUploadIntentResponse.success(photos: NSNumber(value: uploadRequestsToAppend.count)))
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

    private func getUploadOperations() -> [BlockOperation] {
        // Create list of operations
        var uploadOperations = [BlockOperation]()

        // Initialise variables and determine upload requests to prepare and transfer
        /// - considers only auto-upload requests
        /// - called by an extension (don't try to append auto-upload requests again)
        let initOperation = BlockOperation {
            UploadManager.shared.initialiseBckgTask(autoUploadOnly: true,
                                                    triggeredByExtension: true)
        }
        uploadOperations.append(initOperation)

        // Check and resume transfers
        let resumeOperation = BlockOperation {
            // Transfer image
            UploadManager.shared.resumeTransfers()
        }
        resumeOperation.addDependency(uploadOperations.last!)
        uploadOperations.append(resumeOperation)

        // Prepares one image maximum due to the 10s limit
        let uploadOperation = BlockOperation {
            // Prepare image
            UploadManager.shared.appendUploadRequestsToPrepareToBckgTask()
        }
        uploadOperation.addDependency(uploadOperations.last!)
        uploadOperations.append(uploadOperation)

        // Save cached data
        let lastOperation = uploadOperations.last!
        lastOperation.completionBlock = {
            // Save cached data in the main thread
            DispatchQueue.main.async {
                DataController.shared.saveMainContext()
            }
            debugPrint("    > In-app intent completed with success.")
        }
        
        return uploadOperations
    }    
}
