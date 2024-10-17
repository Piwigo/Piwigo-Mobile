//
//  DataMigrator.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 28/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import CoreData

// MARK: - Core Data Migrator
/// See: https://williamboles.com/progressive-core-data-migration/
/**
 Responsible for handling Core Data model migrations.
 
 The default Core Data model migration approach is to go from earlier version to all possible future versions.
 
 So, if we have 4 model versions (1, 2, 3, 4), you would need to create the following mappings 1 to 4, 2 to 4 and 3 to 4.
 Then when we create model version 5, we would create mappings 1 to 5, 2 to 5, 3 to 5 and 4 to 5. You can see that for each
 new version we must create new mappings from all previous versions to the current version. This does not scale well, in the
 above example 4 new mappings have been created. For each new version you must add n-1 new mappings.
 
 Instead the solution below uses an iterative approach where we migrate mutliple times through a chain of model versions.
 
 So, if we have 4 model versions (1, 2, 3, 4), you would need to create the following mappings 1 to 2, 2 to 3 and 3 to 4.
 Then when we create model version 5, we only need to create one additional mapping 4 to 5. This greatly reduces the work
 required when adding a new version.
 */
public class DataMigrator: NSObject {
    
    public func requiresMigration() -> Bool {
        // URL of the store in the App Group directory
        let storeURL = DataDirectories.shared.appGroupDirectory
            .appendingPathComponent("DataModel.sqlite")

        // Move the very old store to the new folder if needed
        var oldStoreURL = DataDirectories.shared.appDocumentsDirectory
            .appendingPathComponent("DataModel.sqlite")
        if requiresMigration(at: oldStoreURL, toVersion: DataMigrationVersion.current) {
            // Migration of store saved in App documents directory required
            return true
        }
        
        // Move the old store to the new folder if needed
        oldStoreURL = DataDirectories.shared.appSupportDirectory
            .appendingPathComponent("DataModel.sqlite")
        if requiresMigration(at: oldStoreURL, toVersion: DataMigrationVersion.current) {
            // Migration of store saved in App Support directory required
            return true
        }

        // Migrate store to new data model if needed
        if requiresMigration(at: storeURL, toVersion: DataMigrationVersion.current) {
            // Migration of store saved in App Group directory required
            return true
        }
        
        // No migration required
        return false
    }

    public func migrateStore() {
        // URL of the store in the App Group directory
        let storeURL = DataDirectories.shared.appGroupDirectory
            .appendingPathComponent("DataModel.sqlite")

        // Move the very old store to the new folder if needed
        var oldStoreURL = DataDirectories.shared.appDocumentsDirectory
            .appendingPathComponent("DataModel.sqlite")
        if requiresMigration(at: oldStoreURL, toVersion: DataMigrationVersion.current) {
            // Perform the migration (version after version)
            migrateStore(at: oldStoreURL,
                         toVersion: DataMigrationVersion.current, at: storeURL)
            return
        }
        
        // Move the old store to the new folder if needed
        oldStoreURL = DataDirectories.shared.appSupportDirectory
            .appendingPathComponent("DataModel.sqlite")
        if requiresMigration(at: oldStoreURL, toVersion: DataMigrationVersion.current) {
            // Perform the migration (version after version)
            migrateStore(at: oldStoreURL,
                         toVersion: DataMigrationVersion.current, at: storeURL)
            // Move Upload folder to container if needed
            self.moveFilesToUpload()
            return
        }

        // Migrate store to new data model if needed
        if requiresMigration(at: storeURL, toVersion: DataMigrationVersion.current) {
            // Perform the migration (version after version)
            migrateStore(at: storeURL,
                         toVersion: DataMigrationVersion.current, at: storeURL)
            return
        }
    }

    private func moveIncompatibleStore(storeURL: URL) {
        let fm = FileManager.default
        let applicationIncompatibleStoresDirectory = DataDirectories.shared.appSupportDirectory
            .appendingPathComponent("Incompatible")

        // Create the Piwigo/Incompatible directory if needed
        if !fm.fileExists(atPath: applicationIncompatibleStoresDirectory.path) {
            do {
                try fm.createDirectory(at: applicationIncompatibleStoresDirectory,
                                       withIntermediateDirectories: true, attributes: nil)
            } catch let error {
                debugPrint("Unable to create a directory for corrupted data stores: \(error.localizedDescription)")
            }
        }
        
        // Rename files with current date
        let dateFormatter = DateFormatter()
        dateFormatter.formatterBehavior = .behavior10_4
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let nameForIncompatibleStore = "\(dateFormatter.string(from: Date()))"

        // Move .sqlite file
        if fm.fileExists(atPath: storeURL.path) {
            let corruptURL = applicationIncompatibleStoresDirectory
                .appendingPathComponent(nameForIncompatibleStore)
                .appendingPathExtension("sqlite")

            // Move Corrupt Store
            do {
                try fm.moveItem(at: storeURL, to: corruptURL)
            } catch let error {
                debugPrint("Unable to move a corrupted data store: \(error.localizedDescription)")
            }
        }

        // Move .sqlite-shm file
        let shmURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
        if fm.fileExists(atPath: shmURL.path) {
            let corruptURL = applicationIncompatibleStoresDirectory
                .appendingPathComponent(nameForIncompatibleStore)
                .appendingPathExtension("sqlite-shm")

            // Move Corrupt Store
            do {
                try fm.moveItem(at: shmURL, to: corruptURL)
            } catch let error {
                debugPrint("Unable to move a corrupted data store: \(error.localizedDescription)")
            }
        }

        // Move .sqlite-shm file
        let walURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
        if fm.fileExists(atPath: walURL.path) {
            let corruptURL = applicationIncompatibleStoresDirectory
                .appendingPathComponent(nameForIncompatibleStore)
                .appendingPathExtension("sqlite-wal")

            // Move Corrupt Store
            do {
                try fm.moveItem(at: walURL, to: corruptURL)
            } catch let error {
                debugPrint("Unable to move a corrupted data store: \(error.localizedDescription)")
            }
        }
    }

    private func moveFilesToUpload() {
        let fm = FileManager.default
        let oldURL = DataDirectories.shared.appSupportDirectory
            .appendingPathComponent("Uploads")
        let newURL = DataDirectories.shared.appGroupDirectory
            .appendingPathComponent("Uploads")

        // Move Uploads directory
        do {
            // Get list of files
            let filesToMove = try fm.contentsOfDirectory(at: oldURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])

            // Move files
            for fileToMove in filesToMove {
                let newFileURL = newURL.appendingPathComponent(fileToMove.lastPathComponent)
                try fm.moveItem(at: fileToMove, to: newFileURL)
            }
            
            // Delete old Uploads directory
            try fm.removeItem(at: oldURL)
        }
        catch let error {
            debugPrint("Unable to move content of Uploads directory: \(error.localizedDescription)")
        }
    }

    
    // MARK: - Check
    private func requiresMigration(at storeURL: URL, toVersion version: DataMigrationVersion) -> Bool {
        guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL) else {
            return false
        }
        
        return (DataMigrationVersion.compatibleVersionForStoreMetadata(metadata) != version)
    }
    
    
    // MARK: - Migration
    private func migrateStore(at oldStoreURL: URL, toVersion version: DataMigrationVersion, at newStoreURL: URL) {
        // Force WAL checkpoint
        forceWALCheckpointingForStore(at: oldStoreURL)
        
        // Initialisation
        var currentURL = oldStoreURL
        let migrationSteps = self.migrationStepsForStore(at: oldStoreURL, toVersion: version)
        if migrationSteps.isEmpty { return }
        
        // Loop over the migration steps
        for (index, migrationStep) in migrationSteps.enumerated() {
            autoreleasepool {
                let manager = NSMigrationManager(sourceModel: migrationStep.sourceModel,
                                                 destinationModel: migrationStep.destinationModel)
                var tempStoreURL: URL
                if newStoreURL != oldStoreURL, index + 1 == migrationSteps.count {
                    tempStoreURL = newStoreURL
                } else {
                    tempStoreURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString)
                }
                
                // Perform a migration
                do {
                    try manager.migrateStore(from: currentURL, sourceType: NSSQLiteStoreType,
                                             options: nil, with: migrationStep.mappingModel,
                                             toDestinationURL: tempStoreURL,
                                             destinationType: NSSQLiteStoreType, destinationOptions: nil)
                } catch let error {
                    // Move store to directory of incompatible stores
                    moveIncompatibleStore(storeURL: currentURL)
                    fatalError("failed attempting to migrate from \(migrationStep.sourceModel) to \(migrationStep.destinationModel), error: \(error)")
                }
                
                // Destroy intermediate step's store
                if ![oldStoreURL, newStoreURL].contains(currentURL) {
                    NSPersistentStoreCoordinator.destroyStore(at: currentURL)
                }
                
                // Use URL of migrated store for next step
                currentURL = tempStoreURL
            }
        }
        
        // Replace original store with new store if old and new URLs are identical
        if newStoreURL == oldStoreURL {
            NSPersistentStoreCoordinator.replaceStore(at: oldStoreURL, withStoreAt: currentURL)
            if (currentURL != oldStoreURL) {
                NSPersistentStoreCoordinator.destroyStore(at: currentURL)
            }
        } else {
            NSPersistentStoreCoordinator.destroyStore(at: oldStoreURL)
        }
    }
    
    private func migrationStepsForStore(at storeURL: URL, toVersion destinationVersion: DataMigrationVersion) -> [DataMigrationStep] {
        guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL),
              let sourceVersion = DataMigrationVersion.compatibleVersionForStoreMetadata(metadata) else {
            return [DataMigrationStep]()
        }
        
        return migrationSteps(fromSourceVersion: sourceVersion, toDestinationVersion: destinationVersion)
    }

    private func migrationSteps(fromSourceVersion sourceVersion: DataMigrationVersion,
                                toDestinationVersion destinationVersion: DataMigrationVersion) -> [DataMigrationStep] {
        var sourceVersion = sourceVersion
        var migrationSteps = [DataMigrationStep]()

        while sourceVersion != destinationVersion, let nextVersion = sourceVersion.nextVersion() {
            let migrationStep = DataMigrationStep(sourceVersion: sourceVersion,
                                                  destinationVersion: nextVersion)
            migrationSteps.append(migrationStep)

            sourceVersion = nextVersion
        }

        return migrationSteps
    }
    
    
    // MARK: - WAL
    private func forceWALCheckpointingForStore(at storeURL: URL) {
        guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL),
              let currentModel = NSManagedObjectModel.compatibleModelForStoreMetadata(metadata) else {
            return
        }
        
        do {
            let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: currentModel)
            let options = [NSSQLitePragmasOption: ["journal_mode": "DELETE"]]
            let store = persistentStoreCoordinator.addPersistentStore(at: storeURL, options: options)
            try persistentStoreCoordinator.remove(store)
        } catch let error {
            fatalError("failed to force WAL checkpointing, error: \(error)")
        }
    }
}


// MARK: - Compatible
private extension DataMigrationVersion {
    static func compatibleVersionForStoreMetadata(_ metadata: [String : Any]) -> DataMigrationVersion? {
        let compatibleVersion = DataMigrationVersion.allCases.first {
            let model = NSManagedObjectModel.managedObjectModel(forVersion: $0)

            // For debugging
//            let modelEntities = model.entityVersionHashesByName.mapValues({ $0 })
//            debugPrint("\($0.rawValue)")
//            debugPrint("••> Tag (model)     : \(Array(arrayLiteral: modelEntities["Tag"]?.base64EncodedString()))")
//            debugPrint("••> Location (model): \(Array(arrayLiteral: modelEntities["Location"]?.base64EncodedString()))")
//            debugPrint("••> Upload (model)  : \(Array(arrayLiteral: modelEntities["Upload"]?.base64EncodedString()))")

//            let metadataEntities = metadata[NSStoreModelVersionHashesKey] as! [String : Data]
//            let metaEntities = metadataEntities.mapValues({ $0 })
//            debugPrint("••> Tag (meta)      : \(Array(arrayLiteral: metaEntities["Tag"]?.base64EncodedString()))")
//            debugPrint("••> Location (meta) : \(Array(arrayLiteral: metaEntities["Location"]?.base64EncodedString()))")
//            debugPrint("••> Upload (meta)   : \(Array(arrayLiteral: metaEntities["Upload"]?.base64EncodedString()))")
//            debugPrint("……")

            return model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }
        
        // In case where the data model is not found, try to guess the current data model…
        if compatibleVersion == nil {
            if let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                if appVersion.compare("2.5", options: .numeric) == .orderedAscending {
        //            debugPrint("••> \(appVersion) is smaller than 2.5")
                    return .version01
                }
                else if appVersion.compare("2.5.2", options: .numeric) == .orderedAscending {
        //            debugPrint("••> \(appVersion) is smaller than 2.5.2")
                    return .version03
                }
                else if appVersion.compare("2.6", options: .numeric) == .orderedAscending {
        //            debugPrint("••> \(appVersion) is smaller than 2.6")
                    return .version04
                }
                else if appVersion.compare("2.6.2", options: .numeric) == .orderedAscending {
        //            debugPrint("••> \(appVersion) is smaller than 2.6.2")
                    return .version06
                }
                else if appVersion.compare("2.7", options: .numeric) == .orderedAscending {
        //            debugPrint("••> \(appVersion) is smaller than 2.7")
                    return .version07
                }
                else if appVersion.compare("2.12", options: .numeric) == .orderedAscending {
        //            debugPrint("••> \(appVersion) is smaller than 2.12")
                    return .version08
                }
                else if appVersion.compare("3.00", options: .numeric) == .orderedAscending {
        //            debugPrint("••> \(appVersion) is smaller than 3.00")
                    return .version09
                }
                else if appVersion.compare("3.20", options: .numeric) == .orderedAscending {
        //            debugPrint("••> \(appVersion) is smaller than 3.2")
                    return .version0C
                }
                return .version0F
            }
        }
        return compatibleVersion
    }
}
