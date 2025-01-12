//
//  ImageToSizesMigrationPolicy_0B_to_0C.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 16/05/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

//import os
import CoreData

let sizesErrorDomain = "Sizes Migration"

class ImageToSizesMigrationPolicy_0B_to_0C: NSEntityMigrationPolicy {
    
    // Logs migration activity
    /// sudo log collect --device --start '2023-04-07 15:00:00' --output piwigo.logarchive
//    @available(iOSApplicationExtension 14.0, *)
//    static let logger = Logger(subsystem: "org.piwigo.piwigoKit", category: "ImageToSizesMigrationPolicy_0B_to_0C")

    /**
     ImageToSizes custom migration performed following these steps:
     - Creates a Sizes instance in the destination context
     - Sets the values of the attributes from the source instance
     - Sets the relationship from the source instance
     - Associates the source instance with the destination instance
    */
    override func createDestinationInstances(forSource sInstance: NSManagedObject,
                                             in mapping: NSEntityMapping,
                                             manager: NSMigrationManager) throws {
        // Create Sizes destination instance
        let description = NSEntityDescription.entity(forEntityName: "Sizes", in: manager.destinationContext)
        let newSizes = Sizes(entity: description!, insertInto: manager.destinationContext)

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
                        let userInfo = [NSLocalizedFailureReasonErrorKey: message]
                        throw NSError(domain: sizesErrorDomain, code: 0, userInfo: userInfo)
                    }
                }
            } else {
                let message = "No Attribute Mappings found!"
                let userInfo = [NSLocalizedFailureReasonErrorKey: message]
                throw NSError(domain: sizesErrorDomain, code: 0, userInfo: userInfo)
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
            newSizes.setValue(destinationValue, forKey: destinationName)
        }
        
        // Add relationship from Image to Sizes
        // Core Data creates automatically the inverse relationship
        let newImages = manager.destinationInstances(forEntityMappingName: "ImageToImage", sourceInstances: [sInstance])
        if let newImage = newImages.first {
            newImage.setValue(newSizes, forKey: "sizes")
        }

        // Associate new Sizes object to Image request
//        if #available(iOSApplicationExtension 14.0, *) {
//            ImageToSizesMigrationPolicy_0B_to_0C.logger.notice("Image ► Sizes: \(newSizes)")
//        }
        manager.associate(sourceInstance: sInstance, withDestinationInstance: newSizes, for: mapping)
    }
}
