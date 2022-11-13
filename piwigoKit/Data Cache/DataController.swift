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
    // "Library/Caches/Piwigo" in the AppGroup container.
    /// - Folder in which we store the images referenced in the Core Data store
    public static var cacheDirectory: URL = {
        let fm = FileManager.default
        do {
            // Get path of the Caches directory in the AppGroup container
            let cacheDirectory = DataMigrator.containerDirectory.appendingPathComponent("Library")
                .appendingPathComponent("Caches")

            // Append Piwigo
            let pwgDirectory = cacheDirectory.appendingPathComponent("Piwigo")

            // Create the Piwigo directory if needed
            if fm.fileExists(atPath: pwgDirectory.path) == false {
                try fm.createDirectory(at: pwgDirectory, withIntermediateDirectories: true, attributes: nil)
            }

            print("••> cacheDirectory: \(pwgDirectory)")
            return pwgDirectory
        } catch {
            fatalError("Unable to create the \"Caches/Piwgo\" directory (\(error.localizedDescription)")
        }
    }()

    public func saveMainContext() {
        // Anything to save?
        guard mainContext.hasChanges else { return }

        do {
            try mainContext.save()
        } catch let error as NSError {
            fatalError("Unresolved error \(error), \(error.userInfo)")
        }
    }
}
