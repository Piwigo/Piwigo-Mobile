//
//  TagProvider.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 19/01/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import CoreData
import CoreMedia

public final class TagProvider {
        
    public init() {}    // To make this class public
    
    
    // MARK: - Fetch Tags
    /**
     Fetches the tag feed from the remote Piwigo server, and imports it into Core Data.
     The API method for admin pwg.tags.getAdminList does not return the number of tagged photos,
     so we must call pwg.tags.getList to present tagged photos when the user has admin rights.
    */
    public func fetchTags(asAdmin: Bool, completion: @escaping (PwgKitError?) -> Void) {
        // Launch the HTTP(S) request
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: asAdmin ? pwgTagsGetAdminList : pwgTagsGetList, paramDict: [:],
                                jsonObjectClientExpectsToReceive: TagJSON.self,
                                countOfBytesClientExpectsToReceive: NSURLSessionTransferSizeUnknown) { result in
            switch result {
            case .success(let pwgData):
                // Import tag data into Core Data.
                do {
                    try self.importTags(from: pwgData.data, asAdmin: asAdmin)
                    completion(nil)
                }
                catch let error as PwgKitError {
                    completion(error)
                }
                catch {
                    completion(.otherError(innerError: error))
                }
                
            case .failure(let error):
                /// - Network communication errors
                /// - Returned JSON data is empty
                /// - Cannot decode data returned by Piwigo server
                completion(error)
            }
        }
    }
    
    /**
     Imports a JSON dictionary into the Core Data store on a private queue,
     processing the record in batches to avoid a high memory footprint.
    */
    private let batchSize = 256
    private func importTags(from tagPropertiesArray: [TagProperties], asAdmin: Bool) throws {
        // We keep IDs of tags to delete
        // Initialised and then updated at each iteration
        var tagToDeleteIDs: Set<Int32>? = nil

        // We shall perform at least one import in case where
        // the user did delete all tags or untag all photos
        guard tagPropertiesArray.isEmpty == false else {
            _ = try importOneBatch([TagProperties](), asAdmin: asAdmin, tagIDs: tagToDeleteIDs)
            return
        }
        
        // Process records in batches to avoid a high memory footprint.
        let count = tagPropertiesArray.count
        
        // Determine the total number of batches.
        var numBatches = count / batchSize
        numBatches += count % batchSize > 0 ? 1 : 0
        
        // Loop over the batches
        for batchNumber in 0 ..< numBatches {
            
            // Determine the range for this batch.
            let batchStart = batchNumber * batchSize
            let batchEnd = batchStart + min(batchSize, count - batchNumber * batchSize)
            let range = batchStart..<batchEnd
            
            // Create a batch for this range from the decoded JSON.
            let tagsBatch = Array(tagPropertiesArray[range])
            
            // Stop the entire import if any batch is unsuccessful.
            let tagIDs = try importOneBatch(tagsBatch, asAdmin: asAdmin, tagIDs: tagToDeleteIDs)
            tagToDeleteIDs = tagIDs
        }
    }
    
    /**
     Imports one batch of tags, creating managed objects from the new data,
     and saving them to the persistent store, on a private queue. After saving,
     resets the context to clean up the cache and lower the memory footprint.
     
     NSManagedObjectContext.performAndWait doesn't rethrow so this function
     catches throws within the closure and uses a return value to indicate
     whether the import is successful.
     
     tagIDs is nil or contains the IDs of tags to delete.
    */
    func importOneBatch(_ tagsBatch: [TagProperties], asAdmin: Bool,
                        tagIDs: Set<Int32>?) throws -> Set<Int32> {

        var tagToDeleteIDs = Set<Int32>()

        // taskContext.performAndWait runs on the URLSession's delegate queue
        // so it won’t block the main thread.
        let bckgContext = DataController.shared.newTaskContext()
        try bckgContext.performAndWait {
            
            // Get current server object
            guard let server = try ServerProvider().getServer(inContext: bckgContext) else {
                debugPrint(PwgKitError.tagCreationError.localizedDescription)
                return
            }
            
            // Retrieve tags in persistent store
            let fetchRequest = Tag.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Tag.tagName), ascending: true,
                                             selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]

            // Look for tags belonging to the currently active server
            fetchRequest.predicate = NSPredicate(format: "server.path == %@", server.path)

            // Perform the fetch.
            let cachedTags:[Tag] = try bckgContext.fetch(fetchRequest)

            // Initialise set of tag IDs during the first iteration
            if tagIDs == nil {
                // Store IDs of present list of tags
                tagToDeleteIDs = Set(cachedTags.map({$0.tagId}))
            } else {
                // Resume IDs of tags to delete
                tagToDeleteIDs = tagIDs ?? Set<Int32>()
            }
            
            // Loop over new tags
            for tagData in tagsBatch {
            
                // Index of this new tag in cache
                guard let ID = tagData.id?.int32Value else { continue }
                if let index = cachedTags.firstIndex(where: { $0.tagId == ID }) {
                    // Update the tag's properties using the raw data
                    do {
                        try cachedTags[index].update(with: tagData, server: server)
                        
                        // Do not delete this tag during the last interation of the import
                        tagToDeleteIDs.remove(ID)
                    }
                    catch let error as PwgKitError {
                        // Could not perform the update
                        throw error
                    }
                    catch {
                        throw PwgKitError.otherError(innerError: error)
                    }
                }
                else {
                    // Create a Tag managed object on the private queue context.
                    let tag = Tag(context: bckgContext)
                    
                    // Populate the Tag's properties using the raw data.
                    do {
                        try tag.update(with: tagData, server: server)
                    }
                    catch let error as PwgKitError {
                        // Delete invalid Tag from the private queue context.
                        bckgContext.delete(tag)
                        throw error
                    }
                    catch {
                        // Delete invalid Tag from the private queue context.
                        bckgContext.delete(tag)
                        throw PwgKitError.otherError(innerError: error)
                    }
                }
            }
            
            // Delete remaining tags if this is the last iteration
            if tagsBatch.count < batchSize,
               tagToDeleteIDs.isEmpty == false {
                // Delete tags
                let tagToDelete = cachedTags.filter({tagToDeleteIDs.contains($0.tagId)})
                tagToDelete.forEach { tag in
                    debugPrint("••> delete tag with ID:\(tag.tagId) and name:\(tag.tagName)")
                    bckgContext.delete(tag)
                }
            }
            
            // Save all insertions from the context to the store.
            bckgContext.saveIfNeeded()

            // Reset the taskContext to free the cache and lower the memory footprint.
            bckgContext.reset()

            // Save cached data in the main thread
            Task { @MainActor in
                DataController.shared.mainContext.saveIfNeeded()
            }
        }
        return tagToDeleteIDs
    }
    
    
    // MARK: - Add Tags
    /**
     Adds a tag to the remote Piwigo server, and imports it into Core Data.
    */
    public func addTag(with name: String, completion: @escaping (PwgKitError?) -> Void) {
                
        // Add tag on server
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgTagsAdd, paramDict: ["name" : name],
                                jsonObjectClientExpectsToReceive: TagAddJSON.self,
                                countOfBytesClientExpectsToReceive: 3000) { result in
            switch result {
            case .success(let pwgData):
                // Import the tagJSON into Core Data.
                guard let tagId = pwgData.data.id else {
                    completion(PwgKitError.missingTagData)
                    return
                }
                let newTag = TagProperties(id: StringOrInt.integer(Int(tagId)),
                                           name: name.utf8mb4Encoded,
                                           lastmodified: "", counter: 0, url_name: "", url: "")

                // Import the new tag in a private queue context
                do {
                    let _ = try self.importOneBatch([newTag], asAdmin: true, tagIDs: Set<Int32>())
                    completion(nil)
                }
                catch let error as PwgKitError {
                    completion(error)
                }
                catch {
                    completion(PwgKitError.otherError(innerError: error))
                }
                
            case .failure(let error):
                /// - Network communication errors
                /// - Returned JSON data is empty
                /// - Cannot decode data returned by Piwigo server
                completion(error)
            }
        }
    }
    
    
    // MARK: - Get Tags with set of IDs
    /**
     Get all Tag instances of the current server matching the list of tag IDs
    */
    public func getTags(withIDs tagIds: String, taskContext: NSManagedObjectContext) throws -> Set<Tag> {
        // Initialisation
        var tagList = Set<Tag>()
        
        try taskContext.performAndWait {
            // Retrieve tags in persistent store
            let fetchRequest = Tag.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Tag.tagName), ascending: true)]
            
            // Look for tags belonging to the currently active server
            fetchRequest.predicate = NSPredicate(format: "server.path == %@", NetworkVars.shared.serverPath)

            // Tag selection
            let cachedTags:[Tag] = try taskContext.fetch(fetchRequest)
            let listOfIds = tagIds.components(separatedBy: ",").compactMap({ Int32($0) })
            tagList = Set(cachedTags.filter({ listOfIds.contains($0.tagId)}))
        }

        return tagList
    }
    
    
    // MARK: - Clear Tags
    /**
        Return number of tags stored in cache
     */
    public func getObjectCount(inContext taskContext: NSManagedObjectContext) -> Int64 {

        // Create a fetch request for the Tag entity
        let fetchRequest = NSFetchRequest<NSNumber>(entityName: "Tag")
        fetchRequest.resultType = .countResultType
        
        // Select tags of the current server only
        fetchRequest.predicate = NSPredicate(format: "server.path == %@", NetworkVars.shared.serverPath)

        // Fetch number of objects
        do {
            let countResult = try taskContext.fetch(fetchRequest)
            return countResult.first!.int64Value
        }
        catch let error {
            debugPrint("••> Tag count not fetched: \(error.localizedDescription)")
        }
        return Int64.zero
    }
        
    /**
     Clears all Core Data tag entries of the current server.
    */
    public func clearAll() {
        
        // Create a fetch request for the Tag entity
        let fetchRequest = Tag.fetchRequest()

        // Select tags of the current server only
        fetchRequest.predicate = NSPredicate(format: "server.path == %@", NetworkVars.shared.serverPath)

        // Create batch delete request
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<any NSFetchRequestResult>)

        // Execute batch delete request
        let bckgContext = DataController.shared.newTaskContext()
        try? bckgContext.executeAndMergeChanges(using: batchDeleteRequest)
    }
}
