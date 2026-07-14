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
import PwgKit
import PwgCacheKit
import PwgUploadKit

// Only used on iOS 15.x - 16.3.x
final class AutoUploadIntentHandler: NSObject, AutoUploadIntentHandling {
    
    // Logs shortcut activity
    /// sudo log collect --device --start '2023-04-07 15:00:00' --output piwigo.logarchive
    static let logger = PwgLogger(subsystem: "org.piwigo", category: String(describing: AutoUploadIntentHandler.self))
    
    // MARK: - Core Data Object Contexts
    @MainActor
    private lazy var mainContext: NSManagedObjectContext = {
        return DataController.shared.mainContext
    }()
    
    
    // MARK: - Handle Intent
    func handle(intent: AutoUploadIntent, completion: @escaping (AutoUploadIntentResponse) -> Void) {
        AutoUploadIntentHandler.logger.notice("In-app intent starting...")

        // If a migration is planned, invite the user to perform the migration.
        let migrator = DataMigrator()
        if migrator.requiresMigration() {
            AutoUploadIntentHandler.logger.notice("Core Data migration required")
            completion(AutoUploadIntentResponse.failure(error: AutoUploadError.migrationRequired.localizedDescription))
            return
        }
        
        // Is auto-uploading enabled?
        if !UploadVars.shared.isAutoUploadActive {
            AutoUploadIntentHandler.logger.notice("Auto-Upload option disabled")
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
            Task { @UploadManagerActor in
                await UploadManager.shared.disableAutoUpload(inBckgTask: true)
            }
            
            // Inform user
            AutoUploadIntentHandler.logger.notice("Invalid source album")
            completion(AutoUploadIntentResponse.failure(error: AutoUploadError.invalidSource.localizedDescription))
            return
        }
        
        // Check existence of Piwigo album
        let categoryId = UploadVars.shared.autoUploadCategoryId
        guard categoryId != Int32.min else {
            // Cannot access Piwigo album -> Reset album ID
            UploadVars.shared.autoUploadCategoryId = Int32.min    // Unknown destination Piwigo album
            
            // Delete remaining upload requests
            Task { @UploadManagerActor in
                await UploadManager.shared.disableAutoUpload(inBckgTask: true)
            }
            
            // Inform user
            AutoUploadIntentHandler.logger.notice("Invalid destination album")
            completion(AutoUploadIntentResponse.failure(error: AutoUploadError.invalidDestination.localizedDescription))
            return
        }
        
        // Get new local images to be uploaded
        Task(priority: .utility) { @UploadManagerActor in
            let uploadRequestsToAppend = UploadManager.shared.getNewRequests(inCollection: collection,
                                                                             toBeUploadedIn: categoryId)
            do {
                // Append auto-upload requests to database
                let uploadIDs = try await UploadManager.shared.importUploads(from: uploadRequestsToAppend)
                
                // Inform the user if there is no photo to upload
                if uploadIDs.isEmpty {
                    // Inform user that the shortcut was executed with error
                    AutoUploadIntentHandler.logger.notice("No upload requests to process")
                    completion(AutoUploadIntentResponse.success(photos: NSNumber(value: 0)))
                    return
                }
                
                // Add upload requests to queue
                UploadVars.shared.isPaused = false
                #if os(iOS) && !targetEnvironment(macCatalyst)
                // Queue uploads to prepare
                await UploadManagerActor.shared.addUploadsToPrepare(withIDs: uploadIDs)
                
                // Process next uploads if possible
                await UploadManagerActor.shared.processNextUpload()
                #elseif targetEnvironment(macCatalyst)
                // Queue uploads to prepare
                await UploadManagerActor.shared.addUploadsToPrepare(withIDs: uploadIDs)
                
                // Process next uploads if possible
                await UploadManagerActor.shared.processNextUpload()
                #endif

                // Inform user that the shortcut was executed with success
                AutoUploadIntentHandler.logger.notice("\(uploadIDs.count) upload requests added")
                completion(AutoUploadIntentResponse.success(photos: NSNumber(value: uploadIDs.count)))
            }
            catch {
                // Inform user that the shortcut was executed with error
                AutoUploadIntentHandler.logger.notice("Import of upload requests failed: \(error.localizedDescription)")
                let msg = PwgKitError.uploadCreationError.localizedDescription
                let errorMsg = String(format: "%@: %@", msg, error.localizedDescription)
                completion(AutoUploadIntentResponse.failure(error: errorMsg))
            }
        }
    }
}
