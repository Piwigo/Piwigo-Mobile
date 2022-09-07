//
//  ServerProvider.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 21/08/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import CoreData

public class ServerProvider: NSObject {
    
    // MARK: - Get/Set Server Object
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
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "path", ascending: true,
                                            selector: #selector(NSString.caseInsensitiveCompare(_:)))]

            // Look for the server located at the provided path
            fetchRequest.predicate = NSPredicate(format: "path == %@", path)

            // Create a fetched results controller and set its fetch request, context, and delegate.
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
            let cachedServer: [Server] = controller.fetchedObjects ?? []
            if cachedServer.isEmpty {
                // Create a Server object on the current queue context.
                guard let server = NSEntityDescription.insertNewObject(forEntityName: "Server",
                                                                       into: taskContext) as? Server else {
                    print(ServerError.creationError.localizedDescription)
                    return
                }
                
                // Populate the Server's properties using default values
                do {
                    try server.update(withPath: path)
                    currentServer = server
                }
                catch ServerError.wrongURL {
                    // Delete invalid Tag from the private queue context.
                    print(ServerError.wrongURL.localizedDescription)
                    taskContext.delete(server)
                }
                catch {
                    print(error.localizedDescription)
                    taskContext.delete(server)
                }

                // Save insertion from the context to the store.
                if taskContext.hasChanges {
                    do {
                        try taskContext.save()
                        DispatchQueue.main.async {
                            DataController.shared.saveMainContext()
                        }
                    }
                    catch {
                        print("Error: \(error)\nCould not save Core Data context.")
                        return
                    }
                }
            } else {
                currentServer = cachedServer.first
            }
        }
        
        return currentServer
    }
}
