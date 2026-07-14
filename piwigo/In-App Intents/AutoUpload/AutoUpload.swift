//
//  AutoUpload.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/06/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import CoreData
import AppIntents
import Photos
import PwgKit
import PwgCacheKit
import PwgUploadKit

@available(iOS 16.4, *)
struct AutoUpload: AppIntent, ForegroundContinuableIntent { // , PredictableIntent {
    static let intentClassName = "AutoUploadIntent"
    
    // Logs shortcut activity
    /// sudo log collect --device --start '2023-04-07 15:00:00' --output piwigo.logarchive
    static let logger = PwgLogger(subsystem: "org.piwigo", category: String(describing: AutoUpload.self))
    
    /// Each intent needs to include metadata, such as a localized title. The title of the intent displays throughout the system.
    static let title = LocalizedStringResource("settings_autoUploadLong")
    
    /// An intent can optionally provide a localized description that the Shortcuts app displays.
    static let description = IntentDescription(LocalizedStringResource("AutoUploadDescription", table: "In-AppIntents"),
                                               categoryName:
                                                LocalizedStringResource("severalImages"), searchKeywords: [
                                                    LocalizedStringResource("settings_autoUpload"),
                                                    LocalizedStringResource("severalImages"), "Piwigo"])
    
    /// Tell the system to not bring the app to the foreground when the intent starts.
    static let openAppWhenRun: Bool = false
    
    /// Tell the system to apply a specific task priority
//    static var priority: TaskPriority { .utility }
    
    static var parameterSummary: some ParameterSummary {
        Summary("Auto-Upload Photos")
    }
    
//    static var predictionConfiguration: some IntentPredictionConfiguration {
//        IntentPrediction(parameters: (.$name)) { name in
//            DisplayRepresentation(
//                title: "Auto-Upload Photos",
//                subtitle: "Appends recent photos."
//            )
//        }
//    }
    
    /**
     When the system runs the intent, it calls `perform()`.
     Intents run on an arbitrary queue. Intents that manipulate UI need to annotate `perform()` with `@MainActor`
     so that the UI operations run on the main actor.
     */
    @UploadManagerActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AutoUpload.logger.notice("In-app intent starting...")
        
        // If a migration is planned, invite the user to perform the migration.
        let migrator = DataMigrator()
        if migrator.requiresMigration() {
            AutoUpload.logger.notice("Core Data migration required")
            return .result(dialog: .responseFailure(error: .migrationRequired))
        }
        
        // Is auto-uploading enabled?
        if !UploadVars.shared.isAutoUploadActive {
            AutoUpload.logger.notice("Auto-Upload option disabled")
            return .result(dialog: .responseFailure(error: .autoUploadDisabled))
        }
        
        // Check access to Photo Library album
        let collectionID = UploadVars.shared.autoUploadAlbumId
        guard collectionID.isEmpty == false,
              let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [collectionID], options: nil).firstObject else {
            // Cannot access local album -> Reset album ID
            UploadVars.shared.autoUploadAlbumId = ""               // Unknown source Photos album
            
            // Delete remaining upload requests
            Task(priority: .utility) { @UploadManagerActor in
                await UploadManager.shared.disableAutoUpload(inBckgTask: true)
            }
            
            // Inform user
            AutoUpload.logger.notice("Invalid source album")
            return .result(dialog: .responseFailure(error: .invalidSource))
        }
        
        // Check existence of Piwigo album
        let categoryId = UploadVars.shared.autoUploadCategoryId
        guard categoryId != Int32.min else {
            // Cannot access Piwigo album -> Reset album ID
            UploadVars.shared.autoUploadCategoryId = Int32.min    // Unknown destination Piwigo album
            
            // Delete remaining upload requests
            Task(priority: .utility) { @UploadManagerActor in
                await UploadManager.shared.disableAutoUpload(inBckgTask: true)
            }
            
            // Inform user
            AutoUpload.logger.notice("Invalid destination album")
            return .result(dialog: .responseFailure(error: .invalidDestination))
        }
        
        // Add new images to upload queue
        var uploadIDs: [NSManagedObjectID]? = await Task(priority: .utility) { @UploadManagerActor in
            let uploadRequestsToAppend = UploadManager.shared.getNewRequests(inCollection: collection,
                                                                             toBeUploadedIn: categoryId)
            do {
                // Append auto-upload requests to database
                let uploadIDs = try await UploadManager.shared.importUploads(from: uploadRequestsToAppend)
                
                // Add upload requests to queue
                UploadVars.shared.isPaused = false

                // Return upload request IDs added to queue
                AutoUpload.logger.notice("\(uploadIDs.count) upload requests added")
                return uploadIDs
            }
            catch {
                // Return no upload request ID
                AutoUpload.logger.notice("Import of upload requests failed: \(error.localizedDescription)")
                return nil
            }
        }.value
        
        // Inform user if the import failed
        guard let uploadIDs
        else { return .result(dialog: .responseFailure(error: .importFailed)) }
        
        // Inform the user if there is no photo to upload
        if uploadIDs.isEmpty {
            // Inform user that the shortcut was executed with error
            AutoUpload.logger.notice("No upload requests to process")
            return .result(dialog: .responseSuccess(photos: 0))
        }
        
        // Inform the user that there are photos to upload and launch the uploads from the main app
        throw needsToContinueInForegroundError(.responseSuccess(photos: uploadIDs.count)) {
            Task(priority: .utility) { @UploadManagerActor in
                #if os(iOS) && !targetEnvironment(macCatalyst)
                if #available(iOS 26.0, *) {
                    // Launch new continued upload task if possible
                    if UploadVars.shared.isContinuedProcessingTaskActive == false {
                        UploadManager.shared.runContinuedUploadTask()
                    }
                }
                else {
                    // Queue uploads to prepare
                    await UploadManagerActor.shared.addUploadsToPrepare(withIDs: uploadIDs)
                    
                    // Process next uploads if possible
                    await UploadManagerActor.shared.processNextUpload()
                }
                #elseif targetEnvironment(macCatalyst)
                // Queue uploads to prepare
                await UploadManagerActor.shared.addUploadsToPrepare(withIDs: uploadIDs)
                
                // Process next uploads if possible
                await UploadManagerActor.shared.processNextUpload()
                #endif
            }
        }
    }
}

@available(iOS 16.4, *)
fileprivate extension IntentDialog
{
    static func responseSuccess(photos: Int) -> Self {
        if photos == 0 {
            .init(LocalizedStringResource("No photo added", table: "In-AppIntents"))
        } else {
            .init(LocalizedStringResource("\(photos) photos added", table: "In-AppIntents"))
        }
    }
    
    static func responseFailure(error: AutoUploadError) -> Self {
        "\(error.localizedDescription)"
    }
}
