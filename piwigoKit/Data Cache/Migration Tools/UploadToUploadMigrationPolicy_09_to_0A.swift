//
//  UploadToUploadMigrationPolicy_09_to_0A.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 22/08/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import CoreData

let userErrorDomain = "User Account Migration"

class UploadToUploadMigrationPolicy_09_to_0A: NSEntityMigrationPolicy {
    
    /**
     UploadToUpload custom migration following these steps:
     - creates an Upload request instance in the destination context
     - sets the values of the attributes from the source instance
     - if the server path is the current one:
        - creates a User instance and store it in userInfo for reuse
        - sets the relationship to the current User instance
        - sets the relationships to the already migrated tags
     - else:
        - creates another Server instance if it does not already exist.
        - associates the source instance with the destination instance
    */
    override func createDestinationInstances(forSource sInstance: NSManagedObject,
                                             in mapping: NSEntityMapping,
                                             manager: NSMigrationManager) throws {
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
                        let userInfo = [NSLocalizedFailureReasonErrorKey: message]
                        throw NSError(domain: userErrorDomain, code: 0, userInfo: userInfo)
                    }
                }
            } else {
                let message = "No Attribute Mappings found!"
                let userInfo = [NSLocalizedFailureReasonErrorKey: message]
                throw NSError(domain: userErrorDomain, code: 0, userInfo: userInfo)
            }
        }

        // Most of the attribute migrations are performed using the expressions defined in the mapping model.
        try traversePropertyMappings { propertyMapping, destinationName in
            // Retrieve source value expression
            guard let valueExpression = propertyMapping.valueExpression else { return }
            // Set destination value expression
            let context: NSMutableDictionary = ["source": sInstance]
            guard let destinationValue = valueExpression.expressionValue(with: sInstance, context: context) else { return }
            // Set attribute value
            newUpload.setValue(destinationValue, forKey: destinationName)
        }

        // Check server data stored in the source instance
        guard let serverPath = sInstance.value(forKeyPath: "serverPath") as? String,
              let _ = URL(string: serverPath) else {
            // We discard records whose server path is incorrect.
            debugPrint("••> Error: Upload request instance w/ wrong serverPath!")
            return
        }
        
        // Can we reuse the user account?
        guard var userInfo = manager.userInfo else { return }
        let userAccountKey = NetworkVars.username + " @ " + serverPath
        if let user = userInfo[userAccountKey] as? NSManagedObject {
            // Add relationship from Upload to User
            // Core Data creates automatically the inverse relationship
            newUpload.setValue(user, forKey: "user")
        }
        else if serverPath == NetworkVars.serverPath,
                NetworkVars.username.isEmpty == false,
                let server = userInfo[serverPath] as? NSManagedObject {
            // Create User destination instance…
            // …assuming that the current user account is the appropriate one.
            let description = NSEntityDescription.entity(forEntityName: "User", in: manager.destinationContext)
            let newUser = User(entity: description!, insertInto: manager.destinationContext)
            newUser.setValue(userAccountKey, forKey: "name")
            newUser.setValue(NetworkVars.username, forKey: "username")
            if let requestDate = sInstance.value(forKey: "requestDate") {
                newUser.setValue(requestDate, forKey: "lastUsed")
            }
            
            // Add relationship from User to Server
            // Core Data creates automatically the inverse relationship
            newUser.setValue(server, forKey: "server")

            // Store new user account instance in userInfo for reuse
            userInfo[userAccountKey] = newUser
            manager.userInfo = userInfo

            // Add relationship from Upload to User
            // Core Data creates automatically the inverse relationship
            newUpload.setValue(newUser, forKey: "user")
        }
        else if userInfo[serverPath] == nil {
            // Create instance of this server for later use
            let description = NSEntityDescription.entity(forEntityName: "Server", in: manager.destinationContext)
            let newServer = Server(entity: description!, insertInto: manager.destinationContext)
            newServer.setValue(serverPath, forKey: "path")
            newServer.setValue(UploadVars.serverFileTypes, forKey: "fileTypes")

            // Store new server instance in userInfo for reuse.
            userInfo[NetworkVars.serverPath] = newServer
            manager.userInfo = userInfo
        }
        
        // Are there Tags of the current server associated to this Upload request?
        // Tags associations to another server will be lost.
        if serverPath == NetworkVars.serverPath,
           let tagIds = sInstance.value(forKey: "tagIds") as? String,
           tagIds.isEmpty == false {
            // List of Tag IDs attached to the source instance
            let tagList = tagIds.components(separatedBy: ",")
            // Corresponding list of Tags for destination instance
            var tags = Set<NSManagedObject>()
            for tagId in tagList {
                if let tag = userInfo[tagId] as? NSManagedObject {
                    tags.insert(tag)
                }
            }

            // Add relationship from Upload to Tags
            // Core Data creates automatically the inverse relationship
            newUpload.setValue(tags, forKey: "tags")
        }
        
        // Associate new Server object to Upload request
        print("••> Upload to Upload migration:")
        print("    old Upload: \(sInstance)")
        print("    new Upload: \(newUpload)")
        manager.associate(sourceInstance: sInstance, withDestinationInstance: newUpload, for: mapping)
    }
}
