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
    
    // Logs the loading of the store
    /// sudo log collect --device --start '2023-04-07 15:00:00' --output piwigo.logarchive
    static let logger = PwgLogger(subsystem: "org.piwigo.cacheKit", category: String(describing: DataController.self))
    
    // MARK: - Initialisation
    private init() {
        let model = NSManagedObjectModel.managedObjectModel(forVersion: DataMigrationVersion.current)
        let persistentContainer = NSPersistentContainer(name: "DataModel", managedObjectModel: model)
        let storeURL = DataDirectories.appGroupDirectory.appendingPathComponent("DataModel.sqlite")
        let description = persistentContainer.persistentStoreDescriptions.first
        description?.url = storeURL
        description?.shouldAddStoreAsynchronously = false
        description?.shouldInferMappingModelAutomatically = false
        description?.shouldMigrateStoreAutomatically = false
        description?.type = NSSQLiteStoreType
        self.persistentContainer = persistentContainer

        self.persistentContainer.loadPersistentStores { _, error in
            guard let error = error as NSError? else { return }
            /// The full error reaches the device log and the app group log files, which is
            /// what a TestFlight tester or a user willing to send a sysdiagnose can hand over.
            DataController.logger.fault("Was unable to load the store: \(error.storeLoadingDescription(of: storeURL))")
            /// The crash report itself carries none of it, so the cause is named by the
            /// function which traps. See StoreLoadingFailure.
            StoreLoadingFailure.trap(error)
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


// MARK: - Store Loading Failures
/**
 Traps a store which cannot be opened, from a function named after the cause.

 The crash reports collected by the App Store carry the symbolicated backtrace and
 nothing else: the message passed to `fatalError()` is dropped, and so are the name and
 the reason of an uncaught `NSException` — the v4.4 (703) reports of the `0F → 0H`
 migration hold no trace of the `NSInvalidArgumentException` which caused them. The one
 diagnosis which does reach App Store Connect is the name of the frame that trapped,
 which is why each cause traps from a function of its own.

 Each body ends in a different message on purpose: the linker folds functions which
 compile to the same code, and a folded frame is reported as `<deduplicated_symbol>`.
 */
enum StoreLoadingFailure {

    static func trap(_ error: NSError) -> Never {
        guard error.domain == NSCocoaErrorDomain
        else { storeFailedToLoadForAForeignReason(error) }

        switch error.code {
        case NSPersistentStoreIncompatibleVersionHashError,
             NSMigrationError, NSMigrationConstraintViolationError,
             NSMigrationMissingSourceModelError, NSMigrationMissingMappingModelError,
             NSMigrationManagerSourceStoreError, NSMigrationManagerDestinationStoreError,
             NSEntityMigrationPolicyError, NSInferredMappingModelError:
            storeWasWrittenByAnotherDataModel(error)
        case NSSQLiteError, NSPersistentStoreInvalidTypeError:
            storeWasRefusedBySQLite(error)
        case NSFileReadNoSuchFileError, NSFileNoSuchFileError:
            storeFileWasNotThere(error)
        case NSFileReadNoPermissionError, NSFileWriteNoPermissionError:
            storeFileCouldNotBeRead(error)
        case NSPersistentStoreOpenError, NSPersistentStoreTimeoutError:
            storeRefusedToOpen(error)
        default:
            storeFailedToLoadForAnUnclassifiedReason(error)
        }
    }

    /// The entity version hashes do not match the current model and the migration did not run.
    @inline(never) private static func storeWasWrittenByAnotherDataModel(_ error: NSError) -> Never {
        fatalError("••> Was unable to load store written by another data model - \(error)")
    }

    /// SQLite would not have the file: corrupt, truncated, or not a database at all.
    @inline(never) private static func storeWasRefusedBySQLite(_ error: NSError) -> Never {
        fatalError("••> Was unable to load store refused by SQLite - \(error)")
    }

    /// Nothing at the store URL, so the app group container is not the one expected.
    @inline(never) private static func storeFileWasNotThere(_ error: NSError) -> Never {
        fatalError("••> Was unable to load store whose file is missing - \(error)")
    }

    /// The file is there and unreadable, which data protection does while the device is locked.
    @inline(never) private static func storeFileCouldNotBeRead(_ error: NSError) -> Never {
        fatalError("••> Was unable to load store whose file cannot be read - \(error)")
    }

    /// Core Data could not open the store and gave no better reason.
    @inline(never) private static func storeRefusedToOpen(_ error: NSError) -> Never {
        fatalError("••> Was unable to load store which refused to open - \(error)")
    }

    /// A Cocoa error this switch does not know: its code is worth adding above.
    @inline(never) private static func storeFailedToLoadForAnUnclassifiedReason(_ error: NSError) -> Never {
        fatalError("••> Was unable to load store for an unclassified reason - \(error)")
    }

    /// An error raised outside NSCocoaErrorDomain.
    @inline(never) private static func storeFailedToLoadForAForeignReason(_ error: NSError) -> Never {
        fatalError("••> Was unable to load store for a foreign reason - \(error)")
    }
}


// MARK: - Store Loading Errors
extension NSError {
    /// Returns what identifies a store loading failure in the logs: the domain and code of
    /// the error, the reason Core Data gives, the error underlying it when there is one, and
    /// the size of the file the store was expected in.
    /// The path itself is left out — it only names the container of the moment.
    func storeLoadingDescription(of storeURL: URL) -> String {
        var description = "\(domain) \(code) - \(localizedDescription)"
        /// Core Data files its explanation under a plain "reason" key, not under
        /// NSLocalizedFailureReasonErrorKey, so both are read.
        for key in ["reason", NSLocalizedFailureReasonErrorKey] {
            if let reason = userInfo[key] as? String, description.contains(reason) == false {
                description += " | reason: \(reason)"
            }
        }
        if let underlying = userInfo[NSUnderlyingErrorKey] as? NSError {
            description += " | underlying: \(underlying.domain) \(underlying.code) - \(underlying.localizedDescription)"
        }
        if let attributes = try? FileManager.default.attributesOfItem(atPath: storeURL.path),
           let size = attributes[.size] as? Int64 {
            description += " | store: \(size) bytes"
        } else {
            description += " | store: unreachable"
        }
        return description
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

