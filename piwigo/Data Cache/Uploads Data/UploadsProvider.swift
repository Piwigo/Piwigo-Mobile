//
//  UploadsProvider.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/03/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
//  A class to fetch data from the remote server and save it to the Core Data store.

import CoreData
import Photos

@objc
class UploadsProvider: NSObject {

    override init() {
        super.init()
        
        // Register image deletion
        var name = NSNotification.Name(kPiwigoNotificationDeletedImage)
        NotificationCenter.default.addObserver(self, selector: #selector(self.didDeleteImageWithId(_:)), name: name, object: nil)
        
        // Register image moved to category
        name = NSNotification.Name(kPiwigoNotificationMovedImage)
        NotificationCenter.default.addObserver(self, selector: #selector(self.didMoveImageWithId(_:)), name: name, object: nil)

        // Register category deletion
        name = NSNotification.Name(kPiwigoNotificationDeletedCategory)
        NotificationCenter.default.addObserver(self, selector: #selector(self.didDeleteCategoryWithId(_:)), name: name, object: nil)
    }
    
    deinit {
        let name = NSNotification.Name(kPiwigoNotificationDeletedImage)
        NotificationCenter.default.removeObserver(self, name: name, object: nil)
    }

    // MARK: - Core Data object context
    
    lazy var managedObjectContext: NSManagedObjectContext = {
        let context:NSManagedObjectContext = (UIApplication.shared.delegate as! AppDelegate).managedObjectContext
        return context
    }()

    
    // MARK: - Add/Update Upload Requests
    /**
     Adds or updates a batch of upload requests into the Core Data store on a private queue,
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
     Adds or updates one batch of uploads, creating managed objects from the new data,
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

            // Get uploads to complete in queue
            // Considers only uploads to the server to which the user is logged in
            let states: [kPiwigoUploadState] = [.waiting, .preparing, .preparingError,
                                                .preparingFail, .formatError, .prepared,
                                                .uploading, .uploadingError, .uploaded,
                                                .finishing, .finishingError]
            // Update app badge and Upload button in root/default album
            UploadManager.shared.nberOfUploadsToComplete = getRequestsIn(states: states).count
        }
        return success
    }
    
    
    // MARK: - Update Single Upload Request
    /**
     Updates an upload request, updating managed object from the new data,
     and saving it to the persistent store, on a private queue. After saving,
     resets the context to clean up the cache and lower the memory footprint.
    */
    func updatePropertiesOfUpload(with ID: NSManagedObjectID,
                                  properties: UploadProperties,
                                  completionHandler: @escaping (Error?) -> Void) -> (Void) {
        // Check current queue
        print("•••>> updatePropertiesOfUpload() \(properties.fileName) | \(properties.stateLabel) in \(queueName())\r")

        // Create a private queue context.
        let taskContext = DataController.getPrivateContext()
                
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

    func updateStatusOfUpload(with ID: NSManagedObjectID,
                              to status: kPiwigoUploadState, error: String?,
                              completionHandler: @escaping (Error?) -> Void) -> (Void) {
        // Check current queue
        print("•••>> updateStatusOfUpload \(ID) to \(status.stateInfo) in \(queueName())\r")

        // Create a private queue context.
        let taskContext = DataController.getPrivateContext()
                
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
     Update a single upload request on the private queue when an image is moved. After saving,
     resets the context to clean up the cache and lower the memory footprint.
    */
    @objc private func didMoveImageWithId(_ notification: Notification) {
        // Check current queue
//        print("•••>> didMoveImageWithId()", queueName())

        // Collect image ID
        guard let imageId = notification.userInfo?["imageId"] as? Int64 else {
            return
        }

        // Collect new album ID
        guard let albumId = notification.userInfo?["albumId"] as? Int64 else {
            return
        }

        // Create a private queue context.
        let taskContext = DataController.getPrivateContext()
                
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
                // Update upload request
                cachedUpload.category = albumId
                
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
    func delete(uploadRequests: [NSManagedObjectID]) {
        
        guard !uploadRequests.isEmpty else { return }
        
        // Create a private queue context.
        let taskContext = DataController.getPrivateContext()
                
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
            
            // Create a batch for this range.
            let uploadsBatch = Array(uploadRequests[range])
            
            // Stop the entire deletion if any batch is unsuccessful.
            if !deleteOneBatch(uploadsBatch, taskContext: taskContext) {
                break
            }
        }
}
    
    /**
     Delete one batch of upload requests on a private queue. After saving,
     resets the context to clean up the cache and lower the memory footprint.
     
     NSManagedObjectContext.performAndWait doesn't rethrow so this function
     catches throws within the closure and uses a return value to indicate
     whether the import is successful.
    */
    private func deleteOneBatch(_ uploadsBatch: [NSManagedObjectID], taskContext: NSManagedObjectContext) -> Bool {
        // Check current queue
//        print("•••>> deleteOneBatch()", queueName())

        var success = false
        taskContext.performAndWait {
            
            // Loop over uploads to delete
            for uploadID in uploadsBatch {
            
                // Delete corresponding temporary files if any
                let uploadToDelete = taskContext.object(with: uploadID) as! Upload
                let filenamePrefix = uploadToDelete.localIdentifier.replacingOccurrences(of: "/", with: "-")
                if !filenamePrefix.isEmpty {
                    UploadManager.shared.deleteFilesInUploadsDirectory(with: filenamePrefix)
                }

                // Delete upload record
                taskContext.delete(uploadToDelete)
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

            // Get uploads to complete in queue
            // Considers only uploads to the server to which the user is logged in
            let states: [kPiwigoUploadState] = [.waiting, .preparing, .preparingError,
                                                .preparingFail, .formatError, .prepared,
                                                .uploading, .uploadingError, .uploaded,
                                                .finishing, .finishingError]
            // Update app badge and Upload button in root/default album
            UploadManager.shared.nberOfUploadsToComplete = getRequestsIn(states: states).count
        }
        return success
    }

    /**
     Delete the upload request of a deleted image on the private queue. After saving,
     resets the context to clean up the cache and lower the memory footprint.
    */
    @objc private func didDeleteImageWithId(_ notification: Notification) {
        // Always perform this task in background
        DispatchQueue.global(qos: .userInitiated).async {
            // Check current queue
//            print("•••>> didDeleteImageWithId()", queueName())

            // Collect album ID
            guard let albumId = notification.userInfo?["albumId"] as? Int64 else {
                return
            }

            // Collect image ID
            guard let imageId = notification.userInfo?["imageId"] as? Int64 else {
                return
            }

            // Create a private queue context.
            let taskContext = DataController.getPrivateContext()
                    
            // taskContext.performAndWait
            taskContext.performAndWait {
                
                // Retrieve existing upload (if any)
                // Create a fetch request for the image ID uploaded to the albumId
                let fetchRequest = NSFetchRequest<Upload>(entityName: "Upload")
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: "imageId", ascending: true)]
                var predicates = [NSPredicate]()
                predicates.append(NSPredicate(format: "imageId == %ld", imageId))
                predicates.append(NSPredicate(format: "category == %ld", albumId))
                fetchRequest.predicate = NSCompoundPredicate.init(andPredicateWithSubpredicates: predicates)

                // Create a fetched results controller and set its fetch request, context, and delegate.
                let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                    managedObjectContext: taskContext,
                                                      sectionNameKeyPath: nil, cacheName: nil)
                
                // Perform the fetch.
                do {
                    // Fetch request of image with Piwigo ID
                    try controller.performFetch()
                } catch {
                    fatalError("Unresolved error \(error)")
                }

                // Update cached upload
                if let cachedUpload = controller.fetchedObjects?.first
                {
                    // Delete upload request
                    self.delete(uploadRequests: [cachedUpload.objectID])
                }

                // Reset the taskContext to free the cache and lower the memory footprint.
                taskContext.reset()
            }
        }
    }

    /**
     Delete the upload requests of a deleted image on the private queue. After saving,
     resets the context to clean up the cache and lower the memory footprint.
    */
    @objc private func didDeleteCategoryWithId(_ notification: Notification) {
        // Always perform this task in background
        DispatchQueue.global(qos: .userInitiated).async {
            // Check current queue
//            print("•••>> didDeleteCategoryWithId()", queueName())

            // Collect album ID
            guard let albumId = notification.userInfo?["albumId"] as? Int64 else {
                return
            }

            // Create a private queue context.
            let taskContext = DataController.getPrivateContext()
                    
            // taskContext.performAndWait
            taskContext.performAndWait {
                
                // Retrieve existing upload (if any)
                // Create a fetch request for the image ID uploaded to the albumId
                let fetchRequest = NSFetchRequest<Upload>(entityName: "Upload")
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: "imageId", ascending: true)]
                fetchRequest.predicate = NSPredicate(format: "category == %ld", albumId)

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
                if let cachedUploads = controller.fetchedObjects
                {
                    // Delete upload requests
                    self.delete(uploadRequests: cachedUploads.map({$0.objectID}))
                }

                // Reset the taskContext to free the cache and lower the memory footprint.
                taskContext.reset()
            }
        }
    }


    // MARK: - Get Uploads in Background Queue
    /**
     Fetches upload requests synchronously in the background
     */
    func getRequestsIn(states: [kPiwigoUploadState]) -> [NSManagedObjectID] {
        // Check that states is not empty
        if states.count == 0 {
            assertionFailure("!!! getRequestsIn() called with no args !!!")
            return [NSManagedObjectID]()
        }
        
        // Check current queue
//        print("•••>> getRequestsIn(states:)", queueName())

        // Initialisation
        var uploadIDs = [NSManagedObjectID]()
        
        // Create a private queue context.
        let taskContext = DataController.getPrivateContext()

        // Perform the fetch
        taskContext.performAndWait {

            // Retrieve existing completed uploads
            // Create a fetch request for the Upload entity sorted by localIdentifier
            let fetchRequest = NSFetchRequest<Upload>(entityName: "Upload")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "requestDate", ascending: true)]
            
            // Predicate
            var predicates = [NSPredicate]()
            states.forEach { (state) in
                predicates.append(NSPredicate(format: "requestState == %d", state.rawValue))
            }
            let statesPredicate = NSCompoundPredicate.init(orPredicateWithSubpredicates: predicates)
            let serverPredicate = NSPredicate(format: "serverPath == %@", Model.sharedInstance().serverPath)
            fetchRequest.predicate = NSCompoundPredicate.init(andPredicateWithSubpredicates: [statesPredicate, serverPredicate])

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
            uploadIDs = ((controller.fetchedObjects ?? [Upload]()) as [Upload]).map({$0.objectID})
            
            // Reset the taskContext to free the cache and lower the memory footprint.
            taskContext.reset()
        }
        return uploadIDs
    }

    func getCompletedRequestsToBeDeleted() -> ([String], [NSManagedObjectID]) {
        // Check current queue
        print("•••>> getCompletedRequestsToBeDeleted()", queueName())

        // Initialisation
        var localIdentifiers = [String]()
        var uploadIDs = [NSManagedObjectID]()
        
        // Create a private queue context.
        let taskContext = DataController.getPrivateContext()

        // Perform the fetch
        taskContext.performAndWait {

            // Retrieve existing completed uploads
            // Create a fetch request for the Upload entity sorted by localIdentifier
            let fetchRequest = NSFetchRequest<Upload>(entityName: "Upload")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "requestDate", ascending: true)]
            
            // Predicate
            var predicates = [NSPredicate]()
            predicates.append(NSPredicate(format: "requestState == %d", kPiwigoUploadState.finished.rawValue))
            predicates.append(NSPredicate(format: "requestState == %d", kPiwigoUploadState.moderated.rawValue))
            let statesPredicate = NSCompoundPredicate.init(orPredicateWithSubpredicates: predicates)
            let deletePredicate = NSPredicate(format: "deleteImageAfterUpload == YES")
            let serverPredicate = NSPredicate(format: "serverPath == %@", Model.sharedInstance().serverPath)
            fetchRequest.predicate = NSCompoundPredicate.init(andPredicateWithSubpredicates: [statesPredicate, deletePredicate, serverPredicate])

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
            
            // Reset flag of upload requests to prevent another demand for deleting images
            if let uploads = controller.fetchedObjects {
                for upload in uploads {
                    // Reset flag
                    upload.deleteImageAfterUpload = false
                    // Collect data to return
                    localIdentifiers.append(upload.localIdentifier)
                    uploadIDs.append(upload.objectID)
                }
            }

            // Save all modifications from the context to the store.
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
    func clearUploads() {
        
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
    func clearCompletedUploads() {

        // Get completed upload requests
        let completedUploads = getRequestsIn(states: [.finished, .moderated])

        // Create a private queue context.
        let taskContext = DataController.getPrivateContext()
        
        // Which one should be deleted?
        var uploadsToDelete = [NSManagedObjectID]()
        taskContext.performAndWait {
            for uploadID in completedUploads {
                // Get record
                let upload = taskContext.object(with: uploadID) as! Upload
                // Check presence in Photo Library
                if let _ = PHAsset.fetchAssets(withLocalIdentifiers: [upload.localIdentifier], options: nil).firstObject {
                    continue
                }
                // Asset not available… will delete it
                uploadsToDelete.append(uploadID)
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
    @objc weak var fetchedResultsControllerDelegate: NSFetchedResultsControllerDelegate?
    
    /**
     A fetched results controller to fetch Upload records sorted by local request date in the main queue.
     */
    @objc lazy var fetchedResultsController: NSFetchedResultsController<Upload> = {
        
        // Create a fetch request for the Upload entity sorted by request date.
        let fetchRequest = NSFetchRequest<Upload>(entityName: "Upload")

        // Sort upload requests by date
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "requestDate", ascending: true)]
        
        // Consider upload requests for the current server only
        fetchRequest.predicate = NSPredicate(format: "serverPath == %@", Model.sharedInstance().serverPath)

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
        let firstSortDescriptor = NSSortDescriptor(key: "requestSectionKey", ascending: true)
        let secondSortDescriptor = NSSortDescriptor(key: "requestDate", ascending: true)
        fetchRequest.sortDescriptors = [firstSortDescriptor, secondSortDescriptor]
        
        // Do not consider completed upload requests for the current server
        let notFinishedPredicate = NSPredicate(format: "requestState != %d", kPiwigoUploadState.finished.rawValue)
        let notModeratedPredicate = NSPredicate(format: "requestState != %d", kPiwigoUploadState.moderated.rawValue)
        let serverPredicate = NSPredicate(format: "serverPath == %@", Model.sharedInstance().serverPath)
        fetchRequest.predicate = NSCompoundPredicate.init(andPredicateWithSubpredicates: [notFinishedPredicate, notModeratedPredicate, serverPredicate])

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
