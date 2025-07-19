//
//  UploadToUploadMigrationPolicy_0J_to_0K.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 19 July 2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import os
import CoreData
import Foundation
import MobileCoreServices

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers        // Requires iOS 14
#endif

class UploadToUploadMigrationPolicy_0J_to_0K: NSEntityMigrationPolicy {
    // Constants
    let logPrefix = "Upload 0J ► Upload 0K"
    let numberFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = NumberFormatter.Style.percent
        return numberFormatter
    }()
    let defaultFileExtCaseValue: Int16 = FileExtCase.keep.rawValue

    override func begin(_ mapping: NSEntityMapping, with manager: NSMigrationManager) throws {
        // Logs
        if #available(iOSApplicationExtension 14.0, *) {
            let percent = numberFormatter.string(from: NSNumber(value: manager.migrationProgress)) ?? ""
            DataMigrator.logger.notice("\(self.logPrefix): Starting… (\(percent))")
        }
        
        // Progress bar
        updateProgressBar(manager.migrationProgress)
        
        // Stop migration?
        if OperationQueue.current?.operations.first?.isCancelled ?? false {
            throw DataMigrationError.timeout
        }
    }

    /**
     UploadToUpload custom migration performed following these steps:
     - Sets the values of the attributes from the source instance
     - Sets the relationship from the source instance
     - Associates the source instance with the destination instance
    */
    override func createDestinationInstances(forSource sInstance: NSManagedObject, in mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        try super.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)
        
        // Create destination instance
        let description = NSEntityDescription.entity(forEntityName: "Upload", in: manager.destinationContext)
        let newUpload = Upload(entity: description!, insertInto: manager.destinationContext)

        // Function iterating over the property mappings if they are present in the migration
        func traversePropertyMappings(block: (NSPropertyMapping, String) -> Void) throws {
            // Retrieve attribute mappings
            if let attributeMappings = mapping.attributeMappings {
                // Loop over all property mappings
                for propertyMapping in attributeMappings {
                    // Check that there exists a destination of that name
                    if let destinationName = propertyMapping.name {
                        // Set destination attribute value
                        block(propertyMapping, destinationName)
                    } else {
                        let message = "Attribute destination not configured properly!"
                        if #available(iOSApplicationExtension 14.0, *) {
                            DataMigrator.logger.error("\(self.logPrefix): \(sInstance) > \(message)")
                        }
                        let userInfo = [NSLocalizedFailureReasonErrorKey: message]
                        throw NSError(domain: uploadErrorDomain, code: 0, userInfo: userInfo)
                    }
                }
            } else {
                let message = "No Attribute Mappings found!"
                if #available(iOSApplicationExtension 14.0, *) {
                    DataMigrator.logger.error("\(self.logPrefix): \(sInstance) > \(message)")
                }
                let userInfo = [NSLocalizedFailureReasonErrorKey: message]
                throw NSError(domain: uploadErrorDomain, code: 0, userInfo: userInfo)
            }
        }

        // The attribute migrations are performed using the expressions defined in the mapping model.
        try traversePropertyMappings { propertyMapping, destinationName in
            // Retrieve source value expression
            guard let valueExpression = propertyMapping.valueExpression else { return }
            // Set destination value expression
            let context: NSMutableDictionary = ["source": sInstance]
            guard let destinationValue = valueExpression.expressionValue(with: sInstance, context: context) else { return }
            // Set attribute value
            newUpload.setValue(destinationValue, forKey: destinationName)
        }
        
        // Set 'fileType' from old 'fileName' to detect videos and already loaded PDF files
        if let fileName = sInstance.value(forKey: "fileName") as? String {
            let fileExt = URL(fileURLWithPath: fileName).pathExtension.lowercased()
            if fileExt.isEmpty {
                if let isVideo = sInstance.value(forKey: "isVideo") as? Bool, isVideo {
                    newUpload.setValue(pwgImageFileType.video.rawValue, forKey: "fileType")
                } else {
                    newUpload.setValue(pwgImageFileType.image.rawValue, forKey: "fileType")
                }
            } else {
                if #available(iOS 14.0, *) {
                    if let uti = UTType(filenameExtension: fileExt) {
                        if uti.conforms(to: .movie) {
                            newUpload.setValue(pwgImageFileType.video.rawValue, forKey: "fileType")
                        } else if uti.conforms(to: .pdf) {
                            newUpload.setValue(pwgImageFileType.pdf.rawValue, forKey: "fileType")
                        } else {
                            newUpload.setValue(pwgImageFileType.image.rawValue, forKey: "fileType")
                        }
                    } else {
                        newUpload.setValue(pwgImageFileType.image.rawValue, forKey: "fileType")
                    }
                } else {
                    // Fallback to previous version
                    if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExt as NSString, nil)?.takeRetainedValue() {
                        if UTTypeConformsTo(uti, kUTTypeMovie) {
                            newUpload.setValue(pwgImageFileType.video.rawValue, forKey: "fileType")
                        } else if UTTypeConformsTo(uti, kUTTypePDF) {
                            newUpload.setValue(pwgImageFileType.pdf.rawValue, forKey: "fileType")
                        } else {
                            newUpload.setValue(pwgImageFileType.image.rawValue, forKey: "fileType")
                        }
                    } else {
                        newUpload.setValue(pwgImageFileType.image.rawValue, forKey: "fileType")
                    }
                }
            }
        }

        // Associate new Upload object to old one
        manager.associate(sourceInstance: sInstance, withDestinationInstance: newUpload, for: mapping)
        
        // Stop migration?
        if OperationQueue.current?.operations.first?.isCancelled ?? false {
            throw DataMigrationError.timeout
        }
    }

    override func endInstanceCreation(forMapping mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        // Logs
        if #available(iOSApplicationExtension 14.0, *) {
            let percent = numberFormatter.string(from: NSNumber(value: manager.migrationProgress)) ?? ""
            DataMigrator.logger.notice("\(self.logPrefix): Instances created (\(percent))")
        }
        
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
        if #available(iOSApplicationExtension 14.0, *) {
            let percent = numberFormatter.string(from: NSNumber(value: manager.migrationProgress)) ?? ""
            DataMigrator.logger.notice("\(self.logPrefix): Relationships created (\(percent))")
        }
        
        // Progress bar
        updateProgressBar(manager.migrationProgress)
        
        // Stop migration?
        if OperationQueue.current?.operations.first?.isCancelled ?? false {
            throw DataMigrationError.timeout
        }
    }
    
    override func end(_ mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        // Logs
        if #available(iOSApplicationExtension 14.0, *) {
            let percent = numberFormatter.string(from: NSNumber(value: manager.migrationProgress)) ?? ""
            DataMigrator.logger.notice("\(self.logPrefix): Completed (\(percent))")
        }
        
        // Progress bar
        updateProgressBar(manager.migrationProgress)
        
        // Stop migration?
        if OperationQueue.current?.operations.first?.isCancelled ?? false {
            throw DataMigrationError.timeout
        }
    }
}
