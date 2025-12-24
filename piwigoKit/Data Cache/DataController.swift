//
//  DataController.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 17/02/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import os
import Foundation
import CoreData

public final class DataController {

    // MARK: - Singleton
    public static let shared = DataController()
    
    // MARK: - Core Data Stack
    nonisolated private let persistentContainer: NSPersistentContainer
    
    // MARK: - Initialisation
    private init() {
        let model = NSManagedObjectModel.managedObjectModel(forVersion: DataMigrationVersion.current)
        let persistentContainer = NSPersistentContainer(name: "DataModel", managedObjectModel: model)
        let description = persistentContainer.persistentStoreDescriptions.first
        description?.url = DataDirectories.appGroupDirectory.appendingPathComponent("DataModel.sqlite")
        description?.shouldAddStoreAsynchronously = false
        description?.shouldInferMappingModelAutomatically = false
        description?.shouldMigrateStoreAutomatically = false
        description?.type = NSSQLiteStoreType
        self.persistentContainer = persistentContainer

        self.persistentContainer.loadPersistentStores { _, error in
            guard let error = error else { return }
            fatalError("••> Was unable to load store - \(error)")
        }
    }
    
    @MainActor
    public lazy var mainContext: NSManagedObjectContext = {
        let context = self.persistentContainer.viewContext
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        context.automaticallyMergesChangesFromParent = true
        context.shouldDeleteInaccessibleFaults = true
        context.name = "View context"
        return context
    }()
    
    nonisolated public func newTaskContext() -> NSManagedObjectContext {
        let context = self.persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        context.shouldDeleteInaccessibleFaults = true
        return context
    }
}


// MARK: - Core Data Saving
extension NSManagedObjectContext {
    /// Only performs a save if there are changes to commit.
    public func saveIfNeeded() {
        // Anything to save?
        guard hasChanges
        else { return }
        
        // Save changes
        do {
            try save()
        }
        catch let error as NSError {
            // Will try later…
            debugPrint("••> Could not save context: \(error.localizedDescription)")
            // Multiple errors?
            if error.code == NSValidationMultipleErrorsError {
                let detailedErrors: [NSError] = error.userInfo[NSDetailedErrorsKey] as? [NSError] ?? []
                let errorCount = detailedErrors.count
                debugPrint("••> \(errorCount) validation error\(errorCount == 1 ? "" : "s"):")
                var printedErros: Set<String> = []
                for detailError in detailedErrors {
                    guard !printedErros.contains(detailError.localizedDescription)
                    else { continue }
                    printedErros.insert(detailError.localizedDescription)
                    debugPrint("••> - \(detailError.localizedDescription)")
                }
            }
        }
    }
}
