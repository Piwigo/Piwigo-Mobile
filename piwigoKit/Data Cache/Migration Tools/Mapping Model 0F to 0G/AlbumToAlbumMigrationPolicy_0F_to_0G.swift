//
//  AlbumToAlbumMigrationPolicy_0F_to_0G.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 02/03/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import os
import CoreData

let albumErrorDomain = "Album Migration"

class AlbumToAlbumMigrationPolicy_0F_to_0G: NSEntityMigrationPolicy {
    // Contants
    let logPrefix = "Album 0F ► Album 0G"
    
    override func begin(_ mapping: NSEntityMapping, with manager: NSMigrationManager) throws {
        // Logs
        if #available(iOSApplicationExtension 14.0, *) {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = NumberFormatter.Style.percent
            let percent = numberFormatter.string(from: NSNumber(value: manager.migrationProgress)) ?? ""
            DataMigrator.logger.notice("\(self.logPrefix): Starting… (\(percent))")
        }
        // Progress bar
        DispatchQueue.main.async {
            let userInfo = ["progress" : NSNumber.init(value: manager.migrationProgress)]
            NotificationCenter.default.post(name: Notification.Name.pwgMigrationProgressUpdated,
                                            object: nil, userInfo: userInfo)
        }
    }
    
    /**
     AlbumToAlbum custom migration performed following these steps:
     - Creates a Sizes instance in the destination context
     - Sets the values of the attributes from the source instance
     - Sets the value of the attribute 'comment' to NSAttributedString() if nil in source
     - Sets the relationship from the source instance
     - Associates the source instance with the destination instance
    */
    override func createDestinationInstances(forSource sInstance: NSManagedObject,
                                             in mapping: NSEntityMapping,
                                             manager: NSMigrationManager) throws {

        // Create destination instance
        let description = NSEntityDescription.entity(forEntityName: "Album", in: manager.destinationContext)
        let newAlbum = Album(entity: description!, insertInto: manager.destinationContext)

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
                        throw NSError(domain: albumErrorDomain, code: 0, userInfo: userInfo)
                    }
                }
            } else {
                let message = "No Attribute Mappings found!"
                if #available(iOSApplicationExtension 14.0, *) {
                    DataMigrator.logger.error("\(self.logPrefix): \(sInstance) > \(message)")
                }
                let userInfo = [NSLocalizedFailureReasonErrorKey: message]
                throw NSError(domain: albumErrorDomain, code: 0, userInfo: userInfo)
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
            newAlbum.setValue(destinationValue, forKey: destinationName)
        }
        
        // Replace nil comments with NSAttributedString()
        if newAlbum.value(forKey: "comment") == nil {
            newAlbum.setValue(NSAttributedString(), forKey: "comment")
//            if #available(iOSApplicationExtension 14.0, *),
//               let albumId = sInstance.value(forKey: "pwgID") as? Int32 {
//                DataMigrator.logger.notice("\(self.logPrefix): Empty comment for album #\(albumId)")
//            }
        }

        // Associate comment object to Album request
        manager.associate(sourceInstance: sInstance, withDestinationInstance: newAlbum, for: mapping)
    }
    
    override func endInstanceCreation(forMapping mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        // Logs
        if #available(iOSApplicationExtension 14.0, *) {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = NumberFormatter.Style.percent
            let percent = numberFormatter.string(from: NSNumber(value: manager.migrationProgress)) ?? ""
            DataMigrator.logger.notice("\(self.logPrefix): Instances created (\(percent))")
        }
        // Progress bar
        DispatchQueue.main.async {
            let userInfo = ["progress" : NSNumber.init(value: manager.migrationProgress)]
            NotificationCenter.default.post(name: Notification.Name.pwgMigrationProgressUpdated,
                                            object: nil, userInfo: userInfo)
        }
    }
    
    override func endRelationshipCreation(forMapping mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        // Logs
        if #available(iOSApplicationExtension 14.0, *) {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = NumberFormatter.Style.percent
            let percent = numberFormatter.string(from: NSNumber(value: manager.migrationProgress)) ?? ""
            DataMigrator.logger.notice("\(self.logPrefix): Relationships created (\(percent))")
        }
        // Progress bar
        DispatchQueue.main.async {
            let userInfo = ["progress" : NSNumber.init(value: manager.migrationProgress)]
            NotificationCenter.default.post(name: Notification.Name.pwgMigrationProgressUpdated,
                                            object: nil, userInfo: userInfo)
        }
    }
    
    override func end(_ mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        // Logs
        if #available(iOSApplicationExtension 14.0, *) {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = NumberFormatter.Style.percent
            let percent = numberFormatter.string(from: NSNumber(value: manager.migrationProgress)) ?? ""
            DataMigrator.logger.notice("\(self.logPrefix): Completed (\(percent))")
        }
        // Progress bar
        DispatchQueue.main.async {
            let userInfo = ["progress" : NSNumber.init(value: manager.migrationProgress)]
            NotificationCenter.default.post(name: Notification.Name.pwgMigrationProgressUpdated,
                                            object: nil, userInfo: userInfo)
        }
    }
}
