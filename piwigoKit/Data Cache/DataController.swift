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
        self.migrator = migrator    // Perform migration if needed

        super.init()                // Create instance
        self.persistentContainer.loadPersistentStores { _, error in
            guard let error = error else { return }
            fatalError("••> Was unable to load store - \(error)")
        }
    }

    
    // MARK: - Core Data Stack
    lazy var persistentContainer: NSPersistentContainer = {
        let model = NSManagedObjectModel.managedObjectModel(forVersion: DataMigrationVersion.current)
        let persistentContainer = NSPersistentContainer(name: "DataModel", managedObjectModel: model)
        let description = persistentContainer.persistentStoreDescriptions.first
        description?.url = DataMigrator.appGroupDirectory.appendingPathComponent("DataModel.sqlite")
        description?.shouldAddStoreAsynchronously = false
        description?.shouldInferMappingModelAutomatically = false
        description?.shouldMigrateStoreAutomatically = false
        description?.type = storeType
        return persistentContainer
    }()
    
    public lazy var mainContext: NSManagedObjectContext = {
        let context = self.persistentContainer.viewContext
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        context.shouldDeleteInaccessibleFaults = true
        return context
    }()
    
    public var bckgContext: NSManagedObjectContext {
        let context = self.persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.shouldDeleteInaccessibleFaults = true
        return context
    }

    
    // MARK: - Core Data Saving
    public func saveMainContext() {
        // Anything to save?
        guard mainContext.hasChanges else { return }

        do {
            try mainContext.save()
        } catch let error as NSError {
            fatalError("Unresolved error \(error), \(error.userInfo)")
        }
    }


//    //MARK: - Core Data Directories
//    // "Library/Application Support/Piwigo" inside the group container.
//    /// - The shared database and temporary files to upload are stored in the App Group
//    ///   container so that they can be used and shared by the app and the extensions.
//    lazy var appGroupDirectory: URL = {
//        // We use different App Groups:
//        /// - Development: one chosen by the developer
//        /// - Release: the official group.org.piwigo
//        #if DEBUG
//        let AppGroup = "group.net.lelievre-berna.piwigo"
//        #else
//        let AppGroup = "group.org.piwigo"
//        #endif
//
//        // Get path of group container
//        let fm = FileManager.default
//        let containerDirectory = fm.containerURL(forSecurityApplicationGroupIdentifier: AppGroup)
//        let piwigoURL = containerDirectory?.appendingPathComponent("Library")
//            .appendingPathComponent("Application Support")
//            .appendingPathComponent("Piwigo")
//
//        // Create the Piwigo directory in the container if needed
//        if !(fm.fileExists(atPath: piwigoURL?.path ?? "")) {
//            var errorCreatingDirectory: Error? = nil
//            do {
//                if let piwigoURL = piwigoURL {
//                    try fm.createDirectory(at: piwigoURL, withIntermediateDirectories: true, attributes: nil)
//                }
//            }
//            catch let errorCreatingDirectory {
//            }
//            if errorCreatingDirectory != nil {
//                fatalError("Unable to create Piwigo directory in App Group container.")
//            }
//        }
//
//        print("••> AppGroupDirectory: \(piwigoURL!)")
//        return piwigoURL!
//    }()
//
//    // "Library/Application Support/Piwigo" inside the Data Container of the Sandbox.
//    /// - This is where the incompatible Core Data stores are stored.
//    /// - The contents of this directory are backed up by iTunes and iCloud.
//    /// - This is the directory where the application used to store the Core Data store files
//    ///   and files to upload before the creation of extensions.
//    lazy var appSupportDirectory: URL = {
//        let fm = FileManager.default
//        let applicationSupportDirectory = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).last
//        let piwigoURL = applicationSupportDirectory?.appendingPathComponent("Piwigo")
//
//        // Create the Piwigo directory in "Library/Application Support" if needed
//        if !(fm.fileExists(atPath: piwigoURL?.path ?? "")) {
//            var errorCreatingDirectory: Error? = nil
//            do {
//                if let piwigoURL = piwigoURL {
//                    try fm.createDirectory(at: piwigoURL, withIntermediateDirectories: true, attributes: nil)
//                }
//            } catch let errorCreatingDirectory {
//            }
//            if errorCreatingDirectory != nil {
//                fatalError("Unable to create \"Piwigo\" directory in \"Library/Application Support\".")
//            }
//        }
//
//        print("••> AppSupportDirectory: \(piwigoURL!)")
//        return piwigoURL!
//    }()
//
//    // "Documents" inside the Data Container of the Sandbox.
//    /// - This is the directory where the application used to store the Core Data store files long ago.
//    lazy var appDocumentsDirectory: URL = {
//        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
//        let appDocumentsDirectory = urls[urls.count-1]
//
//        print("••> appDocumentsDirectory: \(appDocumentsDirectory)")
//        return appDocumentsDirectory
//    }()
}
