//
//  ServerProvider.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 21/08/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import CoreData

public final class ServerProvider {
    
    public init() {}    // To make this class public

    // MARK: - Get/Create Server Object
    /**
     Returns the Server object at path.
     Will create the Server object if it does not exist before returning it.
     */
    private func fetchRequestOfServer(atPath path: String = NetworkVars.shared.serverPath) -> NSFetchRequest<Server> {
        // Create a fetch request sorted by path
        let fetchRequest = Server.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Server.path), ascending: true,
                                                         selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
        
        // Look for the Server located at the provided path
        fetchRequest.predicate = NSPredicate(format: "path == %@", path)
        fetchRequest.fetchLimit = 1
        return fetchRequest
    }
    
    public func getServer(inContext taskContext: NSManagedObjectContext,
                          atPath path: String = NetworkVars.shared.serverPath) throws -> Server? {
        // Synchronous execution
        try taskContext.performAndWait {
            // Create a fetch request for the Server entity
            let fetchRequest = fetchRequestOfServer(atPath: path)
            
            // Return the Server entity if possible
            let server = try taskContext.fetch(fetchRequest).first
            if let server { return server }
            
            // Create a Server object on the current queue context
            let newServer = Server(context: taskContext)

            // Return the new Server object or an error
            try newServer.update(withPath: path)
            taskContext.saveIfNeeded()
            return newServer
        }
    }
}
