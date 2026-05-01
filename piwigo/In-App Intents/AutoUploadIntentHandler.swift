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

// Only used on iOS 15.x
final class AutoUploadIntentHandler: NSObject, AutoUploadIntentHandling {
    
    // MARK: - Core Data Object Contexts
    @MainActor
    private lazy var mainContext: NSManagedObjectContext = {
        return DataController.shared.mainContext
    }()
    
    
    // MARK: - Handle Intent
    func handle(intent: AutoUploadIntent, completion: @escaping (AutoUploadIntentResponse) -> Void) {
        debugPrint("••> !!!!!!!!!!!!!!!!!!!!!!!!!")
        debugPrint("••> Auto-upload in-app intent starting...")
        
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
            Task { @UploadManagerActor in
                await UploadManager.shared.disableAutoUpload(inBckgTask: true)
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
            Task { @UploadManagerActor in
                await UploadManager.shared.disableAutoUpload(inBckgTask: true)
            }
            
            // Inform user
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
                
                // Inform user that the shortcut was executed with success
                completion(AutoUploadIntentResponse.success(photos: NSNumber(value: uploadIDs.count)))
            }
            catch {
                // Inform user that the shortcut was executed with error
                let msg = PwgKitError.uploadCreationError.localizedDescription
                let errorMsg = String(format: "%@: %@", msg, error.localizedDescription)
                completion(AutoUploadIntentResponse.failure(error: errorMsg))
            }
        }
    }
}
