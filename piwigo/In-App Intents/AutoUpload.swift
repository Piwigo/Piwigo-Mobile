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
import piwigoKit
import uploadKit

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct AutoUpload: AppIntent, CustomIntentMigratedAppIntent { // , PredictableIntent {
    static let intentClassName = "AutoUploadIntent"
    
    /// Each intent needs to include metadata, such as a localized title. The title of the intent displays throughout the system.
    static let title = LocalizedStringResource("AutoUploadTitle", table: "In-AppIntents")
    
    /// An intent can optionally provide a localized description that the Shortcuts app displays.
    static let description = IntentDescription(LocalizedStringResource("AutoUploadDescription", table: "In-AppIntents"),
                                               categoryName:
                                                LocalizedStringResource("severalImages"), searchKeywords: [
                                                    LocalizedStringResource("Auto-Upload", table: "In-AppIntents"),
                                                    LocalizedStringResource("severalImages"), "Piwigo"])
    
    /// Tell the system to not bring the app to the foreground when the intent runs.
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
        debugPrint("••> !!!!!!!!!!!!!!!!!!!!!!!!!")
        debugPrint("••> Auto-upload in-app intent starting...")
        
        // If a migration is planned, invite the user to perform the migration.
        let migrator = DataMigrator()
        if migrator.requiresMigration() {
            return .result(dialog: .responseFailure(error: .migrationRequired))
        }
        
        // Is auto-uploading enabled?
        if !UploadVars.shared.isAutoUploadActive {
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
            return .result(dialog: .responseFailure(error: .invalidDestination))
        }
        
        // Add new images to upload queue
        let nberOfRequests = await Task(priority: .utility) { @UploadManagerActor in
            let uploadRequestsToAppend = UploadManager.shared.getNewRequests(inCollection: collection,
                                                                         toBeUploadedIn: categoryId)
            do {
                // Append auto-upload requests to database
                let uploadIDs = try await UploadManager.shared.importUploads(from: uploadRequestsToAppend)
                
                // Return number of upload requests added to queue
                return uploadIDs.count
            }
            catch {
                // Return unknown number of upload requests added to queue
                return Int.min
            }
        }.value
        
        // Inform user
        if nberOfRequests == Int.min {
            // Inform user that the shortcut was executed with error
            return .result(dialog: .responseFailure(error: .importFailed))
        }
        else {
            // Inform user that the shortcut was executed with success
            return .result(dialog: .responseSuccess(photos: nberOfRequests))
        }
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
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

