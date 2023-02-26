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

    // MARK: - Core Data Object Contexts
    private lazy var mainContext: NSManagedObjectContext = {
        let context:NSManagedObjectContext = DataController.shared.mainContext
        return context
    }()

    private lazy var bckgContext: NSManagedObjectContext = {
        let context:NSManagedObjectContext = DataController.shared.bckgContext
        return context
    }()


    // MARK: - Core Data Providers
    private lazy var userProvider: UserProvider = {
        let provider : UserProvider = UserProvider()
        return provider
    }()

    private lazy var tagProvider: TagProvider = {
        let provider : TagProvider = TagProvider()
        return provider
    }()


    // MARK: - Add/Update Upload Requests
    /**
     Adds or updates a batch of upload requests into the Core Data store on a private queue,
     processing the record in batches to avoid a high memory footprint.
    */
    public func importUploads(from uploadRequest: [UploadProperties],
                              completionHandler: @escaping (Error?) -> Void) {
        
        guard uploadRequest.isEmpty == false else {
            completionHandler(nil)
            return
        }
        
        // Get current user account
        guard let user = userProvider.getUserAccount(inContext: bckgContext) else {
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
            if !importOneBatch(uploadsBatch, for: user) {
                return
            }
        }
        completionHandler(nil)
    }
    
    /**
     Adds or updates one batch of upload requests, creating managed objects from the new data,
     and saving them to the persistent store, on a private queue. After saving,
     resets the context to clean up the cache and lower the memory footprint.
     
     NSManagedObjectContext.performAndWait doesn't rethrow so this function
     catches throws within the closure and uses a return value to indicate
     whether the import is successful.
    */
    private func importOneBatch(_ uploadsBatch: [UploadProperties], for user: User) -> Bool {
        
        var success = false
                
        // taskContext.performAndWait runs on the URLSession's delegate queue
        // so it won’t block the main thread.
        bckgContext.performAndWait {
            
            // Retrieve existing uploads
            // Create a fetch request for the Upload entity sorted by localIdentifier
            let fetchRequest = Upload.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Upload.localIdentifier), ascending: true)]
            
            // Select upload requests:
            /// — for the current server and user only
            var andPredicates = [NSPredicate]()
            andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.username))
            andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.serverPath))
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)

            // Create a fetched results controller and set its fetch request, context, and delegate.
            let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                managedObjectContext: bckgContext,
                                                  sectionNameKeyPath: nil, cacheName: nil)
            
            // Perform the fetch.
            do {
                try controller.performFetch()
            } catch {
                fatalError("Unresolved error \(error)")
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
                    catch UploadError.missingData {
                        // Could not perform the update
                        print(UploadError.missingData.localizedDescription)
                    }
                    catch {
                        print(error.localizedDescription)
                    }
                } else {
                    // Create an Upload managed object on the private queue context.
                    guard let upload = NSEntityDescription.insertNewObject(forEntityName: "Upload", into: bckgContext) as? Upload else {
                        print(UploadError.creationError.localizedDescription)
                        return
                    }
                    
                    // Populate the Upload's properties using the data.
                    do {
                        let tags = tagProvider.getTags(withIDs: uploadData.tagIds,
                                                       taskContext: bckgContext)
                        try upload.update(with: uploadData, tags: tags, forUser: user)
                    }
                    catch UploadError.missingData {
                        // Delete invalid Upload from the private queue context.
                        print(UploadError.missingData.localizedDescription)
                        bckgContext.delete(upload)
                    }
                    catch {
                        print(error.localizedDescription)
                    }
                }
            }
            
            // Save all insertions and deletions from the context to the store.
            if bckgContext.hasChanges {
                do {
                    try bckgContext.save()
                    if Thread.isMainThread == false {
                        DispatchQueue.main.async {
                            DataController.shared.saveMainContext()
                        }
                    }
                }
                catch {
                    fatalError("Failure to save context: \(error)")
                }
                // Reset the taskContext to free the cache and lower the memory footprint.
                bckgContext.reset()
            }
            success = true
        }
        return success
    }
    
    
    // MARK: - Get Uploads in Background Queue
    /**
     Fetches upload requests synchronously in the background
     */
//    public func getRequests(inStates states: [pwgUploadState],
//                            markedForDeletion: Bool = false,
//                            markedForAutoUpload: Bool = false) -> ([String], [NSManagedObjectID]) {
//        // Check that states is not empty
//        if states.count == 0 {
//            assertionFailure("!!! getRequests() called with no args !!!")
//            return ([], [NSManagedObjectID]())
//        }
//        
//        // Check current queue
//        print("••> !!!!!!!!! getRequests()", queueName())
//
//        // Initialisation
//        var localIdentifiers = [String]()
//        var uploadIDs = [NSManagedObjectID]()
//
//        // Perform the fetch
//        bckgContext.performAndWait {
//
//            // Retrieve existing completed uploads
//            // Create a fetch request for the Upload entity sorted by localIdentifier
//            let fetchRequest = Upload.fetchRequest()
//            
//            // Priority to uploads requested manually, oldest ones first
//            var sortDescriptors = [NSSortDescriptor(key: #keyPath(Upload.markedForAutoUpload), ascending: true)]
//            sortDescriptors.append(NSSortDescriptor(key: #keyPath(Upload.requestDate), ascending: true))
//            fetchRequest.sortDescriptors = sortDescriptors
//
//            // AND subpredicates
//            var andPredicates:[NSPredicate] = [NSPredicate]()
//            andPredicates.append(NSPredicate(format: "requestState IN %@", states.map({$0.rawValue})))
//            andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.serverPath))
//            andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.username))
//            if markedForAutoUpload {
//                // Only auto-upload requests are wanted
//                andPredicates.append(NSPredicate(format: "markedForAutoUpload == YES"))
//            }
//            if markedForDeletion {
//                // Only image marked for deletion are wanted
//                andPredicates.append(NSPredicate(format: "deleteImageAfterUpload == YES"))
//            }
//            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
//
//            // Create a fetched results controller and set its fetch request, context, and delegate.
//            let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
//                                                managedObjectContext: bckgContext,
//                                                  sectionNameKeyPath: nil, cacheName: nil)
//            // Perform the fetch.
//            do {
//                try controller.performFetch()
//            } catch {
//                fatalError("Unresolved error \(error)")
//            }
//            
//            // Loop over the fetched upload requests
//            if let uploads = controller.fetchedObjects {
//                for upload in uploads {
//                    // Did we collect upload requests marked for deletion?
//                    if markedForDeletion {
//                        // Reset flag if needed to prevent another deletion request
//                        upload.deleteImageAfterUpload = false
//                    }
//                    // Gather identifiers and objectIDs
//                    localIdentifiers.append(upload.localIdentifier)
//                    uploadIDs.append(upload.objectID)
//                }
//            }
//
//            // Save all modifications from the context to the store.
//            if markedForDeletion, bckgContext.hasChanges {
//                do {
//                    try bckgContext.save()
//                    if Thread.isMainThread == false {
//                        DispatchQueue.main.async {
//                            DataController.shared.saveMainContext()
//                        }
//                    }
//                }
//                catch {
//                    fatalError("Failure to save context: \(error)")
//                }
//            }
//            
//            // Reset the taskContext to free the cache and lower the memory footprint.
//            bckgContext.reset()
//        }
//        return (localIdentifiers, uploadIDs)
//    }

    
    // MARK: - Clear Uploads
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
        andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.username))
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
                       completion: @escaping (Error?) -> Void) {
        
        guard uploadRequests.isEmpty == false else {
            completion(nil)
            return
        }
        
        // Create the queue context.
        guard let taskContext = uploadRequests.first?.managedObjectContext else {
            completion(UploadError.deletionError)
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
                completion(UploadError.deletionError)
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
        print("••> deleteOneBatch()", queueName())

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

    
    // MARK: - NSFetchedResultsController
    /**
     A fetched results controller delegate to update the UploadQueue table view
     */
    public weak var fetchedNonCompletedResultsControllerDelegate: NSFetchedResultsControllerDelegate?
    
    /**
     A fetched results controller to fetch Upload records sorted by state in the main queue for feeding the UploadQueue table view
     */
    public lazy var fetchedNonCompletedResultsController: NSFetchedResultsController<Upload> = {
        
        // Create a fetch request for the Upload entity sorted by request date.
        let fetchRequest = Upload.fetchRequest()

        // Set the batch size to a suitable number
        fetchRequest.fetchBatchSize = 20

        // Sort upload requests by state and date
        // Priority to uploads requested manually, oldest ones first
        var sortDescriptors = [NSSortDescriptor(key: #keyPath(Upload.requestSectionKey), ascending: true)]
        sortDescriptors.append(NSSortDescriptor(key: #keyPath(Upload.markedForAutoUpload), ascending: true))
        sortDescriptors.append(NSSortDescriptor(key: #keyPath(Upload.requestDate), ascending: true))
        fetchRequest.sortDescriptors = sortDescriptors
        
        // Select upload requests:
        /// — which are not completed
        /// — whose image has not been deleted from the Piwigo server
        /// — for the current server and user only
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.username))
        andPredicates.append(NSPredicate(format: "requestState != %i", pwgUploadState.finished.rawValue))
        andPredicates.append(NSPredicate(format: "requestState != %i", pwgUploadState.moderated.rawValue))
        andPredicates.append(NSPredicate(format: "requestState != %i", pwgUploadState.deleted.rawValue))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)

        // Create a fetched results controller and set its fetch request, context, and delegate.
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                            managedObjectContext: mainContext,
                                              sectionNameKeyPath: "requestSectionKey",
                                                       cacheName: "nonCompletedUploads")
        controller.delegate = fetchedNonCompletedResultsControllerDelegate
        
        // Perform the fetch.
        do {
            try controller.performFetch()
        } catch {
            fatalError("Unresolved error \(error)")
        }
        
        return controller
    }()
}

