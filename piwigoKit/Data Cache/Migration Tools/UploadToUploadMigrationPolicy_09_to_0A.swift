//
//  UploadToUploadMigrationPolicy_09_to_0A.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 22/08/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import CoreData

let userErrorDomain = "User Account Migration"

/**
 UploadToUpload custom migration
 
 - Create Server instance in the Core Data store if needed and store it in userInfo
 - Set values of attributes from source instance
 - Set relationship to User instance
 - Associate source instance with destination instance
*/
class UploadToUploadMigrationPolicy_09_to_0A: NSEntityMigrationPolicy {
    
    /**
     Creates new Upload request and sets its attributes from the old Upload instance.
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
              let _ = URL(string: serverPath),
              NetworkVars.username.isEmpty == false else {
            // If the user requested uploads to the non-current server,
            // we discard this record because we do not know the username of the account :=(
            debugPrint("••> Error: Upload request instance w/o serverPath or username!")
            return
        }
        
        // Retrieve the corresponding user account if possible
        guard let userInfo = manager.userInfo else { return }
        let userAccountKey = NetworkVars.username + " @ " + serverPath
        if let user = userInfo[userAccountKey] as? NSManagedObject {
            // Add relationship from Upload to User
            // Core Data creates automatically the inverse relationship
            newUpload.setValue(user, forKey: "user")
        }
        else {
            // Create User destination instance
            let description = NSEntityDescription.entity(forEntityName: "User", in: manager.destinationContext)
            let newUser = User(entity: description!, insertInto: manager.destinationContext)
            newUser.setValue(userAccountKey, forKey: "name")
            newUser.setValue(NetworkVars.username, forKey: "username")
            if let dateCreated = sInstance.value(forKey: "requestDate") as? TimeInterval {
                newUser.setValue(dateCreated, forKey: "lastUsed")
            }

            // Should we also create a server destination instance?
            if let server = userInfo[serverPath] {
                // Add relationship from User to Server
                // Core Data creates automatically the inverse relationship
                newUser.setValue(server, forKey: "server")
            }
            else {
                // Create instance for this server
                let description = NSEntityDescription.entity(forEntityName: "Server", in: manager.destinationContext)
                let newServer = Server(entity: description!, insertInto: manager.destinationContext)
                newServer.setValue(serverPath, forKey: "path")
                newServer.setValue(UploadVars.serverFileTypes, forKey: "fileTypes")

                // Add relationship from User to Server
                // Core Data creates automatically the inverse relationship
                newUser.setValue(newServer, forKey: "server")

                // Store new server instance in userInfo for later usage.
                manager.userInfo = [NetworkVars.serverPath : newServer]
            }
            
            // Store new user account instance in userInfo for later usage.
            manager.userInfo = [userAccountKey : newUser]
        }
        
        // Associate new Server object to Upload request
        print("••> Upload to Upload migration:")
        print("    old Upload: \(sInstance)")
        print("    new Upload: \(newUpload)")
        manager.associate(sourceInstance: sInstance, withDestinationInstance: newUpload, for: mapping)
    }
}
