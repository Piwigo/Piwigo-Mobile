//
//  DataController.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 17/02/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation
import CoreData

public class DataController: NSObject {

    // MARK: - Singleton
    public static let shared = DataController()
    
    
    // MARK: - Initialisation
    let migrator: DataMigratorProtocol
    private let storeType: String

    init(storeType: String = NSSQLiteStoreType, migrator: DataMigratorProtocol = DataMigrator()) {
        self.storeType = storeType
        self.migrator = migrator
    }

    
    //MARK: - Core Data Directories
    // "Library/Application Support/Piwigo" inside the group container.
    /// - The shared database and temporary files to upload are stored in the App Group
    ///   container so that they can be used and shared by the app and the extensions.
    lazy var appGroupDirectory: URL = {
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
        let containerDirectory = fm.containerURL(forSecurityApplicationGroupIdentifier: AppGroup)
        let piwigoURL = containerDirectory?.appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("Piwigo")

        // Create the Piwigo directory in the container if needed
        if !(fm.fileExists(atPath: piwigoURL?.path ?? "")) {
            var errorCreatingDirectory: Error? = nil
            do {
                if let piwigoURL = piwigoURL {
                    try fm.createDirectory(at: piwigoURL, withIntermediateDirectories: true, attributes: nil)
                }
            }
            catch let errorCreatingDirectory {
            }
            if errorCreatingDirectory != nil {
                fatalError("Unable to create Piwigo directory in App Group container.")
            }
        }

        print("••> AppGroupDirectory: \(piwigoURL!)")
        return piwigoURL!
    }()

    // "Library/Application Support/Piwigo" inside the Data Container of the Sandbox.
    /// - This is where the incompatible Core Data stores are stored.
    /// - The contents of this directory are backed up by iTunes and iCloud.
    /// - This is the directory where the application used to store the Core Data store files
    ///   and files to upload before the creation of extensions.
    lazy var appSupportDirectory: URL = {
        let fm = FileManager.default
        let applicationSupportDirectory = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).last
        let piwigoURL = applicationSupportDirectory?.appendingPathComponent("Piwigo")

        // Create the Piwigo directory in "Library/Application Support" if needed
        if !(fm.fileExists(atPath: piwigoURL?.path ?? "")) {
            var errorCreatingDirectory: Error? = nil
            do {
                if let piwigoURL = piwigoURL {
                    try fm.createDirectory(at: piwigoURL, withIntermediateDirectories: true, attributes: nil)
                }
            } catch let errorCreatingDirectory {
            }
            if errorCreatingDirectory != nil {
                fatalError("Unable to create \"Piwigo\" directory in \"Library/Application Support\".")
            }
        }

        print("••> AppSupportDirectory: \(piwigoURL!)")
        return piwigoURL!
    }()


    // MARK: - Core Data Stack
    public lazy var mainContext: NSManagedObjectContext = {

        let applicationDocumentsDirectory: URL = {
            // The directory the application used to store the Core Data store file long ago.
            let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            return urls[urls.count-1]
        }()

        var managedObjectModel: NSManagedObjectModel = {
            // This resource has the same name as your xcdatamodeld contained in your project
            let bundle = Bundle.init(for: DataController.self)
            guard var modelURL = bundle.url(forResource: "DataModel", withExtension: "momd") else {
                fatalError("Error loading model from bundle")
            }
            
            // Retrieve the model version string (from the .plist file located in the .momd package)
            // in order to avoid having to update the code each time there is a new model version.
            // Avoids the warning "Failed to load optimized model at path…" for iOS
            if #available(iOS 13.0, *) { } else {
                let versionInfoURL = modelURL.appendingPathComponent("VersionInfo.plist")
                if let versionInfoNSDictionary = NSDictionary(contentsOf: versionInfoURL),
                    let version = versionInfoNSDictionary.object(forKey: "NSManagedObjectModel_CurrentVersionName") as? String {
                    modelURL.appendPathComponent("\(version).mom")
                }
            }
            
            // Get the object data model
            guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
                fatalError("Error initializing mom from: \(modelURL)")
            }
            return managedObjectModel
        }()

        var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
            // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
            // Create the coordinator
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
            
            // Move the very old store to the new folder if needed
//            let storeURL = appGroupDirectory.appendingPathComponent("DataModel.sqlite")
//            var oldURL = applicationDocumentsDirectory.appendingPathComponent("DataModel.sqlite")
//            NSPersistentStoreCoordinator.moveStore(from: oldURL, to: storeURL)

            // Move the old store to the new folder if needed
//            oldURL = appSupportDirectory.appendingPathComponent("DataModel.sqlite")
//            NSPersistentStoreCoordinator.moveStore(from: oldURL, to: storeURL)

            // Move Upload folder to container if needed
//            moveFilesToUpload()

            // The database is now stored in the App group directory
//            if migrator.requiresMigration(at: storeURL, toVersion: DataMigrationVersion.current) {
//                DispatchQueue.global(qos: .userInitiated).async {
//                    // Perform the migration(s)
//                    self.migrator.migrateStore(at: storeURL, toVersion: DataMigrationVersion.current)
//
//                    // Add presistent store to coordinator
//                    do {
//                        try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil,
//                                                           at: storeURL, options: nil)
//                    } catch let error {
//                        // Move Incompatible Store
//                        self.moveIncompatibleStore(storeURL: storeURL)
//
//                        // Will inform user at restart
//                        CacheVars.couldNotMigrateCoreDataStore = true
//
//                        // Crash!
//                        abort()
//                    }
//                }
//            } else {
//
//            }


            
            // The database is now stored in the App group directory
            let storeURL = appGroupDirectory.appendingPathComponent("DataModel.sqlite")
//            if needMigrate {
//                do {
//                    try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil,
//                                                       at: oldURL, options: options)
//                    if let store = coordinator.persistentStore(for: oldURL)
//                    {
//                        do {
//                            try coordinator.migratePersistentStore(store, to: storeURL,
//                                                                   options: options, withType: NSSQLiteStoreType)
//                            // Delete old Core Data store files
//                            self.deleteOldStoreAtUrl(url: oldURL)
//                            self.deleteOldStoreAtUrl(url: oldURL.deletingPathExtension()
//                                                        .appendingPathExtension("sqlite-shm"))
//                            self.deleteOldStoreAtUrl(url: oldURL.deletingPathExtension()
//                                                        .appendingPathExtension("sqlite-wal"))
//                            // Move Upload folder to container if needed
//                            moveFilesToUpload()
//                        }
//                        catch let error {
//                            // Log error
//                            let error = NSError(domain: "Piwigo", code: 9990,
//                                                userInfo: [NSLocalizedDescriptionKey : "Failed to move Core Data store."])
//                            print("Unresolved error \(error.localizedDescription)")
//
//                            // Move Incompatible Store
//                            self.moveIncompatibleStore(storeURL: oldURL)
//
//                            // Will inform user at restart
//                            CacheVars.couldNotMigrateCoreDataStore = true
//
//                            // Crash!
//                            abort()
//                        }
//                    }
//                } catch {
//                    // Log error
//                    let error = NSError(domain: "Piwigo", code: 9990,
//                                        userInfo: [NSLocalizedDescriptionKey : "Failed to migrate Core Data store."])
//                    print("Unresolved error \(error.localizedDescription)")
//
//                    // Move Incompatible Store
//                    self.moveIncompatibleStore(storeURL: oldURL)
//
//                    // Will inform user at restart
//                    CacheVars.couldNotMigrateCoreDataStore = true
//
//                    // Crash!
//                    abort()
//                }
//            } else {
                do {
                    try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil,
                                                       at: storeURL, options: nil)
                } catch {
                    // Log error
                    let error = NSError(domain: "Piwigo", code: 9990,
                                        userInfo: [NSLocalizedDescriptionKey : "Failed to migrate Core Data store."])
                    print("Unresolved error \(error.localizedDescription)")

                    // Move Incompatible Store
                    moveIncompatibleStore(storeURL: storeURL)
                    
                    // Will inform user at restart
                    CacheVars.couldNotMigrateCoreDataStore = true

                    // Crash!
                    abort()
                }
//            }
            
            return coordinator
        }()

        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        if #available(iOS 10.0, *) {
            managedObjectContext.automaticallyMergesChangesFromParent = true
        }
        managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        managedObjectContext.shouldDeleteInaccessibleFaults = true
        // Set unused undoManager to nil for macOS (it is nil by default on iOS)
        // to reduce resource requirements.
        managedObjectContext.undoManager = nil
        return managedObjectContext
    }()

    lazy var backgroundContext: NSManagedObjectContext = {
        var privateManagedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateManagedObjectContext.parent = mainContext
        privateManagedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        privateManagedObjectContext.shouldDeleteInaccessibleFaults = true
        // Set unused undoManager to nil for macOS (it is nil by default on iOS)
        // to reduce resource requirements.
//        privateManagedObjectContext.undoManager = nil
        return privateManagedObjectContext
    }()
    
    public func migrateStoreIfNeeded(completion: @escaping () -> Void) {
        // URL of the store in the App Group directory
        let storeURL = appGroupDirectory.appendingPathComponent("DataModel.sqlite")

        // The directory the application used to store the Core Data store file long ago.
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let applicationDocumentsDirectory = urls[urls.count-1]

        // Move the very old store to the new folder if needed
        var oldURL = applicationDocumentsDirectory.appendingPathComponent("DataModel.sqlite")
        NSPersistentStoreCoordinator.moveStore(from: oldURL, to: storeURL)

        // Move the old store to the new folder if needed
        oldURL = appSupportDirectory.appendingPathComponent("DataModel.sqlite")
        NSPersistentStoreCoordinator.moveStore(from: oldURL, to: storeURL)

        // Move Upload folder to container if needed
        moveFilesToUpload()

        // The database is now stored in the App group directory
        if migrator.requiresMigration(at: storeURL, toVersion: DataMigrationVersion.current) {
            DispatchQueue.global(qos: .userInitiated).async {
                // Perform the migration (version after version)
                self.migrator.migrateStore(at: storeURL, toVersion: DataMigrationVersion.current)
                DispatchQueue.main.async {
                    completion()
                }
            }
        } else {
            completion()
        }
    }
    
//    private func deleteOldStoreAtUrl(url: URL) {
//        let fileCoordinator = NSFileCoordinator(filePresenter: nil)
//        fileCoordinator.coordinate(writingItemAt: url, options: .forDeleting, error: nil, byAccessor: {
//            (urlForModifying) -> Void in
//            do {
//                try FileManager.default.removeItem(at: urlForModifying)
//            }catch let error {
//                print("Failed to remove item with error: \(error.localizedDescription)")
//            }
//        })
//    }

    private func moveIncompatibleStore(storeURL: URL) {
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

    private func moveFilesToUpload() {
        let fm = FileManager.default
        let oldURL = appSupportDirectory.appendingPathComponent("Uploads")
        let newURL = appGroupDirectory.appendingPathComponent("Uploads")

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
}


// MARK: - Core Data Batch Deletion
extension NSManagedObjectContext {
    /// Executes the given `NSBatchDeleteRequest` and directly merges the changes to bring the given managed object context up to date.
    /// See https://www.avanderlee.com/swift/nsbatchdeleterequest-core-data/
    /// - Parameter batchDeleteRequest: The `NSBatchDeleteRequest` to execute.
    /// - Throws: An error if anything went wrong executing the batch deletion.
    public func executeAndMergeChanges(using batchDeleteRequest: NSBatchDeleteRequest) throws {
        batchDeleteRequest.resultType = .resultTypeObjectIDs
        let result = try execute(batchDeleteRequest) as? NSBatchDeleteResult
        let objectIDArray = result?.result as? [NSManagedObjectID]
        let changes = [NSDeletedObjectsKey : objectIDArray]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes as [AnyHashable : Any], into: [self])
    }
}
