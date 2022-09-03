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
    
    // MARK: - Core Data Providers
    private lazy var userProvider: UserProvider = {
        let provider : UserProvider = UserProvider()
        return provider
    }()

    private lazy var tagProvider: TagProvider = {
        let provider : TagProvider = TagProvider()
        return provider
    }()


    // MARK: - Create Destination Instances
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
              let username = sInstance.value(forKeyPath: "username") as? String,
              username.isEmpty == false else {
            // Should never happen — discard this record
            return
        }
        
        // Should we add this user's account to the store?
        let serverKey = username + " @ " + serverPath
        if let user = manager.userInfo?[AnyHashable(serverKey)] as? User {
            newUpload.setValue(user, forKey: "user")
        } else {
            // Create User destination instance
            let description = NSEntityDescription.entity(forEntityName: "User", in: manager.destinationContext)
            let newUser = User(entity: description!, insertInto: manager.destinationContext)
            
            // Get user instance
            let server = userProvider.getUserAccountObject(with: manager.destinationContext,
                                                           atPath: serverPath, withUsername: username)
            // Get tag instances
            let tags = tagProvider.getTags(withIDs: sInstance.value(forKeyPath: "tagIds") as! String,
                                           taskContext: manager.destinationContext)
            // Set key/value pairs
            newUpload.setValue(username, forKey: "username")
            newUpload.setValue(server, forKey: "server")
            newUpload.setValue(tags, forKey: "tags")
            
            // Store new user account instance in userInfo
            manager.userInfo?[AnyHashable(serverKey)] = newUser
        }
        
        // Associate new Server object to Upload request
        manager.associate(sourceInstance: sInstance, withDestinationInstance: newUpload, for: mapping)
    }
}
