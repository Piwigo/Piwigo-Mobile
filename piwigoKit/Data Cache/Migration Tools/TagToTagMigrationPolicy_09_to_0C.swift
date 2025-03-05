//
//  TagToTagMigrationPolicy_09_to_0C.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 04/06/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import os
import CoreData

let tagErrorDomain = "Tag Migration"

class TagToTagMigrationPolicy_09_to_0C: NSEntityMigrationPolicy {
    // Contants
    let logPrefix = "Tag 09 ► Tag 0C"

    /**
     If needed, creates a Server instance of the currently used server before migrating Tag entities.
     ATTENTION: This class must be called before UploadToUploadMigrationPolicy_09_to_0A.
     */
    override func begin(_ mapping: NSEntityMapping, with manager: NSMigrationManager) throws {
        // Check current server path
        guard let _ = URL(string: NetworkVars.shared.serverPath) else {  return }

        // Create instance for the currently used server if needed
        let description = NSEntityDescription.entity(forEntityName: "Server", in: manager.destinationContext)
        let newServer = Server(entity: description!, insertInto: manager.destinationContext)
        newServer.setValue(UUID().uuidString, forKey: "uuid")
        newServer.setValue(NetworkVars.shared.serverPath, forKey: "path")
        newServer.setValue(NetworkVars.shared.serverFileTypes, forKey: "fileTypes")

        // Store new server instance in userInfo for reuse
        manager.userInfo = [NetworkVars.shared.serverPath : newServer]
    }
    
    /**
     TagToTag custom migration performed following these steps:
     - Creates a Tag instance in the destination context
     - Sets the values of the attributes from the source instance
     - Sets the relationship to the current Server instance created in begin()
     - Stores the new Tag instance in userInfo for reuse in UploadToUploadMigrationPolicy_09_to_0C
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
                        if #available(iOSApplicationExtension 14.0, *) {
                            DataMigrator.logger.error("\(self.logPrefix): \(sInstance) > \(message)")
                        }
                        let userInfo = [NSLocalizedFailureReasonErrorKey: message]
                        throw NSError(domain: tagErrorDomain, code: 0, userInfo: userInfo)
                    }
                }
            } else {
                let message = "No Attribute Mappings found!"
                if #available(iOSApplicationExtension 14.0, *) {
                    DataMigrator.logger.error("\(self.logPrefix): \(sInstance) > \(message)")
                }
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
              let newServer = userInfo[NetworkVars.shared.serverPath] as? NSManagedObject else { return }
        
        // Add relationship from Tag to Server
        // Core Data creates automatically the inverse relationship
        newTag.setValue(newServer, forKey: "server")
        
        // Add Tag destination instance to userInfo for reuse
        // in UploadToUploadMigrationPolicy_09_to_0C.swift
        if let tagId = sInstance.value(forKey: "tagId") {
            userInfo["\(tagId)"] = newTag
            manager.userInfo = userInfo
        }

        // Associate new Tag to old one
//        if #available(iOSApplicationExtension 14.0, *) {
//            DataMigrator.logger.notice("\(self.logPrefix): \(sInstance) > \(newTag)")
//        }
        manager.associate(sourceInstance: sInstance,
                          withDestinationInstance: newTag,
                          for: mapping)
    }
}
