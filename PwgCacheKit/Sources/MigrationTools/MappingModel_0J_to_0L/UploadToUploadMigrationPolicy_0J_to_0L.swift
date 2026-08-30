//
//  UploadToUploadMigrationPolicy_0J_to_0L.swift
//  PwgCacheKit
//
//  Created by Eddy Lelièvre-Berna on 19 July 2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import os
import CoreData
import Foundation
import UniformTypeIdentifiers

final class UploadToUploadMigrationPolicy_0J_to_0L: NSEntityMigrationPolicy {
    // Constants
    let logPrefix = "Upload 0J ► Upload 0L"
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
     - Sets 'fileType' from the old 'fileName' and 'isVideo'
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

        // Set 'fileType' from old 'fileName' to detect videos and already loaded PDF files
        if let fileName = sInstance.value(forKey: "fileName") as? String {
            let fileExt = URL(fileURLWithPath: fileName).pathExtension.lowercased()
            let fileType: pwgImageFileType
            if fileExt.isEmpty {
                let isVideo = sInstance.value(forKey: "isVideo") as? Bool ?? false
                fileType = isVideo ? .video : .image
            } else if let uti = UTType(filenameExtension: fileExt) {
                if uti.conforms(to: .movie) {
                    fileType = .video
                } else if uti.conforms(to: .pdf) {
                    fileType = .pdf
                } else {
                    fileType = .image
                }
            } else {
                fileType = .image
            }
            newUploads.forEach { $0.setValue(fileType.rawValue, forKey: "fileType") }
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
