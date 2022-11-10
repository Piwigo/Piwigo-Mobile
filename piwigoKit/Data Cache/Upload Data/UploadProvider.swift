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
    
    
    // MARK: - Update Single Upload Request
    /**
     Updates an upload request, updating the managed object from the new data,
     and saving it to the persistent store, on a private queue. After saving,
     resets the context to clean up the cache and lower the memory footprint.
    */
    public func updatePropertiesOfUpload(with ID: NSManagedObjectID,
                                         properties: UploadProperties,
                                         completionHandler: @escaping (Error?) -> Void) -> (Void) {
        // Check current queue
//        print("••> updatePropertiesOfUpload() \(properties.fileName) | \(properties.stateLabel) in \(queueName())\r")

        // taskContext.performAndWait runs on the URLSession's delegate queue
        // so it won’t block the main thread.
        bckgContext.performAndWait {
            
            // Retrieve existing upload
            let cachedUpload = bckgContext.object(with: ID) as! Upload
            
            // Update cached upload
            do {
                let tags = tagProvider.getTags(withIDs: properties.tagIds,
                                               taskContext: bckgContext)
                try cachedUpload.update(with: properties, tags: tags)
            }
            catch UploadError.missingData {
                // Could not perform the update
                print(UploadError.missingData.localizedDescription)
            }
            catch {
                print(error.localizedDescription)
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
        }
        completionHandler(nil)
    }

    public func updateStatusOfUpload(with ID: NSManagedObjectID,
                                     to status: kPiwigoUploadState, error: String?,
                                     completionHandler: @escaping (Error?) -> Void) -> (Void) {
        // Check current queue
        print("••> updateStatusOfUpload \(ID) to \(status.stateInfo) in \(queueName())\r")

        // taskContext.performAndWait runs on the URLSession's delegate queue
        // so it won’t block the main thread.
        bckgContext.performAndWait {
            
            // Retrieve existing upload
            let cachedUpload = bckgContext.object(with: ID) as! Upload
            
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
        }
        completionHandler(nil)
    }

    /**
     Update a single upload request on the private queue when an image is deleted from the Piwigo server.
     After saving, resets the context to clean up the cache and lower the memory footprint.
    */
    public func markAsDeletedPiwigoImage(withID imageId: Int64) {
        // Check current queue
//        print("••> didDeleteImageWithId()", queueName())

        // taskContext.performAndWait
        bckgContext.performAndWait {
            
            // Retrieve existing upload (if any)
            // Create a fetch request for the image ID uploaded to the albumId
            let fetchRequest = NSFetchRequest<Upload>(entityName: "Upload")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Upload.imageId), ascending: true)]
            fetchRequest.predicate = NSPredicate(format: "imageId == %ld", imageId)

            // Select upload request:
            /// — for the current server and user only
            var andPredicates = [NSPredicate]()
            andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.serverPath))
            andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.username))
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
            
            // Update cached upload
            if let cachedUpload = controller.fetchedObjects?.first
            {
                // Mark image as deleted
                cachedUpload.requestState = kPiwigoUploadState.deleted.rawValue
                
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
            }
        }
    }


    // MARK: - Delete Upload Requests
    /**
     Delete a batch of upload requests from the Core Data store on a private or background queue,
     processing the record in batches to avoid a high memory footprint.
    */
    public func delete(uploadRequests: [NSManagedObjectID],
                       completionHandler: @escaping (Error?) -> Void) {
        
        guard uploadRequests.isEmpty == false else {
            completionHandler(nil)
            return
        }
        
        // Create the queue context.
        var taskContext: NSManagedObjectContext
        if Thread.isMainThread {
            taskContext = mainContext
        } else {
            taskContext = bckgContext
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
//        print("••> deleteOneBatch()", queueName())

        var success = false
        var uploadsToDelete = [NSManagedObjectID]()
        taskContext.performAndWait {
            // Loop over uploads to delete
            for uploadID in uploadsBatch {
                // Delete corresponding temporary files if any
                let uploadToDelete = taskContext.object(with: uploadID) as! Upload
                let filenamePrefix = uploadToDelete.localIdentifier.replacingOccurrences(of: "/", with: "-")
                if filenamePrefix.isEmpty == false {
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
//        debugPrint("••> getRequests()", queueName())

        // Initialisation
        var localIdentifiers = [String]()
        var uploadIDs = [NSManagedObjectID]()

        // Perform the fetch
        bckgContext.performAndWait {

            // Retrieve existing completed uploads
            // Create a fetch request for the Upload entity sorted by localIdentifier
            let fetchRequest = Upload.fetchRequest()
            
            // Priority to uploads requested manually, oldest ones first
            var sortDescriptors = [NSSortDescriptor(key: #keyPath(Upload.markedForAutoUpload), ascending: true)]
            sortDescriptors.append(NSSortDescriptor(key: #keyPath(Upload.requestDate), ascending: true))
            fetchRequest.sortDescriptors = sortDescriptors

            // OR subpredicates
            var orSubpredicates = [NSPredicate]()
            states.forEach { (state) in
                orSubpredicates.append(NSPredicate(format: "requestState == %d", state.rawValue))
            }
            let statesPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: orSubpredicates)
            
            // AND subpredicates
            var andPredicates:[NSPredicate] = [statesPredicate]
            andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.serverPath))
            andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.username))
            if markedForAutoUpload {
                // Only auto-upload requests are wanted
                andPredicates.append(NSPredicate(format: "markedForAutoUpload == YES"))
            }
            if markedForDeletion {
                // Only image marked for deletion are wanted
                andPredicates.append(NSPredicate(format: "deleteImageAfterUpload == YES"))
            }
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
            if markedForDeletion, bckgContext.hasChanges {
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
            }
            
            // Reset the taskContext to free the cache and lower the memory footprint.
            bckgContext.reset()
        }
        return (localIdentifiers, uploadIDs)
    }

    
    // MARK: - Clear Uploads
    /**
     Clear cached Core Data upload entry
    */
    public func clearUploads() {
        
        // Create a fetch request for the Upload entity
        let fetchRequest = Upload.fetchRequest()

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
     Remove from cache completed requests whose images do not exist in Photo Library.
    */
    public func clearCompletedUploads() {

        // Get completed upload requests
        let (localIds, uploadIds) = getRequests(inStates: [.finished, .moderated])

        // Which one should be deleted?
        var uploadsToDelete = [NSManagedObjectID]()
        bckgContext.performAndWait {
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
            try? bckgContext.executeAndMergeChanges(using: batchDeleteRequest)
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
        let fetchRequest = Upload.fetchRequest()

        // Priority to uploads requested manually, oldest ones first
        var sortDescriptors = [NSSortDescriptor(key: #keyPath(Upload.markedForAutoUpload), ascending: true)]
        sortDescriptors.append(NSSortDescriptor(key: #keyPath(Upload.requestDate), ascending: true))
        fetchRequest.sortDescriptors = sortDescriptors
        
        // Select upload requests:
        /// — whose image has not been deleted from the Piwigo server
        /// — for the current server and user only
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "requestState != %d", kPiwigoUploadState.deleted.rawValue))
        andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.username))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)

        // Create a fetched results controller and set its fetch request, context, and delegate.
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                            managedObjectContext: mainContext,
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
        andPredicates.append(NSPredicate(format: "requestState != %d", kPiwigoUploadState.finished.rawValue))
        andPredicates.append(NSPredicate(format: "requestState != %d", kPiwigoUploadState.moderated.rawValue))
        andPredicates.append(NSPredicate(format: "requestState != %d", kPiwigoUploadState.deleted.rawValue))
        andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.username))
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

