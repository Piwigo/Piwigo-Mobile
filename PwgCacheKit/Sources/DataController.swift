//
//  DataController.swift
//  PwgCacheKit
//
//  Created by Eddy Lelièvre-Berna on 17/02/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import os
import Foundation
import CoreData
import PwgKit

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
        context.automaticallyMergesChangesFromParent = true
        context.shouldDeleteInaccessibleFaults = true
        context.name = "Background context"
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
            // For debugging purpose:
//            let stack = Thread.callStackSymbols
//                    .dropFirst()        // skip logCallStack itself
//                    .prefix(3)          // how many frames you want
//                    .joined(separator: "\n")
//                print("📍 Call stack:\n\(stack)")
            try save()
        }
        catch let error as NSError {
            // Will try later…
            reportSaveError(error)
        }
    }
    
    /// Only performs a save if there are changes to commit, and reports a failure to the caller.
    /// To be used when the caller cannot carry on without the data being persisted.
    /// Objects which are not saved remain invisible to the other contexts because
    /// background contexts are siblings of the view context, not children of it.
    public func saveIfNeededOrThrow() throws {
        // Anything to save?
        guard hasChanges
        else { return }

        // Save changes
        do {
            try save()
        }
        catch let error as NSError {
            // The caller decides what to do…
            reportSaveError(error)
            throw error
        }
    }

    private func reportSaveError(_ error: NSError) {
        #if DEBUG
        debugPrint("••> Could not save context: \(error.localizedDescription)")
        #endif
        // Multiple errors?
        if error.code == NSValidationMultipleErrorsError {
            let detailedErrors: [NSError] = error.userInfo[NSDetailedErrorsKey] as? [NSError] ?? []
            let errorCount = detailedErrors.count
            #if DEBUG
            debugPrint("••> \(errorCount) validation error\(errorCount == 1 ? "" : "s"):")
            #endif
            var printedErros: Set<String> = []
            for detailError in detailedErrors {
                guard !printedErros.contains(detailError.localizedDescription)
                else { continue }
                printedErros.insert(detailError.localizedDescription)
                #if DEBUG
                debugPrint("••> - \(detailError.localizedDescription)")
                #endif
            }
        }

        // Validation error?
        /// Contrary to e.g. a disk error, a validation error will not fix itself:
        /// the invalid object remains in the context and makes every subsequent save fail,
        /// i.e. the app silently stops storing data until it is relaunched.
        /// Discarding the pending changes is the only way to get that context working again.
        if error.domain == NSCocoaErrorDomain,
           (NSManagedObjectValidationError...NSValidationInvalidURIError).contains(error.code) {
            #if DEBUG
            debugPrint("••> Discarding the changes which could not be saved.")
            #endif
            rollback()
        }
    }
}

