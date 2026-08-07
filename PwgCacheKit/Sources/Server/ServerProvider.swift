//
//  ServerProvider.swift
//  PwgCacheKit
//
//  Created by Eddy Lelièvre-Berna on 21/08/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import CoreData
import PwgKit

public final class ServerProvider {
    
    public init() {}    // To make this class public
    
    // MARK: - Fetch Request
    // A server is uniquely identified by its path
    fileprivate func fetchRequestOfServer(atPath path: String = ServerVars.shared.serverPath) -> NSFetchRequest<Server> {
        // Create a fetch request sorted by path
        let fetchRequest = Server.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Server.path), ascending: true,
                                                         selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
        
        // Look for the Server located at the provided path
        fetchRequest.predicate = NSPredicate(format: "path == %@", path)
        fetchRequest.fetchLimit = 1
        return fetchRequest
    }
    
    
    // MARK: - Create/Get Current Server Object
    // Get or create a Server object in cache for the current path
    public func getOrCreateCurrentServer(inContext taskContext: NSManagedObjectContext) throws(PwgKitError) -> Server {
        // Do {} below is used to allow typed throws
        do {
            // Synchronous execution
            return try taskContext.performAndWait { () -> Server in
                // Create a fetch request for the Server entity
                let fetchRequest = fetchRequestOfServer(atPath: ServerVars.shared.serverPath)
                fetchRequest.returnsObjectsAsFaults = false
                fetchRequest.shouldRefreshRefetchedObjects = true
                
                // Update or create the User instance
                if let server = try taskContext.fetch(fetchRequest).first {
                    // Server object exists
                    return server
                }
                else {
                    // Create a Server object on the current queue context
                    let newServer = Server(context: taskContext)
                    try newServer.update(withProtocol: ServerVars.shared.serverProtocol,
                                         path: ServerVars.shared.serverPath,
                                         fileTypes: ServerVars.shared.serverFileTypes)
                    taskContext.saveIfNeeded()
                    return newServer
                }
            }
        }
        catch let error as PwgKitError { throw error }
        catch let error as NSError { throw PwgKitError.CoreDataError(innerError: error)}
        catch let error { throw PwgKitError.otherError(innerError: error) }
    }
    
    // Return a Server instance of the current server
    public func getCurrentServer(inContext taskContext: NSManagedObjectContext) throws(PwgKitError) -> Server {
        // Do {} below is used to allow typed throws
        do {
            // Synchronous execution
            return try taskContext.performAndWait { () -> Server in
                // Create a fetch request for the User entity of the current server
                let fetchRequest = fetchRequestOfServer()
                
                // Return fetched account properties
                guard let server = try taskContext.fetch(fetchRequest).first
                        else { throw PwgKitError.serverNotFound }
                return server
            }
        }
        catch let error as PwgKitError { throw error }
        catch let error as NSError { throw PwgKitError.CoreDataError(innerError: error)}
        catch let error { throw PwgKitError.otherError(innerError: error) }
    }
}
