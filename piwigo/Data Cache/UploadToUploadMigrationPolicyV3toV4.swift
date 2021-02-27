//
//  UploadToUploadMigrationPolicyV3toV4.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/02/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import CoreData
import UIKit

let errorDomain = "Migration"

class UploadToUploadMigrationPolicyV3toV4:
  NSEntityMigrationPolicy {

    override func createDestinationInstances(forSource sInstance: NSManagedObject,
                                             in mapping: NSEntityMapping,
                                             manager: NSMigrationManager) throws {
        
        // Create an instance of the new destination object
        let description = NSEntityDescription.entity(forEntityName: "Upload",
                                                     in: manager.destinationContext)
        let newUpload = Upload(entity: description!,
                               insertInto: manager.destinationContext)

        // Create a traversePropertyMappings function that performs the task of iterating
        // over the property mappings if they are present in the migration
        func traversePropertyMappings(block: (NSPropertyMapping, String) -> Void) throws {
            
            if let attributeMappings = mapping.attributeMappings {
                for propertyMapping in attributeMappings {
                    if let destinationName = propertyMapping.name {
                            block(propertyMapping, destinationName)
                    } else {
                        // Case where the mappings file has been specified incorrectly
                        let message = "Upload destination not configured properly"
                        let userInfo = [NSLocalizedFailureReasonErrorKey: message]
                        throw NSError(domain: errorDomain,
                                      code: 0, userInfo: userInfo)
                    }
                }
            } else {
                let message = "No Upload Mappings found!"
                let userInfo = [NSLocalizedFailureReasonErrorKey: message]
                throw NSError(domain: errorDomain,
                              code: 0, userInfo: userInfo)
            }
        }

        // Most of the attribute migrations should be performed
        // using the expressions defined in the mapping model.
        try traversePropertyMappings { propertyMapping, destinationName in
            if let valueExpression = propertyMapping.valueExpression {
                let context: NSMutableDictionary = ["source": sInstance]
                guard let destinationValue = valueExpression.expressionValue(with: sInstance,
                                                                             context: context)
                else { return }
                newUpload.setValue(destinationValue, forKey: destinationName)
            }
        }

        // Try to get an instance of the dates.
        // Convert it to TimeInterval to populate the data in the new object.
        if let creationDate = sInstance.value(forKey: "creationDate") as? Date {
            newUpload.setValue(creationDate.timeIntervalSinceReferenceDate, forKey: "creationDate")
        } else {
            newUpload.setValue(TimeInterval(0), forKey: "creationDate")
        }
        if let requestDate = sInstance.value(forKey: "requestDate") as? Date {
            newUpload.setValue(requestDate.timeIntervalSinceReferenceDate, forKey: "requestDate")
        } else {
            newUpload.setValue(TimeInterval(0), forKey: "requestDate")
        }

        // The migration manager needs to know the connection between the source object,
        // the newly created destination object and the mapping.
        manager.associate(sourceInstance: sInstance,
                          withDestinationInstance: newUpload,
                          for: mapping)
    }
}
