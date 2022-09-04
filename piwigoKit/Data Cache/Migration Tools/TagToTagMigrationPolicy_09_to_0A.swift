//
//  TagToTagMigrationPolicy_09_to_0A.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 27/08/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import CoreData

let tagErrorDomain = "Tag Migration"

/**
 TagToTag custom migration
 
 - Create Server instance in the Core Data store if needed and store it in userInfo
 - Set values of attributes from source instance
 - Set relationship to Server instance
 - Associate source instance with destination instance
*/
class TagToTagMigrationPolicy_09_to_0A: NSEntityMigrationPolicy {

    /**
     Creates a Server instance of the currently used server before migrating Tag and Upload entities.
     */
    override func begin(_ mapping: NSEntityMapping, with manager: NSMigrationManager) throws {
        // Check current server path
        guard let _ = URL(string: NetworkVars.serverPath) else {
            // Should never happen — discard this record
            return
        }

        // Create instance for the currently used server
        let description = NSEntityDescription.entity(forEntityName: "Server", in: manager.destinationContext)
        let newServer = Server(entity: description!, insertInto: manager.destinationContext)
        newServer.setValue(NetworkVars.serverPath, forKey: "path")
        newServer.setValue(UploadVars.serverFileTypes, forKey: "fileTypes")

        // Store new server instance in userInfo for later usage.
        manager.userInfo = [NetworkVars.serverPath : newServer]
    }
    
    /**
     Creates new Tag and sets its attributes from the old Tag instance.
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
        
        // Associate new Tag to old one
//        print("••> Tag to Tag migration:")
//        print("    old Tag: \(sInstance)")
//        print("    new Tag: \(newTag)")
        manager.associate(sourceInstance: sInstance,
                          withDestinationInstance: newTag,
                          for: mapping)
    }
    
    /**
     Called once new instances of Tags and Uploads have been created.
     - Adds relationship between a Tag and the current Server.
     - Adds relationship between a Tag and the Upload requests.
     */
    override func createRelationships(forDestination dInstance: NSManagedObject,
                                      in mapping: NSEntityMapping,
                                      manager: NSMigrationManager) throws {
        // Retrieve Server instance common to all tags
        guard let userInfo = manager.userInfo,
              let newServer = userInfo[NetworkVars.serverPath] as? NSManagedObject else {
            return
        }
        
        // Add relationship from Tag to Server
        // Core Data creates automatically the inverse relationship
        dInstance.setValue(newServer, forKey: "server")

        // Add relationship from Tag to Upload if any
        guard let tagId = dInstance.value(forKey: "tagId") as? Int32 else { return }
        let tagIdStr = String(tagId)
        let oldUploads = manager.sourceModel.entities.filter({$0.name == "Upload"})
            .filter({
                guard let tagIds = $0.value(forKey: "tagIds") as? String else { return false }
                return tagIds.components(separatedBy: ",").contains(tagIdStr)
            })
        dInstance.setValue(Set(oldUploads), forKey: "uploads")
        
        debugPrint(newServer)
        debugPrint(dInstance)
    }
}
