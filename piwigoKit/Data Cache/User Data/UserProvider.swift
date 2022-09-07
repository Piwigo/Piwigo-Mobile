//
//  UserProvider.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 28/08/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import CoreData

public class UserProvider: NSObject {
    
    // MARK: - Core Data Providers
    private lazy var serverProvider: ServerProvider = {
        let provider : ServerProvider = ServerProvider()
        return provider
    }()


    // MARK: - Get/Set User Account Object
    /**
     Returns a User Account instance
     
     - Will create a Server object if it does not already exist.
     - Will create a User Account object if it does not already exist.
     */
    public func getUserAccount(inContext taskContext: NSManagedObjectContext,
                               atPath path: String = NetworkVars.serverPath,
                               withUsername username: String = NetworkVars.username) -> User? {
        // Initialisation
        var currentUser: User?
        
        // Perform the fetch
        taskContext.performAndWait {
            // Create a fetch request for the User entity
            let fetchRequest = User.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "username", ascending: true,
                                            selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]

            // Look for a user account of the server at path
            var andPredicates = [NSPredicate]()
            andPredicates.append(NSPredicate(format: "username == %@", username))
            andPredicates.append(NSPredicate(format: "server.path == %@", NetworkVars.serverPath))
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)

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

            // Did we find a User instance?
            let cachedUser: [User] = controller.fetchedObjects ?? []
            if cachedUser.isEmpty {
                // Get the Server managed object on the current queue context.
                // Create a User managed object on the current queue context.
                guard let server = serverProvider.getServer(inContext: taskContext, atPath: path),
                      let user = NSEntityDescription.insertNewObject(forEntityName: "User",
                                                                     into: taskContext) as? User else {
                    print(UserError.creationError.localizedDescription)
                    return
                }
                
                // Populate the User's properties using the data.
                do {
                    try user.update(username: username, onServer: server)
                    currentUser = user
                }
                catch UserError.emptyUsername {
                    // Delete invalid User from the current queue context.
                    print(UserError.emptyUsername.localizedDescription)
                    taskContext.delete(user)
                }
                catch {
                    print(error.localizedDescription)
                    taskContext.delete(user)
                }

                // Save all insertions from the context to the store.
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
                currentUser = cachedUser.first
            }
        }
        
        return currentUser
    }
}
