//
//  UploadToUploadMigrationPolicy_0H_to_0J.swift
//  PwgCacheKit
//
//  Created by Eddy Lelièvre-Berna on 14 June 2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import os
import CoreData
import Foundation

final class UploadToUploadMigrationPolicy_0H_to_0J: NSEntityMigrationPolicy {
    // Constants
    let logPrefix = "Upload 0H ► Upload 0J"
    let numberFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = NumberFormatter.Style.percent
        return numberFormatter
    }()
    let defaultFileExtCaseValue: Int16 = FileExtCase.keep.rawValue

    override func begin(_ mapping: NSEntityMapping, with manager: NSMigrationManager) throws {
        // Logs
        let percent = numberFormatter.string(from: NSNumber(value: manager.migrationProgress)) ?? ""
        DataMigrator.logger.notice("\(self.logPrefix): Starting… (\(percent))")
        
        // Progress bar
        updateProgressBar(manager.migrationProgress)
        
        // Stop migration?
        if OperationQueue.current?.operations.first?.isCancelled ?? false {
            throw DataMigrationError.timeout
        }
    }

    /**
     UploadToUpload custom migration performed following these steps:
     - Lets the mapping model create the destination instance, set the values of
       its attributes and associate it with the source instance
     - Converts the old 'prefixFileNameBeforeUpload' and 'defaultPrefix' into
       'fileNamePrefixEncodedActions'
    */
    override func createDestinationInstances(forSource sInstance: NSManagedObject, in mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        // Create the destination instance, set the attributes whose value expression
        // is defined in the mapping model, and associate it with the source instance.
        try super.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)

        // Retrieve the destination instance created above
        guard let mappingName = mapping.name else {
            let message = "Entity mapping not configured properly!"
            DataMigrator.logger.error("\(self.logPrefix): \(sInstance) > \(message)")
            let userInfo = [NSLocalizedFailureReasonErrorKey: message]
            throw NSError(domain: uploadErrorDomain, code: 0, userInfo: userInfo)
        }
        let newUploads = manager.destinationInstances(forEntityMappingName: mappingName,
                                                      sourceInstances: [sInstance])

        // Set 'fileNamePrefixEncodedActions' from old 'defaultPrefix' if necessary
        if let prefixFileNameBeforeUpload = sInstance.value(forKey: "prefixFileNameBeforeUpload") as? Bool,
           prefixFileNameBeforeUpload,
           let defaultPrefix = sInstance.value(forKey: "defaultPrefix") as? String,
           let encodedPrefix = defaultPrefix.base64Encoded {
            let encodedAction = "\(RenameAction.ActionType.addText.rawValue):\(encodedPrefix)"
            newUploads.forEach { $0.setValue(encodedAction, forKey: "fileNamePrefixEncodedActions") }
        }

        // Stop migration?
        if OperationQueue.current?.operations.first?.isCancelled ?? false {
            throw DataMigrationError.timeout
        }
    }

    override func endInstanceCreation(forMapping mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        // Logs
        let percent = numberFormatter.string(from: NSNumber(value: manager.migrationProgress)) ?? ""
        DataMigrator.logger.notice("\(self.logPrefix): Instances created (\(percent))")
        
        // Progress bar
        updateProgressBar(manager.migrationProgress)
        
        // Stop migration?
        if OperationQueue.current?.operations.first?.isCancelled ?? false {
            throw DataMigrationError.timeout
        }
    }
    
    override func createRelationships(forDestination dInstance: NSManagedObject, in mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        try super.createRelationships(forDestination: dInstance, in: mapping, manager: manager)
        
        // Stop migration?
        if OperationQueue.current?.operations.first?.isCancelled ?? false {
            throw DataMigrationError.timeout
        }
    }
    
    override func endRelationshipCreation(forMapping mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        // Logs
        let percent = numberFormatter.string(from: NSNumber(value: manager.migrationProgress)) ?? ""
        DataMigrator.logger.notice("\(self.logPrefix): Relationships created (\(percent))")
        
        // Progress bar
        updateProgressBar(manager.migrationProgress)
        
        // Stop migration?
        if OperationQueue.current?.operations.first?.isCancelled ?? false {
            throw DataMigrationError.timeout
        }
    }
    
    override func end(_ mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        // Logs
        let percent = numberFormatter.string(from: NSNumber(value: manager.migrationProgress)) ?? ""
        DataMigrator.logger.notice("\(self.logPrefix): Completed (\(percent))")
        
        // Progress bar
        updateProgressBar(manager.migrationProgress)
        
        // Stop migration?
        if OperationQueue.current?.operations.first?.isCancelled ?? false {
            throw DataMigrationError.timeout
        }
    }
}
