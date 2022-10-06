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
    static var appGroupDirectory: URL { get }
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
    
    // Initialisation
    init() {
        // Perform migration right before creating DataController instance if needed
        migrateStoreIfNeeded()
    }
    
    internal func migrateStoreIfNeeded() {
        // URL of the store in the App Group directory
        let storeURL = DataMigrator.appGroupDirectory.appendingPathComponent("DataModel.sqlite")

        // Move the very old store to the new folder if needed
        var oldStoreURL = appDocumentsDirectory.appendingPathComponent("DataModel.sqlite")
        if requiresMigration(at: oldStoreURL, toVersion: DataMigrationVersion.current) {
            // Perform the migration (version after version)
            migrateStore(at: oldStoreURL,
                         toVersion: DataMigrationVersion.current, at: storeURL)
            return
        }
        
        // Move the old store to the new folder if needed
        oldStoreURL = appSupportDirectory.appendingPathComponent("DataModel.sqlite")
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

    internal func moveIncompatibleStore(storeURL: URL) {
        let fm = FileManager.default
        let applicationIncompatibleStoresDirectory = self.appSupportDirectory.appendingPathComponent("Incompatible")

        // Create the Piwigo/Incompatible directory if needed
        if !fm.fileExists(atPath: applicationIncompatibleStoresDirectory.path) {
            do {
                try fm.createDirectory(at: applicationIncompatibleStoresDirectory,
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

        // Move .sqlite file
        if fm.fileExists(atPath: storeURL.path) {
            let corruptURL = applicationIncompatibleStoresDirectory
                .appendingPathComponent(nameForIncompatibleStore)
                .appendingPathExtension("sqlite")

            // Move Corrupt Store
            do {
                try fm.moveItem(at: storeURL, to: corruptURL)
            } catch let error {
                print("Unable to move corrupt store: \(error.localizedDescription)")
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
                print("Unable to move corrupt store: \(error.localizedDescription)")
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
                print("Unable to move corrupt store: \(error.localizedDescription)")
            }
        }
    }

    internal func moveFilesToUpload() {
        let fm = FileManager.default
        let oldURL = appSupportDirectory.appendingPathComponent("Uploads")
        let newURL = DataMigrator.appGroupDirectory.appendingPathComponent("Uploads")

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
            print("Unable to move content of Uploads directory: \(error.localizedDescription)")
        }
    }

    
    //MARK: - Core Data Directories
    // "Library/Application Support/Piwigo" inside the group container.
    /// - The shared database and temporary files to upload are stored in the App Group
    ///   container so that they can be used and shared by the app and the extensions.
    static var appGroupDirectory: URL = {
        // We use different App Groups:
        /// - Development: one chosen by the developer
        /// - Release: the official group.org.piwigo
        #if DEBUG
        let AppGroup = "group.net.lelievre-berna.piwigo"
        #else
        let AppGroup = "group.org.piwigo"
        #endif

        // Get path of group container
        let fm = FileManager.default
        guard let containerDirectory = fm.containerURL(forSecurityApplicationGroupIdentifier: AppGroup) else {
            fatalError("Unable to retrieve the App Group directory.")
        }
        let piwigoURL = containerDirectory.appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("Piwigo")

        // Create the Piwigo directory in the container if needed
        if fm.fileExists(atPath: piwigoURL.path) == false {
            do {
                try fm.createDirectory(at: piwigoURL, withIntermediateDirectories: true, attributes: nil)
            }
            catch {
                fatalError("Unable to create the \"Piwigo\" directory in the App Group container (\(error.localizedDescription).")
            }
        }

        print("••> appGroupDirectory: \(piwigoURL)")
        return piwigoURL
    }()

    // "Library/Application Support/Piwigo" inside the Data Container of the Sandbox.
    /// - This is where the incompatible Core Data stores are stored.
    /// - The contents of this directory are backed up by iTunes and iCloud.
    /// - This is the directory where the application used to store the Core Data store files
    ///   and files to upload before the creation of extensions.
    lazy var appSupportDirectory: URL = {
        let fm = FileManager.default
        guard let applicationSupportDirectory = fm.urls(for: .applicationSupportDirectory,
                                                        in: .userDomainMask).last else {
            fatalError("Unable to retrieve the \"Library/Application Support\" directory.")
        }
        let piwigoURL = applicationSupportDirectory.appendingPathComponent("Piwigo")

        // Create the Piwigo directory in "Library/Application Support" if needed
        if fm.fileExists(atPath: piwigoURL.path) == false {
            do {
                try fm.createDirectory(at: piwigoURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                fatalError("Unable to create \"Piwigo\" directory in \"Library/Application Support\" (\(error.localizedDescription).")
            }
        }

        print("••> appSupportDirectory: \(piwigoURL)")
        return piwigoURL
    }()

    // "Documents" inside the Data Container of the Sandbox.
    /// - This is the directory where the application used to store the Core Data store files long ago.
    lazy var appDocumentsDirectory: URL = {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let appDocumentsDirectory = urls[urls.count-1]

        print("••> appDocumentsDirectory: \(appDocumentsDirectory)")
        return appDocumentsDirectory
    }()

    
    // MARK: - Check
    internal func requiresMigration(at storeURL: URL, toVersion version: DataMigrationVersion) -> Bool {
        guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL) else {
            return false
        }
        
        return (DataMigrationVersion.compatibleVersionForStoreMetadata(metadata) != version)
    }
    
    
    // MARK: - Migration
    internal func migrateStore(at oldStoreURL: URL, toVersion version: DataMigrationVersion, at newStoreURL: URL) {
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
    
    internal func migrationStepsForStore(at storeURL: URL, toVersion destinationVersion: DataMigrationVersion) -> [DataMigrationStep] {
        guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL),
              let sourceVersion = DataMigrationVersion.compatibleVersionForStoreMetadata(metadata) else {
            return [DataMigrationStep]()
        }
        
        return migrationSteps(fromSourceVersion: sourceVersion, toDestinationVersion: destinationVersion)
    }

    internal func migrationSteps(fromSourceVersion sourceVersion: DataMigrationVersion,
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
    internal func forceWALCheckpointingForStore(at storeURL: URL) {
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
//    private func moveIncompatibleStore(storeURL: URL) {
//        let fm = FileManager.default
//        let appIncompatibleStoresDirectory = appSupportDirectory.appendingPathComponent("Incompatible")
//
//        // Create the Piwigo/Incompatible directory if needed
//        if !fm.fileExists(atPath: appIncompatibleStoresDirectory.path) {
//            do {
//                try fm.createDirectory(at: appIncompatibleStoresDirectory,
//                                       withIntermediateDirectories: true, attributes: nil)
//            } catch let error {
//                print("Unable to create directory for corrupt data stores: \(error.localizedDescription)")
//            }
//        }
//
//        // Rename files with current date
//        let dateFormatter = DateFormatter()
//        dateFormatter.formatterBehavior = .behavior10_4
//        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
//        let nameForIncompatibleStore = "\(dateFormatter.string(from: Date()))"
//
//        // Move store
//        let corruptStoreURL = appIncompatibleStoresDirectory
//            .appendingPathComponent(nameForIncompatibleStore)
//            .appendingPathExtension("sqlite")
//
//        // Move Corrupt Store
//        do {
//            try fm.moveItem(at: storeURL, to: corruptStoreURL)
//        } catch let error {
//            print("Unable to move corrupt store: \(error.localizedDescription)")
//        }
//    }
}


// MARK: - Compatible
private extension DataMigrationVersion {
    static func compatibleVersionForStoreMetadata(_ metadata: [String : Any]) -> DataMigrationVersion? {
        let compatibleVersion = DataMigrationVersion.allCases.first {
            let model = NSManagedObjectModel.managedObjectModel(forVersion: $0)

            // For debugging
//            let modelEntities = model.entityVersionHashesByName.mapValues({ $0 })
//            print("\($0.rawValue)")
//            print("••> Tag (model)     : \(Array(arrayLiteral: modelEntities["Tag"]?.base64EncodedString()))")
//            print("••> Location (model): \(Array(arrayLiteral: modelEntities["Location"]?.base64EncodedString()))")
//            print("••> Upload (model)  : \(Array(arrayLiteral: modelEntities["Upload"]?.base64EncodedString()))")

//            let metadataEntities = metadata[NSStoreModelVersionHashesKey] as! [String : Data]
//            let metaEntities = metadataEntities.mapValues({ $0 })
//            print("••> Tag (meta)      : \(Array(arrayLiteral: metaEntities["Tag"]?.base64EncodedString()))")
//            print("••> Location (meta) : \(Array(arrayLiteral: metaEntities["Location"]?.base64EncodedString()))")
//            print("••> Upload (meta)   : \(Array(arrayLiteral: metaEntities["Upload"]?.base64EncodedString()))")
//            print("……")

            return model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }
        
        // In case where the data model is not found, try to guess the current data model…
        if compatibleVersion == nil {
            if let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                if appVersion.compare("2.5", options: .numeric) == .orderedAscending {
        //            print("••> \(appVersion) is smaller than 2.5")
                    return .version01
                }
                else if appVersion.compare("2.5.2", options: .numeric) == .orderedAscending {
        //            print("••> \(appVersion) is smaller than 2.5.2")
                    return .version03
                }
                else if appVersion.compare("2.6", options: .numeric) == .orderedAscending {
        //            print("••> \(appVersion) is smaller than 2.6")
                    return .version04
                }
                else if appVersion.compare("2.6.2", options: .numeric) == .orderedAscending {
        //            print("••> \(appVersion) is smaller than 2.6.2")
                    return .version06
                }
                else if appVersion.compare("2.7", options: .numeric) == .orderedAscending {
        //            print("••> \(appVersion) is smaller than 2.7")
                    return .version07
                }
                else if appVersion.compare("2.12", options: .numeric) == .orderedAscending {
        //            print("••> \(appVersion) is smaller than 2.12")
                    return .version08
                }
                else if appVersion.compare("3.00", options: .numeric) == .orderedAscending {
        //            print("••> \(appVersion) is smaller than 3.00")
                    return .version09
                }
                return .version0A
            }
        }
        return compatibleVersion
    }
}
