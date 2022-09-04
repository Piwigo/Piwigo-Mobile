//
//  TagToTagMigrationPolicy_09_to_0A.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 27/08/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import CoreData

let tagErrorDomain = "Tag Migration"

class TagToTagMigrationPolicy_09_to_0A: NSEntityMigrationPolicy {

    /**
     If possible, creates a Server instance of the currently used server before migrating Tag entities.
     */
    override func begin(_ mapping: NSEntityMapping, with manager: NSMigrationManager) throws {
        // Check current server path
        guard let _ = URL(string: NetworkVars.serverPath) else {  return }

        // Create instance for the currently used server if needed
        let description = NSEntityDescription.entity(forEntityName: "Server", in: manager.destinationContext)
        let newServer = Server(entity: description!, insertInto: manager.destinationContext)
        newServer.setValue(NetworkVars.serverPath, forKey: "path")
        newServer.setValue(UploadVars.serverFileTypes, forKey: "fileTypes")

        // Store new server instance in userInfo for reuse
        manager.userInfo = [NetworkVars.serverPath : newServer]
    }
    
    /**
     TagToTag custom migration performed following these steps:
     - Creates a Tag instance in the destination context
     - Sets the values of the attributes from the source instance
     - Sets the relationship to the current Server instance created in begin()
     - Stores the new Tag instance in userInfo for reuse in UploadToUploadMigrationPolicy_09_to_0A
     - Associates the source instance with the destination instance
    */
    override func createDestinationInstances(forSource sInstance: NSManagedObject,
                                             in mapping: NSEntityMapping,
                                             manager: NSMigrationManager) throws {
        // Create destination instance
        let description = NSEntityDescription.entity(forEntityName: "Tag", in: manager.destinationContext)
        let newTag = Tag(entity: description!, insertInto: manager.destinationContext)

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
                        throw NSError(domain: tagErrorDomain, code: 0, userInfo: userInfo)
                    }
                }
            } else {
                let message = "No Attribute Mappings found!"
                let userInfo = [NSLocalizedFailureReasonErrorKey: message]
                throw NSError(domain: tagErrorDomain, code: 0, userInfo: userInfo)
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
            newTag.setValue(destinationValue, forKey: destinationName)
        }
        
        // Retrieve Server instance common to all tags
        guard var userInfo = manager.userInfo,
              let newServer = userInfo[NetworkVars.serverPath] as? NSManagedObject else { return }
        
        // Add relationship from Tag to Server
        // Core Data creates automatically the inverse relationship
        newTag.setValue(newServer, forKey: "server")
        
        // Add Tag destination instance to userInfo for reuse
        // in UploaddToUploadMigrationPolicy_09_to_0A.swift
        if let tagId = sInstance.value(forKey: "tagId") {
            userInfo["\(tagId)"] = newTag
            manager.userInfo = userInfo
        }

        // Associate new Tag to old one
        print("••> Tag to Tag migration:")
        print("    old Tag: \(sInstance)")
        print("    new Tag: \(newTag)")
        manager.associate(sourceInstance: sInstance,
                          withDestinationInstance: newTag,
                          for: mapping)
    }
}
