//
//  UploadsProvider.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/03/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
//  A class to fetch data from the remote server and save it to the Core Data store.

import CoreData

@objc
class UploadsProvider: NSObject {

    // MARK: - Core Data object context
    
    lazy var managedObjectContext: NSManagedObjectContext = {
        let context:NSManagedObjectContext = (UIApplication.shared.delegate as! AppDelegate).managedObjectContext
        return context
    }()

    
    // MARK: - Add Uploads
    /**
     Imports a batch of upload requests into the Core Data store on a private queue,
     processing the record in batches to avoid a high memory footprint.
    */
    func importUploads(from uploadRequest: [UploadProperties], completionHandler: @escaping (Error?) -> Void) {
        
        guard !uploadRequest.isEmpty else { return }
        
        // Create a private queue context.
        let taskContext = DataController.getPrivateContext()
                
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
     Adds one batch of uploads, creating managed objects from the new data,
     and saving them to the persistent store, on a private queue. After saving,
     resets the context to clean up the cache and lower the memory footprint.
     
     NSManagedObjectContext.performAndWait doesn't rethrow so this function
     catches throws within the closure and uses a return value to indicate
     whether the import is successful.
    */
    private func importOneBatch(_ uploadsBatch: [UploadProperties], taskContext: NSManagedObjectContext) -> Bool {
        
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
                let index = cachedUploads.firstIndex { (item) -> Bool in
                    item.localIdentifier == uploadData.localIdentifier
                }
                
                // Is this upload already cached?
                if index == nil {
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
                else {
                    // Update the update's properties using the raw data
                    do {
                        try cachedUploads[index!].update(with: uploadData)
                    }
                    catch UploadError.missingData {
                        // Could not perform the update
                        print(UploadError.missingData.localizedDescription)
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

            success = true
        }
        return success
    }
    
    
    // MARK: - Update Uploads
    /**
     Updates an upload, updating managed object from the new data,
     and saving it to the persistent store, on a private queue. After saving,
     resets the context to clean up the cache and lower the memory footprint.
    */
    func updateRecord(with uploadData: UploadProperties, completionHandler: @escaping (Error?) -> Void) -> (Void) {
        
        // Create a private queue context.
        let taskContext = DataController.getPrivateContext()
                
        // taskContext.performAndWait runs on the URLSession's delegate queue
        // so it won’t block the main thread.
        taskContext.performAndWait {
            
            // Retrieve existing upload
            // Create a fetch request for the Upload entity sorted by localIdentifier
            let fetchRequest = NSFetchRequest<Upload>(entityName: "Upload")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "localIdentifier", ascending: true)]
            fetchRequest.predicate = NSPredicate(format: "localIdentifier == %@", uploadData.localIdentifier)
            
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
            if let cachedUpload = controller.fetchedObjects?.first {
                do {
                    try cachedUpload.update(with: uploadData)
                }
                catch UploadError.missingData {
                    // Could not perform the update
                    print(UploadError.missingData.localizedDescription)
                }
                catch {
                    print(error.localizedDescription)
                }
            }
            
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
        completionHandler(nil)
    }

    
    // MARK: - Delete Uploads
    /**
     Delete a batch of upload requests from the Core Data store on the main queue,
     processing the record in batches to avoid a high memory footprint.
    */
    func delete(uploadRequests: [Upload]) {
        
        guard !uploadRequests.isEmpty else { return }
        
        // Process records in batches to avoid a high memory footprint.
        let batchSize = 256
        let count = uploadRequests.count
        
        // Determine the total number of batches.
        var numBatches = count / batchSize
        numBatches += count % batchSize > 0 ? 1 : 0
        
        for batchNumber in 0 ..< numBatches {
            
            // Determine the range for this batch.
            let batchStart = batchNumber * batchSize
            let batchEnd = batchStart + min(batchSize, count - batchNumber * batchSize)
            let range = batchStart..<batchEnd
            
            // Create a batch for this range from the decoded JSON.
            let uploadsBatch = Array(uploadRequests[range])
            
            // Stop the entire import if any batch is unsuccessful.
            if !deleteOneBatch(uploadsBatch) {
                return
            }
        }
    }
    
    /**
     Delete one batch of uploads on the main queue. After saving,
     resets the context to clean up the cache and lower the memory footprint.
     
     NSManagedObjectContext.performAndWait doesn't rethrow so this function
     catches throws within the closure and uses a return value to indicate
     whether the import is successful.
    */
    private func deleteOneBatch(_ uploadsBatch: [Upload]) -> Bool {
        
        var success = false
                
        // taskContext.performAndWait
        managedObjectContext.performAndWait {
            
            // Loop over uploads to delete
            for upload in uploadsBatch {
            
                // Delete corresponding temporary files if any
                let filenamePrefix = upload.localIdentifier.replacingOccurrences(of: "/", with: "-")
                UploadManager.shared.deleteFilesInUploadsDirectory(with: filenamePrefix)

                // Retrieve object in main context
                let uploadToDelete = managedObjectContext.object(with: upload.objectID)

                // Delete upload record
                managedObjectContext.delete(uploadToDelete)
            }
            
            // Save all insertions and deletions from the context to the store.
            if managedObjectContext.hasChanges {
                do {
                    try managedObjectContext.save()
                }
                catch {
                    fatalError("Failure to save context: \(error)")
                }
            }

            success = true
        }
        return success
    }


    // MARK: - Get Uploads in Background Queue
    /**
     Fetches upload requests synchronously in the background
     */
    func requestsToComplete() -> [Upload]? {
        
        // Initialisation
        var uploads: [Upload]? = nil
        
        // Create a private queue context.
        let taskContext = DataController.getPrivateContext()

        // Perform the fetch
        taskContext.performAndWait {

            // Retrieve existing completed uploads
            // Create a fetch request for the Upload entity sorted by localIdentifier
            let fetchRequest = NSFetchRequest<Upload>(entityName: "Upload")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "requestDate", ascending: true)]
            fetchRequest.predicate = NSPredicate(format: "requestState != %d && requestState != %d  && requestState != %d", kPiwigoUploadState.finished.rawValue, kPiwigoUploadState.preparingFail.rawValue, kPiwigoUploadState.formatError.rawValue)

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
            uploads = controller.fetchedObjects
        }
        return uploads
    }

    func requestsToResume() -> [Upload]? {
        
        // Initialisation
        var uploads: [Upload]? = nil
        
        // Create a private queue context.
        let taskContext = DataController.getPrivateContext()

        // Perform the fetch
        taskContext.performAndWait {

            // Retrieve existing completed uploads
            // Create a fetch request for the Upload entity sorted by localIdentifier
            let fetchRequest = NSFetchRequest<Upload>(entityName: "Upload")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "requestDate", ascending: true)]
            fetchRequest.predicate = NSPredicate(format: "requestState == %d || requestState == %d  || requestState == %d", kPiwigoUploadState.preparingError.rawValue, kPiwigoUploadState.uploadingError.rawValue, kPiwigoUploadState.finishingError.rawValue)

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
            uploads = controller.fetchedObjects
        }
        return uploads
    }

    func requestsCompleted() -> [Upload]? {
        
        // Initialisation
        var uploads: [Upload]? = nil
        
        // Create a private queue context.
        let taskContext = DataController.getPrivateContext()

        // Perform the fetch
        taskContext.performAndWait {

            // Retrieve existing completed uploads
            // Create a fetch request for the Upload entity sorted by localIdentifier
            let fetchRequest = NSFetchRequest<Upload>(entityName: "Upload")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "requestDate", ascending: true)]
            fetchRequest.predicate = NSPredicate(format: "requestState == %d", kPiwigoUploadState.finished.rawValue)

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
            uploads = controller.fetchedObjects
        }
        return uploads
    }

    
    // MARK: - Clear Uploads
    /**
     Clear cached Core Data upload entry
    */
    func clearUploads() {
        
        // Create a fetch request for the Tag entity
        let fetchRequest = NSFetchRequest<Upload>(entityName: "Upload")

        // Create batch delete request
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)

        // Execute batch delete request
        do {
            try managedObjectContext.execute(batchDeleteRequest)
        }
        catch {
            fatalError("Unresolved error \(error)")
        }
    }
    

    // MARK: - NSFetchedResultsController
    /**
     A fetched results controller delegate to give consumers a chance to upload the next images.
     */
    @objc weak var fetchedResultsControllerDelegate: NSFetchedResultsControllerDelegate?
    
    /**
     A fetched results controller to fetch Upload records sorted by local request date in the main queue.
     */
    @objc lazy var fetchedResultsController: NSFetchedResultsController<Upload> = {
        
        // Create a fetch request for the Upload entity sorted by request date.
        let fetchRequest = NSFetchRequest<Upload>(entityName: "Upload")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "requestDate", ascending: true)]
        
        // Create a fetched results controller and set its fetch request, context, and delegate.
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                            managedObjectContext: self.managedObjectContext,
                                              sectionNameKeyPath: nil, cacheName: nil)
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
    @objc weak var fetchedNonCompletedResultsControllerDelegate: NSFetchedResultsControllerDelegate?
    
    /**
     A fetched results controller to fetch Upload records sorted by state in the main queue for feeding the UploadQueue table view
     */
    @objc lazy var fetchedNonCompletedResultsController: NSFetchedResultsController<Upload> = {
        
        // Create a fetch request for the Upload entity sorted by request date.
        let fetchRequest = NSFetchRequest<Upload>(entityName: "Upload")

        // Set the batch size to a suitable number
        fetchRequest.fetchBatchSize = 20

        // Sort upload requests by state and date
        let firstSortDescriptor = NSSortDescriptor(key: "requestState", ascending: false)
        let secondSortDescriptor = NSSortDescriptor(key: "requestDate", ascending: true)
        fetchRequest.sortDescriptors = [firstSortDescriptor, secondSortDescriptor]
        
        // Do not consider completed upload requests
        fetchRequest.predicate = NSPredicate(format: "requestState != %d", kPiwigoUploadState.finished.rawValue)

        // Create a fetched results controller and set its fetch request, context, and delegate.
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                            managedObjectContext: self.managedObjectContext,
                                              sectionNameKeyPath: "stateSection", cacheName: nil)
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
