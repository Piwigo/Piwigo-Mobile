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
protocol DataMigratorProtocol {
    func forceWALCheckpointingForStore(at storeURL: URL)
    func requiresMigration(at storeURL: URL, toVersion version: DataMigrationVersion) -> Bool
    func migrateStore(at storeURL: URL, toVersion version: DataMigrationVersion, at newStoreURL: URL)
}

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
class DataMigrator: DataMigratorProtocol {
    
    // MARK: - Check
    func requiresMigration(at storeURL: URL, toVersion version: DataMigrationVersion) -> Bool {
        guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL) else {
            return false
        }
        
        return (DataMigrationVersion.compatibleVersionForStoreMetadata(metadata) != version)
    }
    
    
    // MARK: - Migration
    func migrateStore(at oldStoreURL: URL, toVersion version: DataMigrationVersion, at newStoreURL: URL) {
        // Force WAL checkpoint
        forceWALCheckpointingForStore(at: oldStoreURL)
        
        // Initialisation
        var currentURL = oldStoreURL
        let migrationSteps = self.migrationStepsForStore(at: oldStoreURL, toVersion: version)
        if migrationSteps.isEmpty { return }
        
        // Loop over the migration steps
        for (index, migrationStep) in migrationSteps.enumerated()
        {
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
    func forceWALCheckpointingForStore(at storeURL: URL) {
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
    
    
    // MARK: - Incompatible Stores
    private func moveIncompatibleStore(storeURL: URL) {
        let fm = FileManager.default
        let appIncompatibleStoresDirectory = DataController.shared.appSupportDirectory.appendingPathComponent("Incompatible")

        // Create the Piwigo/Incompatible directory if needed
        if !fm.fileExists(atPath: appIncompatibleStoresDirectory.path) {
            do {
                try fm.createDirectory(at: appIncompatibleStoresDirectory,
                                       withIntermediateDirectories: true, attributes: nil)
            } catch let error {
                print("Unable to create directory for corrupt data stores: \(error.localizedDescription)")
            }
        }
        
        // Rename files with current date
        let dateFormatter = DateFormatter()
        dateFormatter.formatterBehavior = .behavior10_4
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let nameForIncompatibleStore = "\(dateFormatter.string(from: Date()))"

        // Move store
        let corruptStoreURL = appIncompatibleStoresDirectory
            .appendingPathComponent(nameForIncompatibleStore)
            .appendingPathExtension("sqlite")

        // Move Corrupt Store
        do {
            try fm.moveItem(at: storeURL, to: corruptStoreURL)
        } catch let error {
            print("Unable to move corrupt store: \(error.localizedDescription)")
        }
    }
}


// MARK: - Compatible
private extension DataMigrationVersion {
    static func compatibleVersionForStoreMetadata(_ metadata: [String : Any]) -> DataMigrationVersion? {
        let compatibleVersion = DataMigrationVersion.allCases.first {
            let model = NSManagedObjectModel.managedObjectModel(forVersion: $0)
            
            // For debugging
            let modelEntities = model.entityVersionHashesByName.mapValues({ $0 })
            print("\($0.rawValue)")
            print("••> Tag (model)     : \(Array(arrayLiteral: modelEntities["Tag"]?.base64EncodedString()))")
            print("••> Location (model): \(Array(arrayLiteral: modelEntities["Location"]?.base64EncodedString()))")
            print("••> Upload (model)  : \(Array(arrayLiteral: modelEntities["Upload"]?.base64EncodedString()))")

            let metadataEntities = metadata[NSStoreModelVersionHashesKey] as! [String : Data]
            let metaEntities = metadataEntities.mapValues({ $0 })
            print("••> Tag (meta)      : \(Array(arrayLiteral: metaEntities["Tag"]?.base64EncodedString()))")
            print("••> Location (meta) : \(Array(arrayLiteral: metaEntities["Location"]?.base64EncodedString()))")
            print("••> Upload (meta)   : \(Array(arrayLiteral: metaEntities["Upload"]?.base64EncodedString()))")
            print("……")
            
            return model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }
        return compatibleVersion
    }
}
