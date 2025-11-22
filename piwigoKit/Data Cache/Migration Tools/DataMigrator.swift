//
//  DataMigrator.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 28/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import os
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
public final class DataMigrator: NSObject {
    
    // SQL database filename
    enum storeExtension: String, CaseIterable {
        case sqlite = "sqlite"
        case sqliteShm = "sqlite-shm"
        case sqliteWAL = "sqlite-wal"
    }
    
    let SQLfileName = "DataModel" + ".\(storeExtension.sqlite.rawValue)"
    var timeCounter = CFAbsoluteTime.zero
    
    // Logs migration activity
    /// sudo log collect --device --start '2023-04-07 15:00:00' --output piwigo.logarchive
    static let logger = Logger(subsystem: "org.piwigo.piwigoKit", category: String(describing: DataMigrator.self))
    
    // MARK: - Migration Required?
    public func requiresMigration() -> Bool {
        // URL of the store in the App Group directory
        let storeURL = DataDirectories.appGroupDirectory
            .appendingPathComponent(SQLfileName)
        
        // Move the very old store to the new folder if needed
        var oldStoreURL = DataDirectories.appDocumentsDirectory
            .appendingPathComponent(SQLfileName)
        if requiresMigration(at: oldStoreURL, toVersion: DataMigrationVersion.current) {
            return true
        }
        
        // Move the old store to the new folder if needed
        oldStoreURL = DataDirectories.appSupportDirectory
            .appendingPathComponent(SQLfileName)
        if requiresMigration(at: oldStoreURL, toVersion: DataMigrationVersion.current) {
            return true
        }
        
        // Migrate store to new data model if needed
        if requiresMigration(at: storeURL, toVersion: DataMigrationVersion.current) {
            return true
        }
        
        // No migration required
        return false
    }
    
    private func requiresMigration(at storeURL: URL, toVersion version: DataMigrationVersion) -> Bool {
        guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL)
        else { return false }
        
        return (DataMigrationVersion.compatibleVersionForStoreMetadata(metadata) != version)
    }
    
    
    // MARK: - Perform Migration
    public func migrateStore() throws {
        // Initialise time counter
        timeCounter = CFAbsoluteTimeGetCurrent()
        DataMigrator.logger.notice("Migration started…")
        
        // URL of the store in the App Group directory
        let storeURL = DataDirectories.appGroupDirectory
            .appendingPathComponent(SQLfileName)
        
        // Move the very old store to the new folder if needed
        var oldStoreURL = DataDirectories.appDocumentsDirectory
            .appendingPathComponent(SQLfileName)
        if requiresMigration(at: oldStoreURL, toVersion: DataMigrationVersion.current) {
            // Perform the migration (version after version)
            do {
                try migrateStore(at: oldStoreURL,
                                 toVersion: DataMigrationVersion.current, at: storeURL)
                // Progress bar
                updateProgressBar(1)

                // Log time needed to perform the migration
                let duration = CFAbsoluteTimeGetCurrent() - timeCounter
                DataMigrator.logger.notice("Migration completed in \(duration) s")
                return
            } catch {
                let duration = CFAbsoluteTimeGetCurrent() - timeCounter
                DataMigrator.logger.notice("Migration failed after \(duration) s")
                throw error
            }
        }
        
        // Move the old store to the new folder if needed
        oldStoreURL = DataDirectories.appSupportDirectory
            .appendingPathComponent(SQLfileName)
        if requiresMigration(at: oldStoreURL, toVersion: DataMigrationVersion.current) {
            // Perform the migration (version after version)
            do {
                try migrateStore(at: oldStoreURL,
                                 toVersion: DataMigrationVersion.current, at: storeURL)
                
                // Move Upload folder to container if needed
                self.moveFilesToUpload()
                
                // Progress bar
                updateProgressBar(1)

                // Log time needed to perform the migration
                let duration = CFAbsoluteTimeGetCurrent() - timeCounter
                DataMigrator.logger.notice("Migration completed in \(duration) s")
                return
            } catch {
                let duration = CFAbsoluteTimeGetCurrent() - timeCounter
                DataMigrator.logger.notice("Migration failed after \(duration) s")
                throw error
            }
        }
        
        // Migrate store to new data model if needed
        if requiresMigration(at: storeURL, toVersion: DataMigrationVersion.current) {
            // Perform the migration (version after version)
            do {
                try migrateStore(at: storeURL,
                                 toVersion: DataMigrationVersion.current, at: storeURL)
                // Progress bar
                updateProgressBar(1)

                // Log time needed to perform the migration
                let duration = CFAbsoluteTimeGetCurrent() - timeCounter
                DataMigrator.logger.notice("Migration completed in \(duration) s")
                return
            } catch {
                let duration = CFAbsoluteTimeGetCurrent() - timeCounter
                DataMigrator.logger.notice("Migration failed after \(duration) s")
                throw error
            }
        }
    }
    
    private func migrateStore(at oldStoreURL: URL, toVersion version: DataMigrationVersion, at newStoreURL: URL) throws {
        // Backup the store so that we can restore it if the migration could not be completed
        backupStore(storeURL: oldStoreURL)
        
        // Force WAL checkpoint
        do {
            try forceWALCheckpointingForStore(at: oldStoreURL)
        } catch {
            restoreStore(storeURL: oldStoreURL)
            throw error
        }
        
        // Backup the checkpointed store so that we can restore a checkpointed version
        // if the migration could not be completed
        backupStore(storeURL: oldStoreURL)
        
        // Initialisation
        var currentURL = oldStoreURL
        let migrationSteps = self.migrationStepsForStore(at: oldStoreURL, toVersion: version)
        if migrationSteps.isEmpty {
            DataMigrator.logger.notice("No migration steps found.")
            return
        }
        
        // Loop over the migration steps
        for (index, migrationStep) in migrationSteps.enumerated() {
            DataMigrator.logger.notice("Migration step \(index + 1)/\(migrationSteps.count): Starting…")
            do {
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
                    try manager.migrateStore(from: currentURL, type: .sqlite, options: nil,
                                             mapping: migrationStep.mappingModel,
                                             to: tempStoreURL, type: .sqlite, options: nil)
                } catch let error {
                    // Timeout?
                    if let error = error as? DataMigrationError, error == .timeout {
                        restoreStore(storeURL: oldStoreURL)
                        throw error
                    }
                    
                    // Move store to directory of incompatible stores
                    moveIncompatibleStore(storeURL: currentURL)
                    DataMigrator.logger.notice("Failed attempting to migrate from \(migrationStep.sourceModel) to \(migrationStep.destinationModel), error: \(error)")
                    throw error
                }
                
                // Destroy intermediate step's store
                if ![oldStoreURL, newStoreURL].contains(currentURL) {
                    NSPersistentStoreCoordinator.destroyStore(at: currentURL)
                }
                
                // Use URL of migrated store for next step
                currentURL = tempStoreURL
            }
            
            DataMigrator.logger.notice("Migration step \(index + 1)/\(migrationSteps.count): Completed")
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
    
    
    // MARK: - File Management
    private func backupStore(storeURL: URL) {
        let fm = FileManager.default
        let appBackupStoresDirectory = DataDirectories.appBackupDirectory
        
        // Delete old backup files so that we won't restore files from mixed versions
        storeExtension.allCases.forEach { ext in
            let backupURL = appBackupStoresDirectory
                .appendingPathComponent(storeURL.lastPathComponent)
                .deletingPathExtension().appendingPathExtension(ext.rawValue)
            try? fm.removeItem(at: backupURL)
        }
        
        // Loop over all files of the data store
        storeExtension.allCases.forEach { ext in
            // URL of the file to backup
            let fileURL = storeURL.deletingPathExtension().appendingPathExtension(ext.rawValue)
            
            // Backup the file if it exists
            if fm.fileExists(atPath: fileURL.path) {
                let backupURL = appBackupStoresDirectory
                    .appendingPathComponent(fileURL.lastPathComponent)
                do {
                    try fm.copyItem(at: fileURL, to: backupURL)
                }
                catch let error {
                    DataMigrator.logger.notice("Unable to backup data store: \(error.localizedDescription)")
                }
            }
        }
    }
    
    public func restoreStore(storeURL: URL) {
        let fm = FileManager.default
        let appBackupStoresDirectory = DataDirectories.appBackupDirectory
        
        // Loop over all files of the data store
        storeExtension.allCases.forEach { ext in
            // URL of the file to restore
            let fileURL = storeURL.deletingPathExtension().appendingPathExtension(ext.rawValue)
            
            // Check if the backup file exists
            let restoreURL = appBackupStoresDirectory
                .appendingPathComponent(fileURL.lastPathComponent)
            if fm.fileExists(atPath: restoreURL.path) {
                // Restore the data store from the Piwigo/Backup directory
                try? fm.removeItem(at: fileURL)
                do {
                    try fm.copyItem(at: restoreURL, to: fileURL)
                }
                catch let error {
                    DataMigrator.logger.notice("Unable to restore data store: \(error.localizedDescription)")
                }
             }
        }
    }
    
    private func moveIncompatibleStore(storeURL: URL) {
        let fm = FileManager.default
        let appIncompatibleStoresDirectory = DataDirectories.appIncompatibleDirectory
                
        // Rename files with current date
        let dateFormatter = DateFormatter()
        dateFormatter.formatterBehavior = .behavior10_4
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let nameForIncompatibleStore = "\(dateFormatter.string(from: Date()))"
        
        // Loop over all files of the data store
        storeExtension.allCases.forEach { ext in
            // URL of the file to move
            let fileURL = storeURL.deletingPathExtension().appendingPathExtension(ext.rawValue)
            
            // Move this file if it exists
            if fm.fileExists(atPath: fileURL.path) {
                let corruptURL = appIncompatibleStoresDirectory
                    .appendingPathComponent(nameForIncompatibleStore)
                    .appendingPathExtension(ext.rawValue)
                
                // Move the corrupt data store
                try? fm.removeItem(at: corruptURL)
                do {
                    try fm.moveItem(at: storeURL, to: corruptURL)
                } catch let error {
                    DataMigrator.logger.notice("Unable to move a corrupted data store: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func moveFilesToUpload() {
        let fm = FileManager.default
        let oldURL = DataDirectories.appSupportDirectory
            .appendingPathComponent("Uploads")
        let newURL = DataDirectories.appUploadsDirectory
                
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
            DataMigrator.logger.notice("Unable to move content of Uploads directory: \(error.localizedDescription)")
        }
    }
    
    
    // MARK: - WAL Checkpointing
    private func forceWALCheckpointingForStore(at storeURL: URL) throws {
        guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL),
              let currentModel = NSManagedObjectModel.compatibleModelForStoreMetadata(metadata)
        else { return }
        
        DataMigrator.logger.notice("WAL checkpointing: Starting…")
        do {
            let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: currentModel)
            let options = [NSSQLitePragmasOption: ["journal_mode": "DELETE"]]
            let store = persistentStoreCoordinator.addPersistentStore(at: storeURL, options: options)
            try persistentStoreCoordinator.remove(store)
            let duration = CFAbsoluteTimeGetCurrent() - timeCounter
            DataMigrator.logger.notice("WAL checkpointing: Completed in \(duration) s")
        }
        catch let error {
            DataMigrator.logger.notice("WAL checkpointing failed: \(error.localizedDescription)")
            throw error
        }
    }
}


// MARK: - Model Version Compatibility
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
                let logPrefix = "Trying to guess data model from app version \(appVersion) smaller than "
                if appVersion.compare("2.5", options: .numeric) == .orderedAscending {
                    DataMigrator.logger.error("\(logPrefix) 2.5.")
                    return .version01
                }
                else if appVersion.compare("2.5.2", options: .numeric) == .orderedAscending {
                    DataMigrator.logger.error("\(logPrefix) 2.5.2")
                    return .version03
                }
                else if appVersion.compare("2.6", options: .numeric) == .orderedAscending {
                    DataMigrator.logger.error("\(logPrefix) 2.6")
                    return .version04
                }
                else if appVersion.compare("2.6.2", options: .numeric) == .orderedAscending {
                    DataMigrator.logger.error("\(logPrefix) 2.6.2")
                    return .version06
                }
                else if appVersion.compare("2.7", options: .numeric) == .orderedAscending {
                    DataMigrator.logger.error("\(logPrefix) 2.7")
                    return .version07
                }
                else if appVersion.compare("2.12", options: .numeric) == .orderedAscending {
                    DataMigrator.logger.error("\(logPrefix) 2.12")
                    return .version08
                }
                else if appVersion.compare("3.0", options: .numeric) == .orderedAscending {
                    DataMigrator.logger.error("\(logPrefix) 3.0")
                    return .version09
                }
                else if appVersion.compare("3.2", options: .numeric) == .orderedAscending {
                    DataMigrator.logger.error("\(logPrefix) 3.2")
                    return .version0C
                }
                else if appVersion.compare("3.3", options: .numeric) == .orderedAscending {
                    DataMigrator.logger.error("\(logPrefix) 3.3")
                    return .version0F
                }
                else if appVersion.compare("3.4", options: .numeric) == .orderedAscending {
                    DataMigrator.logger.error("\(logPrefix) 3.4")
                    return .version0H
                }
                else if appVersion.compare("3.5", options: .numeric) == .orderedAscending {
                    DataMigrator.logger.error("\(logPrefix) 3.5")
                    return .version0J
                }
                return .version0L
            }
        }
        return compatibleVersion
    }
}


// MARK: - Utilities
extension DataMigrator {
    // Updates the progress bar of the DataMigrationViewController
    func updateProgressBar(_ progress: Float) {
        DispatchQueue.main.async {
            let userInfo = ["progress" : NSNumber.init(value: progress)]
            NotificationCenter.default.post(name: Notification.Name.pwgMigrationProgressUpdated,
                                            object: nil, userInfo: userInfo)
        }
    }
    
    //    private static func logError(_ message: String, file: String = #file, function: String = #function, line: UInt = #line) {
    //        DataMigrator.logger.debug("\(file):\(function):\(line): \(message)")
    //    }
    
    func queueName() -> String {
        if let currentOperationQueue = OperationQueue.current {
            if let currentDispatchQueue = currentOperationQueue.underlyingQueue {
                return "dispatch queue: \(currentDispatchQueue.label.nonEmpty ?? currentDispatchQueue.description)"
            }
            else {
                return "operation queue: \(currentOperationQueue.name?.nonEmpty ?? currentOperationQueue.description)"
            }
        }
        else {
            let currentThread = Thread.current
            return "thread: \(currentThread.name?.nonEmpty ?? currentThread.description)"
        }
    }
}

extension String {
    /// Returns this string if it is not empty, else `nil`.
    var nonEmpty: String? {
        if self.isEmpty {
            return nil
        }
        else {
            return self
        }
    }
}
