//
//  UserProvider.swift
//  PwgKit
//
//  Created by Eddy Lelièvre-Berna on 28/08/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import CoreData
import PwgKit

public final class UserProvider {
    
    public init() {}    // To make this class public
    
    // MARK: - Fetch Request
    /// A user account is defined with:
    /// - a server path (without the scheme)
    /// - a username (≠ login name)
    fileprivate func fetchRequestOfUser(withUsername username: String = ServerVars.shared.username,
                                        ofServerAtPath path: String = ServerVars.shared.serverPath) -> NSFetchRequest<User> {
        // Create a fetch request sorted by username
        let fetchRequest = User.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(User.username), ascending: true,
                                                         selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
        
        // Select user:
        /// — from the current server which is accessible to the current user
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "server.path == %@", path))
        andPredicates.append(NSPredicate(format: "username == %@", username))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.shouldRefreshRefetchedObjects = true
        fetchRequest.fetchLimit = 1
        return fetchRequest
    }
    
    
    // MARK: - Create/Get Current User Object
    // Create or update a user account in cache at login
    /// - Will create a Server object in cache if needed
    public func createOrUpdateAccount(withProperties userData: UserProperties,
                                      inContext taskContext: NSManagedObjectContext) throws(PwgKitError) -> Void {
        // Do {} below is used to allow typed throws
        do {
            // Synchronous execution
            try taskContext.performAndWait {
                // Get the Server managed object on the current queue context.
                let server = try ServerProvider().getOrCreateCurrentServer(inContext: taskContext)
                
                // Create a fetch request for the User entity of the current server
                let fetchRequest = fetchRequestOfUser(withUsername: userData.username)
                
                // Update or create the User instance
                if let user = try taskContext.fetch(fetchRequest).first {
                    // Account exists, update it
                    try user.update(with: userData, onServer: server)
                }
                else {
                    // Create a User object on the current queue context
                    let newUser = User(context: taskContext)
                    do {
                        try newUser.update(with: userData, onServer: server)
                    }
                    catch {
                        taskContext.delete(newUser)
                        throw error
                    }
                }

                // The account must be persisted, otherwise it would remain invisible
                // to the background contexts and the user could not be retrieved from cache
                try taskContext.saveIfNeededOrThrow()
            }
        }
        catch let error as PwgKitError { throw error }
        catch let error as NSError { throw PwgKitError.CoreDataError(innerError: error)}
        catch let error { throw PwgKitError.otherError(innerError: error) }
    }
    
    // Return a User instance of the current user
    public func getCurrentUser(inContext taskContext: NSManagedObjectContext) throws(PwgKitError) -> User {
        // Do {} below is used to allow typed throws
        do {
            // Synchronous execution
            return try taskContext.performAndWait { () -> User in
                // Create a fetch request for the User entity of the current server
                let fetchRequest = fetchRequestOfUser()
                
                // Return fetched account properties
                guard let user = try taskContext.fetch(fetchRequest).first
                else { throw PwgKitError.userNotFound }
                return user
            }
        }
        catch let error as PwgKitError { throw error }
        catch let error as NSError { throw PwgKitError.CoreDataError(innerError: error)}
        catch let error { throw PwgKitError.otherError(innerError: error) }
    }
    
    public func getPropertiesOfCurrentUser(inContext taskContext: NSManagedObjectContext) throws(PwgKitError) -> UserProperties {
        return try getCurrentUser(inContext: taskContext).getProperties()
    }
    
    
    // MARK: - Get Other User Objects
    public func getUser(withURIstr userURIstr: String,
                        inContext taskContext: NSManagedObjectContext) throws(PwgKitError) -> User {
        // Do {} below is used to allow typed throws
        do {
            // Synchronous execution
            return try taskContext.performAndWait { () -> User in
                // Retrieve User instance
                guard let userURI = URL(string: userURIstr),
                      let userID = taskContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: userURI),
                      let user = try taskContext.existingObject(with: userID) as? User
                else { throw PwgKitError.userNotFound }
                
                // Extract properties
                return user
            }
        }
        catch let error as PwgKitError { throw error }
        catch let error as NSError { throw PwgKitError.CoreDataError(innerError: error)}
        catch let error { throw PwgKitError.otherError(innerError: error) }
    }
    
    public func getPropertiesOfUser(withURIstr userURIstr: String,
                                    inContext taskContext: NSManagedObjectContext) throws(PwgKitError) -> UserProperties {
        return try getUser(withURIstr: userURIstr, inContext: taskContext).getProperties()
    }
    
    
    // MARK: - Update User Object
    public func updateUser(withProperties properties: UserProperties,
                           inContext taskContext: NSManagedObjectContext) throws(PwgKitError) {
        // Do {} below is used to allow typed throws
        do {
            // Synchronous execution
            return try taskContext.performAndWait {
                // Retrieve User instance
                guard let userURI = URL(string: properties.URIstr),
                      let userID = taskContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: userURI),
                      let user = try taskContext.existingObject(with: userID) as? User
                else { throw PwgKitError.userNotFound }
                
                // Get the Server managed object on the current queue context.
                let server = try ServerProvider().getCurrentServer(inContext: taskContext)
                
                // Update properties
                try user.update(with: properties, onServer: server)
                taskContext.saveIfNeeded()
            }
        }
        catch let error as PwgKitError { throw error }
        catch let error as NSError { throw PwgKitError.CoreDataError(innerError: error)}
        catch let error { throw PwgKitError.otherError(innerError: error) }
    }
    
    
    // MARK: - Delete User Object
    public func deleteUser(withUsername username: String = ServerVars.shared.username,
                           ofServerAtPath path: String = ServerVars.shared.serverPath,
                           inContext taskContext: NSManagedObjectContext) {
        
        // Create a fetch request for the User entity
        let fetchRequest = fetchRequestOfUser(withUsername: username, ofServerAtPath: path)
        
        // Delete the User object w/o loading it into memory
        /// - deletes associated albums in cascade
        /// - deletes associated upload requests in cascade if not already re-attributed to Piwigo user
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<any NSFetchRequestResult>)
        try? taskContext.executeAndMergeChanges(using: batchDeleteRequest)
    }
    
    //    public func getCredentialsOfUser(withID objectURIstr: String,
    //                                     inContext taskContext: NSManagedObjectContext) throws -> (String, String) {
    //        try taskContext.performAndWait { () throws -> (String, String) in
    //            // Get username
    //            guard let objectURI = URL(string: objectURIstr),
    //                  let userID = taskContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: objectURI),
    //                  let user = try? taskContext.existingObject(with: userID) as? User,
    //                  user.username.isEmpty == false
    //            else { throw PwgKitError.invalidCredentials }
    //            let username = user.username
    //
    //            // Get server path
    //            guard let server = user.server,
    //                  server.path.isEmpty == false
    //            else { throw PwgKitError.invalidCredentials }
    //            let serverPath = server.path
    //
    //            return (username, serverPath)
    //        }
    //    }
}
