//
//  UploadProvider.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 22/03/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import CoreData
import Photos

public class UploadProvider {
    
    public init() {}    // To make this class public
    
    // MARK: - Get md5sum of Upload Requests
    /**
     Called by UploadPhotosHandler
     Return the md5sum of the upload requests in cache in the background
     */
    public func getAllMd5sum() -> [String] {
        // Retrieve all existing uploads
        // Create a fetch request for the Upload entity sorted by localIdentifier
        let fetchRequest = Upload.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Upload.localIdentifier), ascending: true)]
        
        // Select upload requests:
        /// — for the current server and user only
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.shared.user))
        andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.shared.serverPath))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        
        // Perform the fetch.
        let bckgContext = DataController.shared.newTaskContext()
        do {
            let cachedUploads = try bckgContext.fetch(fetchRequest)
            return cachedUploads.map(\.md5Sum)
        }
        catch {
            debugPrint("Error fetching uploads: \(error)")
            return []
        }
    }
    
    
    // MARK: - Clear Upload Requests
    /**
     Return number of upload requests stored in cache
     */
    public func getObjectCount(inContext taskContext: NSManagedObjectContext) -> Int64 {
        
        // Create a fetch request for the Upload entity
        let fetchRequest = NSFetchRequest<NSNumber>(entityName: "Upload")
        fetchRequest.resultType = .countResultType
        
        // Select upload requests:
        /// — for the current server and user only
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.shared.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.shared.user))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        
        // Fetch number of objects
        do {
            let countResult = try taskContext.fetch(fetchRequest)
            return countResult.first!.int64Value
        }
        catch let error {
            debugPrint("••> Upload count not fetched: \(error.localizedDescription)")
        }
        return Int64.zero
    }
    
    /**
     Clear cached Core Data upload entry
     */
    public func clearAll() {
        // Create a fetch request for the Upload entity
        let fetchRequest = Upload.fetchRequest()
        
        // Priority to uploads requested manually, recent ones first
        var sortDescriptors = [NSSortDescriptor(key: #keyPath(Upload.markedForAutoUpload), ascending: true)]
        sortDescriptors.append(NSSortDescriptor(key: #keyPath(Upload.requestDate), ascending: false))
        fetchRequest.sortDescriptors = sortDescriptors
        
        // Select upload requests:
        /// — for the current server and user only
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.shared.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.shared.user))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        
        // Create batch delete request
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<any NSFetchRequestResult>)
        
        // Execute batch delete request
        let bckgContext = DataController.shared.newTaskContext()
        try? bckgContext.executeAndMergeChanges(using: batchDeleteRequest)
    }
    
    /**
     Delete a batch of upload requests from the Core Data store on a background queue.
     */
    public func deleteUploads(withID uploadIDs: [NSManagedObjectID]) throws(PwgKitError) {
        // Any upload request to delete?
        guard uploadIDs.isEmpty == false
        else { return }
        
        // Create batch delete request
        let batchDeleteRequest = NSBatchDeleteRequest(objectIDs: uploadIDs)
        
        // Execute batch delete request
        // Associated files will be deleted
        let bckgContext = DataController.shared.newTaskContext()
        try bckgContext.executeAndMergeChanges(using: batchDeleteRequest)
    }
    
    /**
     Attribute upload requests with API key as username to Piwigo user
     Used to fix situations where a user logins with API keys before v4.1.2 (since Piwigo 16)
     To be called on a background queue so it won’t block the main thread.
     */
    func attributeAPIKeyUploadRequests(toUserWithID userID: NSManagedObjectID,
                                       inContext taskContext: NSManagedObjectContext) {
        // To be called on a background queue so it won’t block the main thread.
        taskContext.performAndWait {
            
            // Retrieve IDs of upload requests in persistent store
            let fetchRequest = NSFetchRequest<NSManagedObjectID>(entityName: "Upload")
            fetchRequest.resultType = .managedObjectIDResultType
            
            // Retrieve all albums associated to the current API key:
            /// — from the current server
            var andPredicates = [NSPredicate]()
            andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.shared.serverPath))
            andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.shared.username))
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
            
            do {
                // Perform the fetch.
                let uploadIDs = try taskContext.fetch(fetchRequest)
                
                // Retrieve Piwigo user object
                guard let piwigoUser = try? taskContext.existingObject(with: userID) as? User
                else { return }
                
                // Attribute API key upload requests to the Piwigo user
                let batchSize = 100
                for batch in stride(from: 0, to: uploadIDs.count, by: batchSize) {
                    let endIndex = min(batch + batchSize, uploadIDs.count)
                    let batchIDs = Array(uploadIDs[batch..<endIndex])
                    
                    for objectID in batchIDs {
                        let upload = taskContext.object(with: objectID)
                        upload.setValue(piwigoUser, forKey: "user")
                    }
                    
                    // Save modifications from the context’s parent store
                    try taskContext.save()
                    
                    // Reset the taskContext to free the cache and lower the memory footprint.
                    taskContext.reset()

                    // Save cached data in the main thread
                    Task { @MainActor in
                        DataController.shared.mainContext.saveIfNeeded()
                    }
                }
            } catch {
                debugPrint("Unresolved error \(error.localizedDescription)")
            }
        }
    }
}
