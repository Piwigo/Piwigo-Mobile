//
//  UploadProvider.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 22/03/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import CoreData
import Photos

public final class UploadProvider {
    
    public init() {}    // To make this class public
    
    // MARK: - Sort Descriptors & Predicates
    private lazy var sortDescriptors: [NSSortDescriptor] = {
        // Priority to uploads requested manually, oldest ones first
        var sortDescriptors = [NSSortDescriptor(key: #keyPath(Upload.markedForAutoUpload), ascending: true)]
        sortDescriptors.append(NSSortDescriptor(key: #keyPath(Upload.requestDate), ascending: true))
        return sortDescriptors
    }()
    
    private lazy var accountPredicates: [NSPredicate] = {
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "user.server.path == $serverPath"))
        andPredicates.append(NSPredicate(format: "user.username == $userName"))
        return andPredicates
    }()
        
    private lazy var pendingPredicate: NSPredicate = {
        // Retrieves only non-completed upload requests
        var andPredicates = accountPredicates
        let unwantedStates: [pwgUploadState] = [.finished, .moderated]
        andPredicates.append(NSPredicate(format: "NOT (requestState IN %@)", unwantedStates.map({$0.rawValue})))
        return NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
    }()
    
    lazy var completedPredicate: NSPredicate = {
        var andPredicates = accountPredicates
        let states: [pwgUploadState] = [.finished, .moderated]
        andPredicates.append(NSPredicate(format: "requestState IN %@", states.map({$0.rawValue})))
        return NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
    }()

    
    // MARK: - Add/Update Upload Requests
    /**
     Adds or updates a batch of upload requests into the Core Data store on the uploadKit private queue,
     processing the record in batches to avoid a high memory footprint.
     */
    public func importUploads(from uploadRequest: [UploadProperties],
                              inContext taskContext: NSManagedObjectContext) async throws -> [NSManagedObjectID] {
        // Return immediately if empty
        guard uploadRequest.isEmpty == false
        else { return [] }
        
        // Process records in batches to avoid a high memory footprint.
        let batchSize = 256
        let count = uploadRequest.count
        
        // Determine the total number of batches.
        var numBatches = count / batchSize
        numBatches += count % batchSize > 0 ? 1 : 0
        
        // Loop over the batches
        var uploadIDs: [NSManagedObjectID] = []
        for batchNumber in 0 ..< numBatches {
            
            // Determine the range for this batch.
            let batchStart = batchNumber * batchSize
            let batchEnd = batchStart + min(batchSize, count - batchNumber * batchSize)
            let range = batchStart..<batchEnd
            
            // Create a batch for this range from the decoded JSON.
            let uploadsBatch = Array(uploadRequest[range])
            
            // Stop the import if this batch is unsuccessful.
            let uploadIDsInBatch = try await importOneBatch(uploadsBatch, inContext: taskContext)
            uploadIDs.append(contentsOf: uploadIDsInBatch)
        }
        return uploadIDs
    }
    
    /**
     Adds or updates one batch of upload requests, creating managed objects from the new data,
     and saving them to the persistent store, on the uploadKit private queue. After saving,
     resets the context to clean up the cache and lower the memory footprint.
     */
    private func importOneBatch(_ uploadsBatch: [UploadProperties],
                                inContext taskContext: NSManagedObjectContext) async throws -> [NSManagedObjectID]
    {
        // Do {} below is used to allow typed throws
        do {
            // Synchronous execution in the uploadKit background thread
            return try taskContext.performAndWait { () -> [NSManagedObjectID] in
                // Runs on the URLSession's delegate queue so it won’t block the main thread.
                // Main context automatically sees changes via merge
                var uploadIDs: [NSManagedObjectID] = []
                
                // Get current user account
                guard let user = try UserProvider().getUserAccount(inContext: taskContext)
                else { throw PwgKitError.userCreationError }
                if user.isFault {
                    // user is not fired yet.
                    user.willAccessValue(forKey: nil)
                    user.didAccessValue(forKey: nil)
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
                
                // Loop over new uploads
                let cachedUploads = try taskContext.fetch(fetchRequest)
                for uploadData in uploadsBatch {
                    // Index of this new upload in cache
                    if let index = cachedUploads.firstIndex( where: { $0.localIdentifier == uploadData.localIdentifier }) {
                        // Get tag instances
                        let tags = try TagProvider().getTags(withIDs: uploadData.tagIds, taskContext: taskContext)
                        
                        // Update the update's properties using the raw data
                        try cachedUploads[index].update(with: uploadData, tags: tags, forUser: user)
                                                
                        // Append updated upload request ID
                        uploadIDs.append(cachedUploads[index].objectID)
                    }
                    else {
                        // Create an Upload managed object on the private queue context.
                        guard let upload = NSEntityDescription.insertNewObject(forEntityName: "Upload", into: taskContext) as? Upload
                        else { throw PwgKitError.uploadCreationError }
                        
                        do {
                            // Populate the Upload's properties using the data.
                            let tags = try TagProvider().getTags(withIDs: uploadData.tagIds, taskContext: taskContext)
                            try upload.update(with: uploadData, tags: tags, forUser: user)
                                                        
                            // Append new upload request ID
                            try taskContext.obtainPermanentIDs(for: [upload])
                            uploadIDs.append(upload.objectID)
                        }
                        catch let error as PwgKitError {
                            // Delete invalid Upload from the private queue context.
                            taskContext.delete(upload)
                            
                            // Save all insertions from the context to the store.
                            taskContext.saveIfNeeded()
                            
                            // Reset the taskContext to free the cache and lower the memory footprint.
                            taskContext.reset()

                            throw error
                        }
                        catch let error as NSError {
                            throw PwgKitError.CoreDataError(innerError: error)
                        }
                        catch {
                            throw PwgKitError.otherError(innerError: error)
                        }
                    }
                }
                
                // Save all insertions from the context to the store.
                taskContext.saveIfNeeded()
                
                // Reset the taskContext to free the cache and lower the memory footprint.
                taskContext.reset()

                // Return new and updated upload request IDs
                return uploadIDs
            }
        }
        catch let error as PwgKitError {
            throw error
        }
        catch let error as NSError {
            throw PwgKitError.CoreDataError(innerError: error)
        }
        catch {
            throw PwgKitError.otherError(innerError: error)
        }
    }
        
    /**
     Clear status of Core Data upload requests on the uploadKit private queue
     */
    public func clearFailedUploads(_ toResume: [NSManagedObjectID],
                                   inContext taskContext: NSManagedObjectContext) -> ([NSManagedObjectID], [NSManagedObjectID])
    {
        taskContext.performAndWait { () -> ([NSManagedObjectID], [NSManagedObjectID]) in
            // Upload requests to resume
            var toPrepare: [NSManagedObjectID] = []
            var toTransfer: [NSManagedObjectID] = []
            
            // Loop over the failed uploads
            for uploadID in toResume {
                // Retrieve upload object
                guard let failedUpload = try? taskContext.existingObject(with: uploadID) as? Upload
                else { continue }
                
                // Change state
                switch failedUpload.state {
                case .uploading, .uploadingError:
                    // -> Will retry to transfer the image
                    failedUpload.requestState = pwgUploadState.prepared.rawValue
                    failedUpload.requestSectionKey = pwgUploadState.prepared.sectionKey
                    failedUpload.requestError = ""
                    toTransfer.append(uploadID)

                case .finishing, .finishingError:
                    // -> Will retry to finish the upload
                    failedUpload.requestState = pwgUploadState.uploaded.rawValue
                    failedUpload.requestSectionKey = pwgUploadState.uploaded.sectionKey
                    failedUpload.requestError = ""
                    toTransfer.append(uploadID)
                    
                default:
                    // —> Will retry from scratch
                    failedUpload.requestState = pwgUploadState.waiting.rawValue
                    failedUpload.requestSectionKey = pwgUploadState.waiting.sectionKey
                    failedUpload.requestError = ""
                    toPrepare.append(uploadID)
                }
            }
            
            // Save modifications from the context to the store
            taskContext.saveIfNeeded()
            
            // Reset the taskContext to free the cache and lower the memory footprint.
            taskContext.reset()
            
            // Return IDs of upload requests to resume
            return (toPrepare, toTransfer)
        }
    }
    
    /**
     Updates an Upload instance from updated properties
     */
    public func updateUpload(withID uploadID: NSManagedObjectID, properties uploadData: UploadProperties,
                             inContext taskContext: NSManagedObjectContext) throws -> Void {
        try taskContext.performAndWait {
            // Get current user account
            guard let userURI = URL(string: uploadData.userURIstr),
                  let userID = taskContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: userURI),
                  let user = try taskContext.existingObject(with: userID) as? User
            else { throw PwgKitError.userCreationError }
            if user.isFault {
                // user is not fired yet.
                user.willAccessValue(forKey: nil)
                user.didAccessValue(forKey: nil)
            }
            
            // Retrieve upload object
            guard let upload = try taskContext.existingObject(with: uploadID) as? Upload
            else { throw PwgKitError.missingUploadData }
            
            // Get tag instances
            let tags = try TagProvider().getTags(withIDs: uploadData.tagIds, taskContext: taskContext)
            
            // Update the update's properties using the raw data
            try upload.update(with: uploadData, tags: tags, forUser: user)
            
            // Save modifications from the context’s parent store
            taskContext.saveIfNeeded()
        }
    }
    
    
    // MARK: - Get Upload Data
    /**
     Return the number of upload requests stored in cache
     */
    public func getTotalCount(inContext taskContext: NSManagedObjectContext) -> Int64
    {
        taskContext.performAndWait { () -> Int64 in
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
    }
    
    /**
        Retrieve the number of pending upload requests
     */
    public func getCountOfPendingUploads(inContext taskContext: NSManagedObjectContext) -> Int
    {
         taskContext.performAndWait { () -> Int in
            
            // Create a fetch request for the Upload entity sorted by date (oldest first)
            let fetchRequest = NSFetchRequest<NSNumber>(entityName: "Upload")
            fetchRequest.resultType = .countResultType

            // Retrieves only non-completed upload requests
            let variables = ["serverPath" : NetworkVars.shared.serverPath,
                             "userName"   : NetworkVars.shared.user]
            fetchRequest.predicate = pendingPredicate.withSubstitutionVariables(variables)
            fetchRequest.shouldRefreshRefetchedObjects = true

            // Fetch number of objects
            do {
                let countResult = try taskContext.fetch(fetchRequest)
                return countResult.first!.intValue
            }
            catch let error {
                debugPrint("••> Upload count not fetched: \(error.localizedDescription)")
            }
            return Int.zero
        }
    }
    
    /**
        Retrieve IDs of upload pending requests in given states on the uploadKit private queue
     */
    public func getIDsOfPendingUploads(onlyInStates states: [pwgUploadState] = [], onlyImages: [Int64] = [],
                                       onlyDeletable: Bool = false, markedForAutoUpload: Bool = false,
                                       inContext taskContext: NSManagedObjectContext) -> ([NSManagedObjectID], [String])
    {
        taskContext.performAndWait { () -> ([NSManagedObjectID], [String]) in
            
            // Create a fetch request for the Upload entity sorted by date (oldest first)
            let fetchRequest = Upload.fetchRequest()
            fetchRequest.sortDescriptors = sortDescriptors
            
            // Retrieves only non-completed upload requests
            let variables = ["serverPath" : NetworkVars.shared.serverPath,
                             "userName"   : NetworkVars.shared.user]
            fetchRequest.predicate = pendingPredicate.withSubstitutionVariables(variables)
            fetchRequest.returnsObjectsAsFaults = false
            fetchRequest.shouldRefreshRefetchedObjects = true
            
            // Fetch objects
            let pendingUploads: [Upload] = (try? taskContext.fetch(fetchRequest) as [Upload]) ?? []

            // Select only those which are deletable or not
            let deletableUploads = onlyDeletable ? pendingUploads.filter({ $0.deleteImageAfterUpload }) : pendingUploads
            
            // Select those requested by the auto-upload option or not
            let autoUploads = deletableUploads.filter({ $0.markedForAutoUpload == markedForAutoUpload})
            
            // Select only those in wanted states
            let uploadsInStates = states.isEmpty ? autoUploads : autoUploads.filter({ states.contains($0.state) })

            // Select those related with given Piwigo images
            let uploads = onlyImages.isEmpty ? uploadsInStates : uploadsInStates.filter({ onlyImages.contains($0.imageId) })
            
            // Return objectIDs and localIdentifiers
            return (uploads.map(\.objectID), uploads.map({ $0.localIdentifier }))
        }
    }
    
    /**
        Retrieve IDs of completed upload requests marked for deletion on the uploadKit private queue
     */
    public func getIDsOfCompletedUploads(onlyInStates states: [pwgUploadState] = [], onlyImages: [Int64] = [],
                                         onlyDeletable: Bool = false, notAutoUploaded: Bool = false,
                                         inContext taskContext: NSManagedObjectContext) -> ([NSManagedObjectID], [String])
    {
        taskContext.performAndWait { () -> ([NSManagedObjectID], [String]) in
            
            // Create a fetch request for the Upload entity sorted by date (oldest first)
            let fetchRequest = Upload.fetchRequest()
            fetchRequest.sortDescriptors = sortDescriptors
            
            // Retrieves only non-completed upload requests
            let variables = ["serverPath" : NetworkVars.shared.serverPath,
                             "userName"   : NetworkVars.shared.user]
            fetchRequest.predicate = completedPredicate.withSubstitutionVariables(variables)
            fetchRequest.returnsObjectsAsFaults = false
            fetchRequest.shouldRefreshRefetchedObjects = true
            
            // Fetch objects
            let completedUploads: [Upload] = (try? taskContext.fetch(fetchRequest) as [Upload]) ?? []
            
            // Select those which are deletable or not
            let deletableUploads = onlyDeletable ? completedUploads.filter({ $0.deleteImageAfterUpload }) : completedUploads
            
            // Select those which were not auto-uploaded
            let notAutoUploaded = notAutoUploaded ? deletableUploads.filter({ $0.markedForAutoUpload == false }) : deletableUploads
            
            // Select only those in wanted states
            let uploadsInStates = states.isEmpty ? notAutoUploaded : notAutoUploaded.filter({ states.contains($0.state) })
            
            // Select those related with given Piwigo images
            let uploads = onlyImages.isEmpty ? uploadsInStates : uploadsInStates.filter({ onlyImages.contains($0.imageId) })
            
            // Return objectIDs and localIdentifiers
            return (uploads.map(\.objectID), uploads.map({ $0.localIdentifier }))
        }
    }
    
    /**
     Called by UploadPhotosHandler
     Return the md5sum of the upload requests in cache in the background
     */
    public func getAllMd5sum() -> [String]
    {
        let bckgContext = DataController.shared.newTaskContext()
        return bckgContext.performAndWait {
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
            do {
                let cachedUploads = try bckgContext.fetch(fetchRequest)
                return cachedUploads.map(\.md5Sum)
            }
            catch {
                debugPrint("Error fetching uploads: \(error)")
                return []
            }
        }
    }
    
    /**
        Retrieve IDs of upload pending requests in given states on the uploadKit private queue
     */
    public func getPropertiesOfUpload(withID uploadID: NSManagedObjectID,
                                      inContext taskContext: NSManagedObjectContext) throws -> UploadProperties?
    {
        try taskContext.performAndWait { () throws -> UploadProperties? in
            // Get Upload instance
            guard let upload = try taskContext.existingObject(with: uploadID) as? Upload
            else { return nil }
            // Return Upload properties
            return upload.getProperties()
        }
    }
    
    
    // MARK: - Clear Upload Requests
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
    public func deleteUploads(withID uploadIDs: [NSManagedObjectID],
                              inContext taskContext: NSManagedObjectContext) throws(PwgKitError) {
        // Any upload request to delete?
        guard uploadIDs.isEmpty == false
        else { return }
        
        // Create batch delete request
        let batchDeleteRequest = NSBatchDeleteRequest(objectIDs: uploadIDs)
        
        // Execute batch delete request
        // Associated files will be deleted
        try taskContext.executeAndMergeChanges(using: batchDeleteRequest)
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
