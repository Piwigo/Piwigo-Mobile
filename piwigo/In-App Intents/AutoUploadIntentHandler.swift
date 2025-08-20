//
//  AutoUploadIntenthandler.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 21/07/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import CoreData
import Intents
import Photos
import piwigoKit
import uploadKit

class AutoUploadIntentHandler: NSObject, AutoUploadIntentHandling {

    // MARK: - Core Data Object Contexts
    private lazy var mainContext: NSManagedObjectContext = {
        return DataController.shared.mainContext
    }()
    

    // MARK: - Core Data Providers
    private lazy var uploadProvider: UploadProvider = {
        let provider : UploadProvider = UploadManager.shared.uploadProvider
        return provider
    }()

    
    // MARK: - Handle Intent
    func handle(intent: AutoUploadIntent, completion: @escaping (AutoUploadIntentResponse) -> Void) {
        debugPrint("••> !!!!!!!!!!!!!!!!!!!!!!!!!")
        debugPrint("••> In-app intent starting...")

        // If a migration is planned, invite the user to perform the migration.
        let migrator = DataMigrator()
        if migrator.requiresMigration() {
            completion(AutoUploadIntentResponse.failure(error: AutoUploadError.migrationRequired.localizedDescription))
            return
        }
        
        // Is auto-uploading enabled?
        if !UploadVars.shared.isAutoUploadActive {
            completion(AutoUploadIntentResponse.failure(error: AutoUploadError.autoUploadDisabled.localizedDescription))
            return
        }
        
        // Check access to Photo Library album
        let collectionID = UploadVars.shared.autoUploadAlbumId
        guard collectionID.isEmpty == false,
           let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [collectionID], options: nil).firstObject else {
            // Cannot access local album -> Reset album ID
            UploadVars.shared.autoUploadAlbumId = ""               // Unknown source Photos album
            
            // Delete remaining upload requests
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.disableAutoUpload()
            }
            
            // Inform user
            completion(AutoUploadIntentResponse.failure(error: AutoUploadError.invalidSource.localizedDescription))
            return
        }

        // Check existence of Piwigo album
        let categoryId = UploadVars.shared.autoUploadCategoryId
        guard categoryId != Int32.min else {
            // Cannot access Piwigo album -> Reset album ID
            UploadVars.shared.autoUploadCategoryId = Int32.min    // Unknown destination Piwigo album

            // Delete remaining upload requests
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.disableAutoUpload()
            }

            // Inform user
            completion(AutoUploadIntentResponse.failure(error: AutoUploadError.invalidDestination.localizedDescription))
            return
        }
        
        // Extract images not already in the upload queue
        UploadManager.shared.backgroundQueue.async { [unowned self] in
            // Get new local images to be uploaded
            let uploadRequestsToAppend = UploadManager.shared.getNewRequests(inCollection: collection,
                                                                             toBeUploadedIn: categoryId)
                .compactMap{ $0 }
            
            // Append auto-upload requests to database
            self.uploadProvider.importUploads(from: uploadRequestsToAppend) { error in
                // Show an alert if there was an error.
                guard let error = error else {
                    // Initialise upload operations
                    let uploadOperations = self.getUploadOperations()

                    // Launch upload operations
                    // The badge will be updated during execution.
                    let uploadQueue = OperationQueue()
                    uploadQueue.maxConcurrentOperationCount = 1
                    uploadQueue.addOperations(uploadOperations, waitUntilFinished: true)

                    // Inform user that the shortcut was executed with success
                    completion(AutoUploadIntentResponse.success(photos: NSNumber(value: uploadRequestsToAppend.count)))
                    return
                }
                
                // Error encountered…
                DispatchQueue.main.async {
                    let msg = PwgKitError.uploadCreationError.localizedDescription
                    let errorMsg = String(format: "%@: %@", msg, error.localizedDescription)
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
                self.mainContext.saveIfNeeded()
            }
            debugPrint("    > In-app intent completed with success.")
        }
        
        return uploadOperations
    }    
}
