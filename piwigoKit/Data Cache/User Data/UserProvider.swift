//
//  UserProvider.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 28/08/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import CoreData

public enum pwgUserStatus: String, CaseIterable, Sendable {
    case guest, generic, normal, admin, webmaster
}

public final class UserProvider {
    
    public init() {}    // To make this class public

    // MARK: - Manage User Account Object
    /**
     Returns a User Account instance
     - Will create a Server object if it does not already exist.
     - Will create a User Account object if it does not already exist.
     */
    private func fetchRequestOfUser(withUsername username: String = NetworkVars.shared.user,
                                    ofServerAtPath path: String = NetworkVars.shared.serverPath) -> NSFetchRequest<User> {
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
        fetchRequest.fetchLimit = 1
        return fetchRequest
    }
    
    public func getUserAccount(of username: String = NetworkVars.shared.user,
                               ofServerAtPath path: String = NetworkVars.shared.serverPath,
                               inContext taskContext: NSManagedObjectContext,
                               afterUpdate doUpdate: Bool = false) throws(PwgKitError) -> User? {
        // Do {} below is used to allow typed throws
        do {
            // Synchronous execution
            return try taskContext.performAndWait { () -> User? in
                // Create a fetch request for the User entity
                let fetchRequest = fetchRequestOfUser(withUsername: username, ofServerAtPath: path)
                
                // Return the User entity if possible
                let user = try taskContext.fetch(fetchRequest).first
                if let user {
                    if doUpdate {
                        let now = Date.timeIntervalSinceReferenceDate
                        user.lastUsed = now
                        user.server?.lastUsed = now
                        user.status = NetworkVars.shared.userStatus.rawValue
                        taskContext.saveIfNeeded()
                    }
                    return user
                }
                
                // Get the Server managed object on the current queue context.
                let server = try ServerProvider().getServer(inContext: taskContext)
                guard let server else { throw PwgKitError.serverCreationError}
                
                // Create a User object on the current queue context
                let newUser = User(context: taskContext)
                try newUser.update(username: username, ofServer: server)
                taskContext.saveIfNeeded()
                return newUser
            }
        }
        catch let error as PwgKitError {
            throw error
        }
        catch {
            throw PwgKitError.otherError(innerError: error)
        }
    }
    
    func updateUser(withID objectID: NSManagedObjectID, status: Bool,
                    inContext taskContext: NSManagedObjectContext) {
        
        do {
            guard let user = try taskContext.existingObject(with: objectID) as? User
            else { return }
            let dateOfLogin = Date.timeIntervalSinceReferenceDate
            user.lastUsed = dateOfLogin
            if status {
                user.status = NetworkVars.shared.userStatus.rawValue
            }
            if let server = user.server {
                server.lastUsed = dateOfLogin
            }
            taskContext.saveIfNeeded()
        }
        catch {
            print("Error updating User: \(error)")
        }
    }
    
    func deleteUser(withUsername username: String = NetworkVars.shared.user,
                    ofServerAtPath path: String = NetworkVars.shared.serverPath,
                    inContext taskContext: NSManagedObjectContext) {
        
        // Create a fetch request for the User entity
        let fetchRequest = fetchRequestOfUser(withUsername: username, ofServerAtPath: path)

        // Delete the User object w/o loading it into memory
        /// - deletes associated albums in cascade
        /// - deletes associated upload requests in cascade if not already re-attributed to Piwigo user
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<any NSFetchRequestResult>)
        try? taskContext.executeAndMergeChanges(using: batchDeleteRequest)
    }
}
