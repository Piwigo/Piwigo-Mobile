//
//  UploadManager+UploadProvider.swift
//  uploadKit
//
//  Created by Eddy Lelièvre-Berna on 11/01/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import piwigoKit

extension UploadProvider {
    
    // MARK: - Add/Update Upload Requests
    /**
     Adds or updates a batch of upload requests into the Core Data store on a private queue,
     processing the record in batches to avoid a high memory footprint.
     */
    @UploadManagerActor
    public func importUploads(from uploadRequest: [UploadProperties]) async throws -> [NSManagedObjectID] {
        
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
            let uploadIDsInBatch = try await importOneBatch(uploadsBatch)
            uploadIDs.append(contentsOf: uploadIDsInBatch)
        }
        return uploadIDs
    }
    
    /**
     Adds or updates one batch of upload requests, creating managed objects from the new data,
     and saving them to the persistent store, on a private queue. After saving,
     resets the context to clean up the cache and lower the memory footprint.
     
     NSManagedObjectContext.performAndWait doesn't rethrow so this function
     catches throws within the closure and uses a return value to indicate
     whether the import is successful.
     */
    @UploadManagerActor
    private func importOneBatch(_ uploadsBatch: [UploadProperties]) async throws -> [NSManagedObjectID] {
        
        // performAndWait runs on the URLSession's delegate queue
        // so it won’t block the main thread.
        // Main context automatically sees changes via merge
        var uploadIDs: [NSManagedObjectID] = []
        let bckgContext = UploadManager.shared.uploadBckgContext
        
        // Get current user account
        guard let user = try UserProvider().getUserAccount(inContext: bckgContext)
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
        let cachedUploads = try bckgContext.fetch(fetchRequest)
        for uploadData in uploadsBatch {
            // Index of this new upload in cache
            if let index = cachedUploads.firstIndex( where: { $0.localIdentifier == uploadData.localIdentifier }) {
                // Get tag instances
                let tags = try TagProvider().getTags(withIDs: uploadData.tagIds, taskContext: bckgContext)

                // Update the update's properties using the raw data
                try cachedUploads[index].update(with: uploadData, tags: tags, forUser: user)
                
                // Save update from the context to disk
                bckgContext.saveIfNeeded()
                    
                // Append updated upload request ID
                uploadIDs.append(cachedUploads[index].objectID)
            }
            else {
                // Create an Upload managed object on the private queue context.
                guard let upload = NSEntityDescription.insertNewObject(forEntityName: "Upload", into: bckgContext) as? Upload
                else { throw PwgKitError.uploadCreationError }
                
                do {
                    // Populate the Upload's properties using the data.
                    let tags = try TagProvider().getTags(withIDs: uploadData.tagIds, taskContext: bckgContext)
                    try upload.update(with: uploadData, tags: tags, forUser: user)
                    
                    // Save insertion from the context to disk
                    bckgContext.saveIfNeeded()
                    
                    // Append new upload request ID
                    uploadIDs.append(upload.objectID)
                }
                catch let error as PwgKitError {
                    // Delete invalid Upload from the private queue context.
                    bckgContext.delete(upload)

                    // Save deletion from the context to disk
                    bckgContext.saveIfNeeded()
                    
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
        
//        await MainActor.run {
//            DataController.shared.mainContext.saveIfNeeded()
//        }

        // Return new and updated upload request IDs
        return uploadIDs
    }
}
