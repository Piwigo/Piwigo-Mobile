//
//  ImageToImageMigrationPolicy_0K_to_0L.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 8 August 2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import os
import CoreData
import Foundation
import MobileCoreServices

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers        // Requires iOS 14
#endif

class ImageToImageMigrationPolicy_0K_to_0L: NSEntityMigrationPolicy {
    // Constants
    let logPrefix = "Image 0K ► Image 0L"
    let numberFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = NumberFormatter.Style.percent
        return numberFormatter
    }()

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
     ImageToImage custom migration performed following these steps:
     - Sets the values of the attributes from the source instance
     - Sets the value of the attribute 'downloadUrl' to nil
     - Sets the relationship from the source instance
     - Associates the source instance with the destination instance
    */
    override func createDestinationInstances(forSource sInstance: NSManagedObject,
                                             in mapping: NSEntityMapping,
                                             manager: NSMigrationManager) throws {

        // Create destination instance
        let description = NSEntityDescription.entity(forEntityName: "Image", in: manager.destinationContext)
        let newImage = Image(entity: description!, insertInto: manager.destinationContext)

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
                        throw NSError(domain: imageErrorDomain, code: 0, userInfo: userInfo)
                    }
                }
            } else {
                let message = "No Attribute Mappings found!"
                if #available(iOSApplicationExtension 14.0, *) {
                    DataMigrator.logger.error("\(self.logPrefix): \(sInstance) > \(message)")
                }
                let userInfo = [NSLocalizedFailureReasonErrorKey: message]
                throw NSError(domain: imageErrorDomain, code: 0, userInfo: userInfo)
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
            newImage.setValue(destinationValue, forKey: destinationName)
        }
        
        // Set 'commentStr' string from 'comment' NSAttributedString
        if let comment = sInstance.value(forKey: "comment") as? NSAttributedString {
            newImage.setValue(comment.string, forKey: "commentStr")
        } else {
            newImage.setValue("", forKey: "commentStr")
        }
        
        // Initialise 'commentHTML' attributed string
        newImage.setValue(NSAttributedString(), forKey: "commentHTML")
        
        // Associate new Image object to old one
        manager.associate(sourceInstance: sInstance, withDestinationInstance: newImage, for: mapping)
        
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
