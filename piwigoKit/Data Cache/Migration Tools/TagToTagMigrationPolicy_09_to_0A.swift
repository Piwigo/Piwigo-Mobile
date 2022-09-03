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
    
    // MARK: - Constants
    let serverKey = "currentServer"

    
    // MARK: - Core Data Providers
    private lazy var serverProvider: ServerProvider = {
        let provider : ServerProvider = ServerProvider()
        return provider
    }()


    // MARK: - Create Destination Instances
    override func begin(_ mapping: NSEntityMapping, with manager: NSMigrationManager) throws {
        // Initialise manager's userInfo with instance of current server
        if let server = serverProvider.getServerObject(with: manager.destinationContext) {
            let userInfo = [serverKey : server]
            manager.userInfo = userInfo
        }
    }
    
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

        // Most of the attribute migrations are performed using the expressions defined in the mapping model.
        try traversePropertyMappings { propertyMapping, destinationName in
            // Retrieve source value expression
            guard let valueExpression = propertyMapping.valueExpression else { return }
            // Set destination value expression
            let context: NSMutableDictionary = ["source": sInstance]
            guard let destinationValue = valueExpression.expressionValue(with: sInstance, context: context) else { return }
            // Set attribute value
            newTag.setValue(destinationValue, forKey: destinationName)
        }

        // Check current server path
        guard let _ = URL(string: NetworkVars.serverPath) else {
            // Should never happen — discard this record
            return
        }
        
        // Should we add this server to the store?
        if let server = manager.userInfo?[AnyHashable(serverKey)] as? Server {
            newTag.setValue(server, forKey: "server")
        }
        
        // Associate new Server object to Upload request
        manager.associate(sourceInstance: sInstance, withDestinationInstance: newTag, for: mapping)
    }
}
