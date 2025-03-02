//
//  ImageToImageMigrationPolicy_0F_to_0G.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 02/03/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import os
import CoreData
import Foundation

let imageErrorDomain = "Image Migration"

class ImageToImageMigrationPolicy_0F_to_0G: NSEntityMigrationPolicy {
    // Contants
    let logPrefix = "Image 0F ► Image 0G: "
    
    /**
     AlbumToAlbum custom migration performed following these steps:
     - Creates a Sizes instance in the destination context
     - Sets the values of the attributes from the source instance
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
            newImage.setValue(destinationValue, forKey: destinationName)
        }
        
        // Replace nil title with NSAttributedString()
        if newImage.value(forKey: "title") == nil {
            newImage.setValue(NSAttributedString(), forKey: "title")
            if #available(iOSApplicationExtension 14.0, *),
               let imageId = sInstance.value(forKey: "pwgID") as? Int64 {
                DataMigrator.logger.notice("\(self.logPrefix): empty title for image #\(imageId)")
            }
        }

        // Replace nil comments with NSAttributedString()
        if newImage.value(forKey: "comment") == nil {
            newImage.setValue(NSAttributedString(), forKey: "comment")
            if #available(iOSApplicationExtension 14.0, *),
               let imageId = sInstance.value(forKey: "pwgID") as? Int64 {
                DataMigrator.logger.notice("\(self.logPrefix): empty comment for image #\(imageId)")
            }
        }
        
        // Create downloadUrl attribute
        newImage.setValue(nil, forKey: "downloadUrl")
        
        // Associate comment object to Album request
        manager.associate(sourceInstance: sInstance, withDestinationInstance: newImage, for: mapping)
    }
}
