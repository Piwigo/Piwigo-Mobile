//
//  ServerProvider.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 21/08/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import CoreData

public class ServerProvider: NSObject {
    
    // MARK: - Singleton
    public static let shared = ServerProvider()
    
    
    // MARK: - Get/Create Server Object
    /**
     Returns the Server object at path.
     Will create the Server object if it does not exist before returning it.
     */
    public func getServer(inContext taskContext: NSManagedObjectContext,
                          atPath path:String = NetworkVars.serverPath) -> Server? {
        // Initialisation
        var currentServer: Server?
        
        // Perform the fetch
        taskContext.performAndWait {
            // Create a fetch request for the Server entity
            let fetchRequest = Server.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Server.path), ascending: true,
                                            selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]

            // Look for the server located at the provided path
            fetchRequest.predicate = NSPredicate(format: "path == %@", path)
            fetchRequest.fetchLimit = 1

            // Create a fetched results controller and set its fetch request and context.
            let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                managedObjectContext: taskContext,
                                                  sectionNameKeyPath: nil, cacheName: nil)
            // Perform the fetch.
            do {
                try controller.performFetch()
            } catch {
                fatalError("Unresolved error \(error)")
            }

            // Did we find a Server instance?
            if let cachedServer: Server = (controller.fetchedObjects ?? []).first {
                currentServer = cachedServer
            } else {
                // Create a Server object on the current queue context.
                guard let server = NSEntityDescription.insertNewObject(forEntityName: "Server",
                                                                       into: taskContext) as? Server else {
                    debugPrint(ServerError.creationError.localizedDescription)
                    return
                }
                
                // Populate the Server's properties using default values
                do {
                    try server.update(withPath: path)
                    currentServer = server
                }
                catch ServerError.wrongURL {
                    // Delete invalid Tag from the private queue context.
                    debugPrint(ServerError.wrongURL.localizedDescription)
                    taskContext.delete(server)
                }
                catch {
                    debugPrint(error.localizedDescription)
                    taskContext.delete(server)
                }
            }
        }
        
        return currentServer
    }
}
