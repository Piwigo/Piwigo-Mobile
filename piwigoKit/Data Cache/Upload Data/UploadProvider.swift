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
     Delete a batch of upload requests from the Core Data store on a queue,
     processing the record in batches to avoid a high memory footprint.
    */
    public func delete(uploadRequests: [Upload],
                       completion: @escaping (PwgKitError?) -> Void) {
        
        guard uploadRequests.isEmpty == false else {
            completion(nil)
            return
        }
        
        // Create the queue context.
        guard let taskContext = uploadRequests.first?.managedObjectContext else {
            completion(PwgKitError.uploadDeletionError)
            return
        }
        
        // Process records in batches to avoid a high memory footprint.
        let batchSize = 256
        let count = uploadRequests.count
        
        // Determine the total number of batches.
        var numBatches = count / batchSize
        numBatches += count % batchSize > 0 ? 1 : 0
        
        // Loop over the batches
        for batchNumber in 0 ..< numBatches {
            
            // Determine the range for this batch.
            let batchStart = batchNumber * batchSize
            let batchEnd = batchStart + min(batchSize, count - batchNumber * batchSize)
            let range = batchStart..<batchEnd
            
            // Create a batch for this range.
            let uploadsBatch = Array(uploadRequests[range])
            
            // Stop the entire deletion if any batch is unsuccessful.
            if !deleteOneBatch(uploadsBatch, taskContext: taskContext) {
                completion(PwgKitError.uploadDeletionError)
            }
        }
        completion(nil)
    }
    
    /**
     Delete one batch of upload requests on a queue. After saving,
     resets the context to clean up the cache and lower the memory footprint.
     
     NSManagedObjectContext.performAndWait doesn't rethrow so this function
     catches throws within the closure and uses a return value to indicate
     whether the import is successful.
    */
    private func deleteOneBatch(_ uploadBatch: [Upload],
                                taskContext: NSManagedObjectContext) -> Bool {
        // Check imput and current queue
        if uploadBatch.isEmpty { return true }

        var success = false
        taskContext.performAndWait {
            // Create batch delete request
            let batchDeleteRequest = NSBatchDeleteRequest(objectIDs: uploadBatch.map({$0.objectID}))

            // Execute batch delete request
            // Associated files will be deleted
            try? taskContext.executeAndMergeChanges(using: batchDeleteRequest)

            success = true
        }
        return success
    }
}
