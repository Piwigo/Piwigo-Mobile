//
//  UploadProvider.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 22/03/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import CoreData
import Photos

public class UploadProvider: NSObject {
    
    // MARK: - Singleton
    public static let shared = UploadProvider()
    
    
    // MARK: - Core Data Object Contexts
    private lazy var mainContext: NSManagedObjectContext = {
        return DataController.shared.mainContext
    }()
    
    public lazy var bckgContext: NSManagedObjectContext = {
        return DataController.shared.newTaskContext()
    }()
    
    
    // MARK: - Core Data Providers
    private lazy var userProvider: UserProvider = {
        let provider : UserProvider = UserProvider.shared
        return provider
    }()
    
    private lazy var tagProvider: TagProvider = {
        let provider : TagProvider = TagProvider.shared
        return provider
    }()
    
    
    // MARK: - Add/Update Upload Requests
    /**
     Adds or updates a batch of upload requests into the Core Data store on a private queue,
     processing the record in batches to avoid a high memory footprint.
     */
    public func importUploads(from uploadRequest: [UploadProperties],
                              completionHandler: @escaping (PwgKitError?) -> Void) {
        
        guard uploadRequest.isEmpty == false else {
            completionHandler(nil)
            return
        }
        
        // Process records in batches to avoid a high memory footprint.
        let batchSize = 256
        let count = uploadRequest.count
        
        // Determine the total number of batches.
        var numBatches = count / batchSize
        numBatches += count % batchSize > 0 ? 1 : 0
        
        for batchNumber in 0 ..< numBatches {
            
            // Determine the range for this batch.
            let batchStart = batchNumber * batchSize
            let batchEnd = batchStart + min(batchSize, count - batchNumber * batchSize)
            let range = batchStart..<batchEnd
            
            // Create a batch for this range from the decoded JSON.
            let uploadsBatch = Array(uploadRequest[range])
            
            // Stop the entire import if any batch is unsuccessful.
            if !importOneBatch(uploadsBatch) {
                return
            }
        }
        completionHandler(nil)
    }
    
    public func importUploads(from uploadRequest: [UploadProperties]) async throws -> Int {
        
        guard uploadRequest.isEmpty == false
        else { return 0 }
        
        // Process records in batches to avoid a high memory footprint.
        let batchSize = 256
        let count = uploadRequest.count
        
        // Determine the total number of batches.
        var numBatches = count / batchSize
        numBatches += count % batchSize > 0 ? 1 : 0
        
        for batchNumber in 0 ..< numBatches {
            
            // Determine the range for this batch.
            let batchStart = batchNumber * batchSize
            let batchEnd = batchStart + min(batchSize, count - batchNumber * batchSize)
            let range = batchStart..<batchEnd
            
            // Create a batch for this range from the decoded JSON.
            let uploadsBatch = Array(uploadRequest[range])
            
            // Stop the import if this batch is unsuccessful.
            if !importOneBatch(uploadsBatch) {
                return batchNumber * batchSize
            }
        }
        return count
    }
    
    /**
     Adds or updates one batch of upload requests, creating managed objects from the new data,
     and saving them to the persistent store, on a private queue. After saving,
     resets the context to clean up the cache and lower the memory footprint.
     
     NSManagedObjectContext.performAndWait doesn't rethrow so this function
     catches throws within the closure and uses a return value to indicate
     whether the import is successful.
     */
    private func importOneBatch(_ uploadsBatch: [UploadProperties]) -> Bool {
        
        var success = false
        
        // taskContext.performAndWait runs on the URLSession's delegate queue
        // so it won’t block the main thread.
        bckgContext.performAndWait {
            
            // Get current user account
            guard let user = userProvider.getUserAccount(inContext: bckgContext) else {
                return
            }
            
            // Retrieve existing uploads
            // Create a fetch request for the Upload entity sorted by localIdentifier
            let fetchRequest = Upload.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Upload.localIdentifier), ascending: true)]
            
            // Select upload requests:
            /// — for the current server and user only
            var andPredicates = [NSPredicate]()
            andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.shared.user))
            andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.shared.serverPath))
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
            
            // Create a fetched results controller and set its fetch request, context, and delegate.
            let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                        managedObjectContext: bckgContext,
                                                        sectionNameKeyPath: nil, cacheName: nil)
            
            // Perform the fetch.
            do {
                try controller.performFetch()
            } catch {
                fatalError("Unresolved error: \(error.localizedDescription)")
            }
            let cachedUploads = controller.fetchedObjects ?? []
            
            // Loop over new uploads
            for uploadData in uploadsBatch {
                // Index of this new upload in cache
                if let index = cachedUploads.firstIndex( where: { $0.localIdentifier == uploadData.localIdentifier }) {
                    // Update the update's properties using the raw data
                    do {
                        // Get tag instances
                        let tags = tagProvider.getTags(withIDs: uploadData.tagIds,
                                                       taskContext: bckgContext)
                        try cachedUploads[index].update(with: uploadData, tags: tags, forUser: user)
                    }
                    catch PwgKitError.missingUploadData {
                        // Could not perform the update
                        debugPrint(PwgKitError.missingUploadData.localizedDescription)
                    }
                    catch {
                        debugPrint(error.localizedDescription)
                    }
                } else {
                    // Create an Upload managed object on the private queue context.
                    guard let upload = NSEntityDescription.insertNewObject(forEntityName: "Upload", into: bckgContext) as? Upload else {
                        debugPrint(PwgKitError.uploadCreationError.localizedDescription)
                        return
                    }
                    
                    // Populate the Upload's properties using the data.
                    do {
                        let tags = tagProvider.getTags(withIDs: uploadData.tagIds,
                                                       taskContext: bckgContext)
                        try upload.update(with: uploadData, tags: tags, forUser: user)
                    }
                    catch PwgKitError.missingUploadData {
                        // Delete invalid Upload from the private queue context.
                        debugPrint(PwgKitError.missingUploadData.localizedDescription)
                        bckgContext.delete(upload)
                    }
                    catch {
                        debugPrint(error.localizedDescription)
                    }
                }
            }
            
            // Save all insertions and deletions from the context to the store.
            bckgContext.saveIfNeeded()
            DispatchQueue.main.async {
                self.mainContext.saveIfNeeded()
            }
            
            success = true
        }
        return success
    }
    
    
    // MARK: - Get md5sum of Upload Requests
    /**
     Called by UploadPhotosHandler
     Return the md5sum of the upload requests in cache in the main thread
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
        
        // Create a fetched results controller and set its fetch request, context, and delegate.
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                    managedObjectContext: bckgContext,
                                                    sectionNameKeyPath: nil, cacheName: nil)
        
        // Perform the fetch.
        do {
            try controller.performFetch()
        } catch {
            fatalError("Unresolved error: \(error.localizedDescription)")
        }
        let cachedUploads = controller.fetchedObjects ?? []
        return cachedUploads.map(\.md5Sum)
    }
    
    
    // MARK: - Clear Upload Requests
    /**
     Return number of upload requests stored in cache
     */
    public func getObjectCount() -> Int64 {
        
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
            let countResult = try bckgContext.fetch(fetchRequest)
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
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)
        
        // Execute batch delete request
        try? mainContext.executeAndMergeChanges(using: batchDeleteRequest)
    }
    
    /**
     Delete a batch of upload requests from the Core Data store on a background queue.
     */
    public func delete(uploadsWithID: [NSManagedObjectID],
                       completion: @escaping (PwgKitError?) -> Void) {
        // Any upload request to delete?
        guard uploadsWithID.isEmpty == false else {
            completion(nil)
            return
        }
        
        // Delete all upload requests in a batch
        do {
            // Create batch delete request
            let batchDeleteRequest = NSBatchDeleteRequest(objectIDs: uploadsWithID)
            
            // Execute batch delete request
            // Associated files will be deleted
            try bckgContext.executeAndMergeChanges(using: batchDeleteRequest)
            completion(nil)
        }
        catch let error {
            completion(PwgKitError.otherError(innerError: error))
        }
    }
    
    /**
     Attribute upload requests with API key as username to Piwigo user
     Used to fix situations where a user logins with API keys before v4.1.2 (since Piwigo 16)
     To be called on a background queue so it won’t block the main thread.
     */
    func attributeAPIKeyUploadRequests(toUserWithID userID: NSManagedObjectID) {
        // To be called on a background queue so it won’t block the main thread.
        bckgContext.performAndWait {
            
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
                let uploadIDs = try bckgContext.fetch(fetchRequest)
                
                // Retrieve Piwigo user object
                guard let piwigoUser = try? bckgContext.existingObject(with: userID) as? User
                else { return }
                
                // Attribute API key upload requests to the Piwigo user
                let batchSize = 100
                for batch in stride(from: 0, to: uploadIDs.count, by: batchSize) {
                    let endIndex = min(batch + batchSize, uploadIDs.count)
                    let batchIDs = Array(uploadIDs[batch..<endIndex])
                    
                    for objectID in batchIDs {
                        let upload = bckgContext.object(with: objectID)
                        upload.setValue(piwigoUser, forKey: "user")
                    }
                    
                    // Save modifications from the context’s parent store
                    try bckgContext.save()
                    
                    // Reset the taskContext to free the cache and lower the memory footprint.
                    bckgContext.reset()
                    
                    // Merge all modifications in the persistent store
                    DispatchQueue.main.async {
                        self.mainContext.saveIfNeeded()
                    }
                }
            } catch {
                debugPrint("Unresolved error \(error.localizedDescription)")
            }
        }
    }
}
