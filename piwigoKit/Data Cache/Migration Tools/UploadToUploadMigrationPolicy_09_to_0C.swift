//
//  UploadToUploadMigrationPolicy_09_to_0C.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 04/06/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import os
import CoreData

let uploadErrorDomain = "Upload Migration"

class UploadToUploadMigrationPolicy_09_to_0C: NSEntityMigrationPolicy {
    
    // Logs migration activity
    /// sudo log collect --device --start '2023-04-07 15:00:00' --output piwigo.logarchive
    @available(iOSApplicationExtension 14.0, *)
    static let logger = Logger(subsystem: "org.piwigoKit", category: String(String(describing: UploadToUploadMigrationPolicy_09_to_0C.self)))

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
                        throw NSError(domain: uploadErrorDomain, code: 0, userInfo: userInfo)
                    }
                }
            } else {
                let message = "No Attribute Mappings found!"
                let userInfo = [NSLocalizedFailureReasonErrorKey: message]
                throw NSError(domain: uploadErrorDomain, code: 0, userInfo: userInfo)
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
        
        // Forget upload requests of images deleted from the Piwigo server
        if newUpload.value(forKey: "requestState") as? Int16 == 13 {
            if #available(iOSApplicationExtension 14.0, *) {
                UploadToUploadMigrationPolicy_09_to_0C.logger.notice("Upload ► Upload: \(sInstance) > Upload request of deleted image are non longer needed.")
            }
            return
        }
        
        // Replace "NSNotFound" author names with ""
        if newUpload.value(forKey: "author") as? String == "NSNotFound" {
            newUpload.setValue("", forKey: "author")
        }

        // Check server data stored in the source instance
        guard let serverPath = sInstance.value(forKeyPath: "serverPath") as? String,
              let serverFileTypes = sInstance.value(forKeyPath: "serverFileTypes") as? String,
              let _ = URL(string: serverPath) else {
            // We discard records whose server path is incorrect.
            if #available(iOSApplicationExtension 14.0, *) {
                UploadToUploadMigrationPolicy_09_to_0C.logger.notice("Upload ► Upload: \(sInstance) > Upload request instance w/ wrong serverPath!")
            }
            return
        }
        
        // Did we create a record of the currently used server?
        guard var userInfo = manager.userInfo else {
            if #available(iOSApplicationExtension 14.0, *) {
                UploadToUploadMigrationPolicy_09_to_0C.logger.notice("Upload ► Upload: userInfo should have been created in TagToTagMigrationPolicy_09_to_0C!")
            }
            return
        }

        // Is this a known server?
        if userInfo[serverPath] == nil {
            // Create instance for this additional server
            let description = NSEntityDescription.entity(forEntityName: "Server", in: manager.destinationContext)
            let newServer = Server(entity: description!, insertInto: manager.destinationContext)
            newServer.setValue(UUID().uuidString, forKey: "uuid")
            newServer.setValue(serverPath, forKey: "path")
            newServer.setValue(serverFileTypes, forKey: "fileTypes")

            // Store new server instance in userInfo for reuse.
            userInfo[serverPath] = newServer
            manager.userInfo = userInfo
        }
        
        // Can we reuse the user account?
        let userAccountKey = NetworkVars.username + " @ " + serverPath
        if let user = userInfo[userAccountKey] as? NSManagedObject {
            // Add relationship from Upload to User
            // Core Data creates automatically the inverse relationship
            newUpload.setValue(user, forKey: "user")
        }
        else if NetworkVars.username.isEmpty == false,
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
        
        // Associate new Upload object to old one
        if #available(iOSApplicationExtension 14.0, *) {
            UploadToUploadMigrationPolicy_09_to_0C.logger.notice("Upload ► Upload: \(sInstance) > \(newUpload)")
        }
        manager.associate(sourceInstance: sInstance, withDestinationInstance: newUpload, for: mapping)
    }
}
