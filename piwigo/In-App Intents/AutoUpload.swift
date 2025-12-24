//
//  AutoUpload.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/06/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
@preconcurrency import CoreData
import AppIntents
import Photos
@preconcurrency import piwigoKit
import uploadKit

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct AutoUpload: AppIntent, CustomIntentMigratedAppIntent { //}, PredictableIntent {
    static let intentClassName = "AutoUploadIntent"
    
    /// Each intent needs to include metadata, such as a localized title. The title of the intent displays throughout the system.
    static var title = LocalizedStringResource("AutoUploadTitle", table: "In-AppIntents")

    /// An intent can optionally provide a localized description that the Shortcuts app displays.
    static var description = IntentDescription(LocalizedStringResource("AutoUploadDescription", table: "In-AppIntents"),
                                               categoryName:
                                                LocalizedStringResource("severalImages"), searchKeywords: [
                                                LocalizedStringResource("Auto-Upload", table: "In-AppIntents"),
                                                LocalizedStringResource("severalImages"), "Piwigo"])
    
    /// Tell the system to not bring the app to the foreground when the intent runs.
    static let openAppWhenRun: Bool = false

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
    func perform() async throws -> some IntentResult & ProvidesDialog {
        debugPrint("••> !!!!!!!!!!!!!!!!!!!!!!!!!")
        debugPrint("••> In-app intent starting...")
        
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
            Task { @UploadManagement in
                UploadManager.shared.disableAutoUpload()
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
            Task { @UploadManagement in
                UploadManager.shared.disableAutoUpload()
            }
            
            // Inform user
            return .result(dialog: .responseFailure(error: .invalidDestination))
        }
        
        // Get new local images to be uploaded
        let uploadRequestsToAppend = await UploadManager.shared.getNewRequests(inCollection: collection,
                                                                               toBeUploadedIn: categoryId)
        
        // Append auto-upload requests to database
        do {
            let count = try await UploadProvider().importUploads(from: uploadRequestsToAppend)

            // Launch upload operations in background thread
            Task { @UploadManagement in
                launchUploadOperations()
            }
            
            // Inform user that the shortcut was executed with success
            return .result(dialog: .responseSuccess(photos: count))
        }
        catch {
            return .result(dialog: .responseFailure(error: .importFailed))
        }
    }
    
    private func launchUploadOperations() -> Void {
        // Create list of operations
        var uploadOperations = [BlockOperation]()

        // Initialise variables and determine upload requests to prepare and transfer
        /// - considers only auto-upload requests
        /// - called by an extension (don't try to append auto-upload requests again)
        let initOperation = BlockOperation {
            Task { @UploadManagement in
                await UploadManager.shared.initialiseBckgTask(autoUploadOnly: true,
                                                              triggeredByExtension: true)
            }
        }
        uploadOperations.append(initOperation)

        // Check and resume transfers
        let resumeOperation = BlockOperation {
            // Transfer image
            Task { @UploadManagement in
                await UploadManager.shared.resumeTransfers()
            }
        }
        resumeOperation.addDependency(uploadOperations.last!)
        uploadOperations.append(resumeOperation)

        // Prepares one image maximum due to the 10s limit
        let uploadOperation = BlockOperation {
            // Prepare image
            Task { @UploadManagement in
                await UploadManager.shared.appendUploadRequestsToPrepareToBckgTask()
            }
        }
        uploadOperation.addDependency(uploadOperations.last!)
        uploadOperations.append(uploadOperation)

        // Save cached data
        let lastOperation = uploadOperations.last!
        lastOperation.completionBlock = {
            // Save cached data in the main thread
            DispatchQueue.main.async {
                DataController.shared.mainContext.saveIfNeeded()
            }
            debugPrint("    > In-app intent completed with success.")
        }
        
        // Launch upload operations
        // The badge will be updated during execution.
        let uploadQueue = OperationQueue()
        uploadQueue.maxConcurrentOperationCount = 1
        uploadQueue.addOperations(uploadOperations, waitUntilFinished: true)
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
