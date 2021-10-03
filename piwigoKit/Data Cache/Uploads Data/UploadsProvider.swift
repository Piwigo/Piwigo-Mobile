//
//  UploadsProvider.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 22/03/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
//  A class to fetch data from the remote server and save it to the Core Data store.

import CoreData
import Photos

public class UploadsProvider: NSObject {

    // MARK: - Core Data object context
    
    lazy var managedObjectContext: NSManagedObjectContext = {
        let context:NSManagedObjectContext = DataController.managedObjectContext
        return context
    }()

    
    // MARK: - Add/Update Upload Requests
    /**
     Adds or updates a batch of upload requests into the Core Data store on a private queue,
     processing the record in batches to avoid a high memory footprint.
    */
    public func importUploads(from uploadRequest: [UploadProperties],
                              completionHandler: @escaping (Error?) -> Void) {
        
        guard !uploadRequest.isEmpty else {
            completionHandler(nil)
            return
        }
        
        // Create a private queue context.
        let taskContext = DataController.privateManagedObjectContext
                
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
            if !importOneBatch(uploadsBatch, taskContext: taskContext) {
                return
            }
        }
        completionHandler(nil)
    }
    
    /**
     Adds or updates one batch of uploads, creating managed objects from the new data,
     and saving them to the persistent store, on a private queue. After saving,
     resets the context to clean up the cache and lower the memory footprint.
     
     NSManagedObjectContext.performAndWait doesn't rethrow so this function
     catches throws within the closure and uses a return value to indicate
     whether the import is successful.
    */
    private func importOneBatch(_ uploadsBatch: [UploadProperties],
                                taskContext: NSManagedObjectContext) -> Bool {
        
        var success = false
                
        // taskContext.performAndWait runs on the URLSession's delegate queue
        // so it won’t block the main thread.
        taskContext.performAndWait {
            
            // Retrieve existing uploads
            // Create a fetch request for the Upload entity sorted by localIdentifier
            let fetchRequest = NSFetchRequest<Upload>(entityName: "Upload")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "localIdentifier", ascending: true)]
            
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
            let cachedUploads = controller.fetchedObjects ?? []

            // Loop over new uploads
            for uploadData in uploadsBatch {
                // Index of this new upload in cache
                if let index = cachedUploads.firstIndex( where: { $0.localIdentifier == uploadData.localIdentifier }) {
                    // Update the update's properties using the raw data
                    do {
                        try cachedUploads[index].update(with: uploadData)
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
                    guard let upload = NSEntityDescription.insertNewObject(forEntityName: "Upload", into: taskContext) as? Upload else {
                        print(UploadError.creationError.localizedDescription)
                        return
                    }
                    
                    // Populate the Upload's properties using the data.
                    do {
                        try upload.update(with: uploadData)
                    }
                    catch UploadError.missingData {
                        // Delete invalid Upload from the private queue context.
                        print(UploadError.missingData.localizedDescription)
                        taskContext.delete(upload)
                    }
                    catch {
                        print(error.localizedDescription)
                    }
                }
            }
            
            // Save all insertions and deletions from the context to the store.
            if taskContext.hasChanges {
                do {
                    try taskContext.save()

                    // Performs a task in the main queue and wait until this task finishes
                    DispatchQueue.main.async {
                        self.managedObjectContext.performAndWait {
                            do {
                                // Saves the data from the child to the main context to be stored properly
                                try self.managedObjectContext.save()
                            } catch {
                                fatalError("Failure to save context: \(error)")
                            }
                        }
                    }
                }
                catch {
                    fatalError("Failure to save context: \(error)")
                }
                // Reset the taskContext to free the cache and lower the memory footprint.
                taskContext.reset()
            }
            success = true
        }
        return success
    }
    
    
    // MARK: - Update Single Upload Request
    /**
     Updates an upload request, updating managed object from the new data,
     and saving it to the persistent store, on a private queue. After saving,
     resets the context to clean up the cache and lower the memory footprint.
    */
    public func updatePropertiesOfUpload(with ID: NSManagedObjectID,
                                         properties: UploadProperties,
                                         completionHandler: @escaping (Error?) -> Void) -> (Void) {
        // Check current queue
//        print("•••>> updatePropertiesOfUpload() \(properties.fileName) | \(properties.stateLabel) in \(queueName())\r")

        // Create a private queue context.
        let taskContext = DataController.privateManagedObjectContext
                
        // taskContext.performAndWait runs on the URLSession's delegate queue
        // so it won’t block the main thread.
        taskContext.performAndWait {
            
            // Retrieve existing upload
            let cachedUpload = taskContext.object(with: ID) as! Upload
            
            // Update cached upload
            do {
                try cachedUpload.update(with: properties)
            }
            catch UploadError.missingData {
                // Could not perform the update
                print(UploadError.missingData.localizedDescription)
            }
            catch {
                print(error.localizedDescription)
            }
            
            // Save all insertions and deletions from the context to the store.
            if taskContext.hasChanges {
                do {
                    try taskContext.save()
                    
                    // Performs a task in the main queue and wait until this task finishes
                    DispatchQueue.main.async {
                        self.managedObjectContext.performAndWait {
                            do {
                                // Saves the data from the child to the main context to be stored properly
                                try self.managedObjectContext.save()
                            } catch {
                                fatalError("Failure to save context: \(error)")
                            }
                        }
                    }
                }
                catch {
                    fatalError("Failure to save context: \(error)")
                }
                // Reset the taskContext to free the cache and lower the memory footprint.
                taskContext.reset()
            }
        }
        completionHandler(nil)
    }

    public func updateStatusOfUpload(with ID: NSManagedObjectID,
                                     to status: kPiwigoUploadState, error: String?,
                                     completionHandler: @escaping (Error?) -> Void) -> (Void) {
        // Check current queue
        print("•••>> updateStatusOfUpload \(ID) to \(status.stateInfo) in \(queueName())\r")

        // Create a private queue context.
        let taskContext = DataController.privateManagedObjectContext
                
        // taskContext.performAndWait runs on the URLSession's delegate queue
        // so it won’t block the main thread.
        taskContext.performAndWait {
            
            // Retrieve existing upload
            let cachedUpload = taskContext.object(with: ID) as! Upload
            
            // Update cached upload
            do {
                try cachedUpload.updateStatus(with: status, error: error ?? "")
            }
            catch UploadError.missingData {
                // Could not perform the update
                print(UploadError.missingData.localizedDescription)
                completionHandler(UploadError.missingData)
            }
            catch {
                print(error.localizedDescription)
                completionHandler(error)
            }
            
            // Save all insertions and deletions from the context to the store.
            if taskContext.hasChanges {
                do {
                    try taskContext.save()
                    
                    // Performs a task in the main queue and wait until this task finishes
                    DispatchQueue.main.async {
                        self.managedObjectContext.performAndWait {
                            do {
                                // Saves the data from the child to the main context to be stored properly
                                try self.managedObjectContext.save()
                            } catch {
                                fatalError("Failure to save context: \(error)")
                            }
                        }
                    }
                }
                catch {
                    fatalError("Failure to save context: \(error)")
                }
                // Reset the taskContext to free the cache and lower the memory footprint.
                taskContext.reset()
            }
        }
        completionHandler(nil)
    }

    /**
     Update a single upload request on the private queue when an image is deleted from the Piwigo server.
     After saving, resets the context to clean up the cache and lower the memory footprint.
    */
    public func markAsDeletedPiwigoImage(withID imageId: Int64) {
        // Check current queue
//        print("•••>> didDeleteImageWithId()", queueName())

        // Create a private queue context.
        let taskContext = DataController.privateManagedObjectContext
                
        // taskContext.performAndWait
        taskContext.performAndWait {
            
            // Retrieve existing upload (if any)
            // Create a fetch request for the image ID uploaded to the albumId
            let fetchRequest = NSFetchRequest<Upload>(entityName: "Upload")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "imageId", ascending: true)]
            fetchRequest.predicate = NSPredicate(format: "imageId == %ld", imageId)

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
            
            // Update cached upload
            if let cachedUpload = controller.fetchedObjects?.first
            {
                // Mark image as deleted
                cachedUpload.requestState = kPiwigoUploadState.deleted.rawValue
                
                // Save all insertions and deletions from the context to the store.
                if taskContext.hasChanges {
                    do {
                        try taskContext.save()
                        
                        // Performs a task in the main queue and wait until this tasks finishes
                        DispatchQueue.main.async {
                            self.managedObjectContext.performAndWait {
                                do {
                                    // Saves the data from the child to the main context to be stored properly
                                    try self.managedObjectContext.save()
                                } catch {
                                    fatalError("Failure to save context: \(error)")
                                }
                            }
                        }
                    }
                    catch {
                        fatalError("Failure to save context: \(error)")
                    }
                    // Reset the taskContext to free the cache and lower the memory footprint.
                    taskContext.reset()
                }
            }
        }
    }


    // MARK: - Delete Upload Requests
    /**
     Delete a batch of upload requests from the Core Data store on a private queue,
     processing the record in batches to avoid a high memory footprint.
    */
    public func delete(uploadRequests: [NSManagedObjectID],
                       completionHandler: @escaping (Error?) -> Void) {
        
        guard !uploadRequests.isEmpty else { return }
        
        // Create the queue context.
        var taskContext: NSManagedObjectContext
        if Thread.isMainThread {
            taskContext = DataController.managedObjectContext
        } else {
            taskContext = DataController.privateManagedObjectContext
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
                completionHandler(UploadError.deletionError)
            }
        }
        completionHandler(nil)
    }
    
    /**
     Delete one batch of upload requests on a private queue. After saving,
     resets the context to clean up the cache and lower the memory footprint.
     
     NSManagedObjectContext.performAndWait doesn't rethrow so this function
     catches throws within the closure and uses a return value to indicate
     whether the import is successful.
    */
    private func deleteOneBatch(_ uploadsBatch: [NSManagedObjectID],
                                taskContext: NSManagedObjectContext) -> Bool {
        // Check current queue
//        print("•••>> deleteOneBatch()", queueName())

        var success = false
        var uploadsToDelete = [NSManagedObjectID]()
        taskContext.performAndWait {
            // Loop over uploads to delete
            for uploadID in uploadsBatch {
                // Delete corresponding temporary files if any
                let uploadToDelete = taskContext.object(with: uploadID) as! Upload
                let filenamePrefix = uploadToDelete.localIdentifier.replacingOccurrences(of: "/", with: "-")
                if !filenamePrefix.isEmpty {
                    // Called from main or background thread
                    UploadManager.shared.backgroundQueue.async {
                        UploadManager.shared.deleteFilesInUploadsDirectory(withPrefix: filenamePrefix)
                    }
                }

                // Append upload to delete
                uploadsToDelete.append(uploadID)
            }
            
            // Delete upload requests
            if uploadsToDelete.count > 0 {
                // Create batch delete request
                let batchDeleteRequest = NSBatchDeleteRequest(objectIDs: uploadsToDelete)

                // Execute batch delete request
                try? taskContext.executeAndMergeChanges(using: batchDeleteRequest)
            }

            success = true
        }
        return success
    }


    // MARK: - Get Uploads in Background Queue
    /**
     Fetches upload requests synchronously in the background
     */
    public func getRequests(inStates states: [kPiwigoUploadState],
                            markedForDeletion: Bool = false,
                            markedForAutoUpload: Bool = false) -> ([String], [NSManagedObjectID]) {
        // Check that states is not empty
        if states.count == 0 {
            assertionFailure("!!! getRequests() called with no args !!!")
            return ([], [NSManagedObjectID]())
        }
        
        // Check current queue
//        debugPrint("•••>> getRequests()", queueName())

        // Initialisation
        var localIdentifiers = [String]()
        var uploadIDs = [NSManagedObjectID]()

        // Create a private queue context.
        let taskContext = DataController.privateManagedObjectContext

        // Perform the fetch
        taskContext.performAndWait {

            // Retrieve existing completed uploads
            // Create a fetch request for the Upload entity sorted by localIdentifier
            let fetchRequest = NSFetchRequest<Upload>(entityName: "Upload")
            
            // Predicate
            var sortDescriptors = [NSSortDescriptor(key: "requestDate", ascending: true)]
            
            // OR subpredicates
            var orSubpredicates = [NSPredicate]()
            states.forEach { (state) in
                orSubpredicates.append(NSPredicate(format: "requestState == %d", state.rawValue))
            }
            let statesPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: orSubpredicates)
            
            // AND subpredicates
            var andSubpredicates:[NSPredicate] = [statesPredicate]
            andSubpredicates.append(NSPredicate(format: "serverPath == %@", NetworkVars.serverPath))
            if !UploadVars.isAutoUploadActive {
                // User disabled auto-upload mode
                andSubpredicates.append(NSPredicate(format: "markedForAutoUpload == NO"))
            } else if markedForAutoUpload {
                // Auto-upload mode enabled and only auto-upload requests are wanted
                andSubpredicates.append(NSPredicate(format: "markedForAutoUpload == YES"))
            } else {
                // Priority to uploads requested manually
                sortDescriptors.append(NSSortDescriptor(key: "markedForAutoUpload", ascending: true))
            }
            if markedForDeletion {
                andSubpredicates.append(NSPredicate(format: "deleteImageAfterUpload == YES"))
            }
            fetchRequest.sortDescriptors = sortDescriptors
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andSubpredicates)

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
            
            // Loop over the fetched upload requests
            if let uploads = controller.fetchedObjects {
                for upload in uploads {
                    // Did we collect upload requests marked for deletion?
                    if markedForDeletion {
                        // Reset flag if needed to prevent another deletion request
                        upload.deleteImageAfterUpload = false
                    }
                    // Gather identifiers and objectIDs
                    localIdentifiers.append(upload.localIdentifier)
                    uploadIDs.append(upload.objectID)
                }
            }

            // Save all modifications from the context to the store.
            if markedForDeletion, taskContext.hasChanges {
                do {
                    try taskContext.save()
                    
                    // Performs a task in the main queue and wait until this task finishes
                    DispatchQueue.main.async {
                        self.managedObjectContext.performAndWait {
                            do {
                                // Saves the data from the child to the main context to be stored properly
                                try self.managedObjectContext.save()
                            } catch {
                                fatalError("Failure to save context: \(error)")
                            }
                        }
                    }
                }
                catch {
                    fatalError("Failure to save context: \(error)")
                }
            }
            
            // Reset the taskContext to free the cache and lower the memory footprint.
            taskContext.reset()
        }
        return (localIdentifiers, uploadIDs)
    }

    
    // MARK: - Clear Uploads
    /**
     Clear cached Core Data upload entry
    */
    public func clearUploads() {
        
        // Create a fetch request for the Tag entity
        let fetchRequest = NSFetchRequest<Upload>(entityName: "Upload")

        // Create batch delete request
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)

        // Execute batch delete request
        try? managedObjectContext.executeAndMergeChanges(using: batchDeleteRequest)
    }
    /**
     Remove from cache completed requests whose images do not exist in Photo Library.
    */
    public func clearCompletedUploads() {

        // Get completed upload requests
        let (localIds, uploadIds) = getRequests(inStates: [.finished, .moderated])

        // Create a private queue context.
        let taskContext = DataController.privateManagedObjectContext
        
        // Which one should be deleted?
        var uploadsToDelete = [NSManagedObjectID]()
        taskContext.performAndWait {
            for index in 0..<localIds.count {
                // Check presence in Photo Library
                if let _ = PHAsset.fetchAssets(withLocalIdentifiers: [localIds[index]], options: nil).firstObject {
                    continue
                }
                // Asset not available… will delete it
                uploadsToDelete.append(uploadIds[index])
            }
        }

        if uploadsToDelete.count > 0 {
            // Create batch delete request
            let batchDeleteRequest = NSBatchDeleteRequest(objectIDs: uploadsToDelete)

            // Execute batch delete request
            try? taskContext.executeAndMergeChanges(using: batchDeleteRequest)
        }
    }


    // MARK: - NSFetchedResultsController
    /**
     A fetched results controller delegate to give consumers a chance to upload the next images.
     */
    public weak var fetchedResultsControllerDelegate: NSFetchedResultsControllerDelegate?
    
    /**
     A fetched results controller to fetch Upload records sorted by local request date in the main queue.
     */
    public lazy var fetchedResultsController: NSFetchedResultsController<Upload> = {
        
        // Create a fetch request for the Upload entity sorted by request date.
        let fetchRequest = NSFetchRequest<Upload>(entityName: "Upload")

        // Sort upload requests by date
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "requestDate", ascending: true)]
        
        // Select upload requests:
        /// — whose image has not been deleted from the Piwigo server
        /// — for the current server only
        let notDeletedPredicate = NSPredicate(format: "requestState != %d", kPiwigoUploadState.deleted.rawValue)
        let serverPredicate = NSPredicate(format: "serverPath == %@", NetworkVars.serverPath)
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [notDeletedPredicate, serverPredicate])

        // Create a fetched results controller and set its fetch request, context, and delegate.
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                            managedObjectContext: self.managedObjectContext,
                                              sectionNameKeyPath: nil,
                                                       cacheName: "allUploads")
        controller.delegate = fetchedResultsControllerDelegate
        
        // Perform the fetch.
        do {
            try controller.performFetch()
        } catch {
            fatalError("Unresolved error \(error)")
        }
        
        return controller
    }()

    /**
     A fetched results controller delegate to update the UploadQueue table view
     */
    public weak var fetchedNonCompletedResultsControllerDelegate: NSFetchedResultsControllerDelegate?
    
    /**
     A fetched results controller to fetch Upload records sorted by state in the main queue for feeding the UploadQueue table view
     */
    public lazy var fetchedNonCompletedResultsController: NSFetchedResultsController<Upload> = {
        
        // Create a fetch request for the Upload entity sorted by request date.
        let fetchRequest = NSFetchRequest<Upload>(entityName: "Upload")

        // Set the batch size to a suitable number
        fetchRequest.fetchBatchSize = 20

        // Sort upload requests by state and date
        let firstSortDescriptor = NSSortDescriptor(key: "requestSectionKey", ascending: true)
        let secondSortDescriptor = NSSortDescriptor(key: "requestDate", ascending: true)
        fetchRequest.sortDescriptors = [firstSortDescriptor, secondSortDescriptor]
        
        // Select upload requests:
        /// — which are not completed
        /// — whose image has not been deleted from the Piwigo server
        /// — for the current server only
        let notFinishedPredicate = NSPredicate(format: "requestState != %d", kPiwigoUploadState.finished.rawValue)
        let notModeratedPredicate = NSPredicate(format: "requestState != %d", kPiwigoUploadState.moderated.rawValue)
        let notDeletedPredicate = NSPredicate(format: "requestState != %d", kPiwigoUploadState.deleted.rawValue)
        let serverPredicate = NSPredicate(format: "serverPath == %@", NetworkVars.serverPath)
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [notFinishedPredicate, notModeratedPredicate, notDeletedPredicate, serverPredicate])

        // Create a fetched results controller and set its fetch request, context, and delegate.
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                            managedObjectContext: self.managedObjectContext,
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

