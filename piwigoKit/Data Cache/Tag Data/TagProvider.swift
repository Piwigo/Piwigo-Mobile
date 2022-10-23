//
//  TagProvider.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 19/01/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import CoreData
import CoreMedia

public class TagProvider: NSObject {
        
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
    private lazy var serverProvider: ServerProvider = {
        let provider : ServerProvider = ServerProvider()
        return provider
    }()


    // MARK: - Fetch Tags
    /**
     Fetches the tag feed from the remote Piwigo server, and imports it into Core Data.
     The API method for admin pwg.tags.getAdminList does not return the number of tagged photos,
     so we must call pwg.tags.getList to present tagged photos when the user has admin rights.
    */
    public func fetchTags(asAdmin: Bool, completionHandler: @escaping (Error?) -> Void) {
        // Launch the HTTP(S) request
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: asAdmin ? pwgTagsGetAdminList : pwgTagsGetList, paramDict: [:],
                                jsonObjectClientExpectsToReceive: TagJSON.self,
                                countOfBytesClientExpectsToReceive: NSURLSessionTransferSizeUnknown) { jsonData in
            // Decode the JSON object and import it into Core Data.
            DispatchQueue.global(qos: .background).async {
                do {
                    // Decode the JSON into codable type TagJSON.
                    let decoder = JSONDecoder()
                    let tagJSON = try decoder.decode(TagJSON.self, from: jsonData)

                    // Piwigo error?
                    if tagJSON.errorCode != 0 {
                        let error = PwgSession.shared.localizedError(for: tagJSON.errorCode,
                                                                     errorMessage: tagJSON.errorMessage)
                        completionHandler(error)
                        return
                    }

                    // Import the tagJSON into Core Data.
                    try self.importTags(from: tagJSON.data, asAdmin: asAdmin)

                } catch {
                    // Alert the user if data cannot be digested.
                    let error = error as NSError
                    completionHandler(error)
                    return
                }
                completionHandler(nil)
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            completionHandler(error)
        }
    }
    
    /**
     Imports a JSON dictionary into the Core Data store on a private queue,
     processing the record in batches to avoid a high memory footprint.
    */
    private let batchSize = 256
    private func importTags(from tagPropertiesArray: [TagProperties], asAdmin: Bool) throws {
        // Get current server object
        guard let server = serverProvider.getServer(inContext: bckgContext) else {
            fatalError("Unresolved error!")
        }
        
        // We shall perform at least one import in case where
        // the user did delete all tags or untag all photos
        guard tagPropertiesArray.isEmpty == false else {
            _ = importOneBatch([TagProperties](), from: server, asAdmin: asAdmin)
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
            if !importOneBatch(tagsBatch, from: server, asAdmin: asAdmin) {
                return
            }
        }
    }
    
    /**
     Imports one batch of tags, creating managed objects from the new data,
     and saving them to the persistent store, on a private queue. After saving,
     resets the context to clean up the cache and lower the memory footprint.
     
     NSManagedObjectContext.performAndWait doesn't rethrow so this function
     catches throws within the closure and uses a return value to indicate
     whether the import is successful.
    */
    private func importOneBatch(_ tagsBatch: [TagProperties], from server: Server, asAdmin: Bool) -> Bool {
        
        var success = false

        // taskContext.performAndWait runs on the URLSession's delegate queue
        // so it won’t block the main thread.
        bckgContext.performAndWait {
            
            // Retrieve tags in persistent store
            let fetchRequest = Tag.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Tag.tagId), ascending: true)]
            
            // Look for tags belonging to the currently active server
            var andPredicates = [NSPredicate]()
            andPredicates.append(NSPredicate(format: "server.path == %@", server.path))
            if asAdmin == false {
                // Look for non-orphaned tags if method called by non-admin user
                andPredicates.append(NSPredicate(format: "numberOfImagesUnderTag != %ld", 0))
                andPredicates.append(NSPredicate(format: "numberOfImagesUnderTag != %ld", Int64.max))
            }
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)

            // Create a fetched results controller and set its fetch request, context, and delegate.
            let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                managedObjectContext: self.bckgContext,
                                                  sectionNameKeyPath: nil, cacheName: nil)
            
            // Perform the fetch.
            do {
                try controller.performFetch()
            } catch {
                fatalError("Unresolved error \(error)")
            }
            let cachedTags:[Tag] = controller.fetchedObjects ?? []

            // Loop over new tags
            for tagData in tagsBatch {
            
                // Index of this new tag in cache
                guard let ID = tagData.id?.int32Value else { continue }
                if let index = cachedTags.firstIndex(where: { $0.tagId == ID }) {
                    // Update the tag's properties using the raw data
                    do {
                        try cachedTags[index].update(with: tagData, server: server)
                    }
                    catch TagError.missingData {
                        // Could not perform the update
                        print(TagError.missingData.localizedDescription)
                    }
                    catch {
                        print(error.localizedDescription)
                    }
                }
                else {
                    // Create a Tag managed object on the private queue context.
                    guard let tag = NSEntityDescription.insertNewObject(forEntityName: "Tag",
                                                                        into: bckgContext) as? Tag else {
                        print(TagError.creationError.localizedDescription)
                        return
                    }
                    
                    // Populate the Tag's properties using the raw data.
                    do {
                        try tag.update(with: tagData, server: server)
                    }
                    catch TagError.missingData {
                        // Delete invalid Tag from the private queue context.
                        print(TagError.missingData.localizedDescription)
                        bckgContext.delete(tag)
                    }
                    catch {
                        print(error.localizedDescription)
                    }
                }
            }
            
            // Remove deleted tags
            let newTagIds = tagsBatch.compactMap({$0.id}).compactMap({$0.int32Value})
            let cachedTagsToDelete = cachedTags.filter({newTagIds.contains($0.tagId) == false})
            cachedTagsToDelete.forEach { cachedTag in
                print("=> delete tag with ID:\(cachedTag.tagId) and name:\(cachedTag.tagName)")
                bckgContext.delete(cachedTag)
            }
            
            // Save all insertions from the context to the store.
            if bckgContext.hasChanges {
                do {
                    try bckgContext.save()
                    DispatchQueue.main.async {
                        DataController.shared.saveMainContext()
                    }
                }
                catch {
                    print("Error: \(error)\nCould not save Core Data context.")
                    return
                }
                // Reset the taskContext to free the cache and lower the memory footprint.
                bckgContext.reset()
            }

            success = true
        }
        return success
    }
    
    
    // MARK: - Add Tags
    /**
     Adds a tag to the remote Piwigo server, and imports it into Core Data.
    */
    public func addTag(with name: String, completionHandler: @escaping (Error?) -> Void) {
                
        // Add tag on server
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgTagsAdd, paramDict: ["name" : name],
                                jsonObjectClientExpectsToReceive: TagAddJSON.self,
                                countOfBytesClientExpectsToReceive: 3000) { jsonData in
            // Decode the JSON object and import it into Core Data.
            do {
                // Decode the JSON into codable type TagJSON.
                let decoder = JSONDecoder()
                let tagJSON = try decoder.decode(TagAddJSON.self, from: jsonData)

                // Piwigo error?
                if tagJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: tagJSON.errorCode,
                                                        errorMessage: tagJSON.errorMessage)
                    completionHandler(error)
                    return
                }

                // Import the tagJSON into Core Data.
                guard let tagId = tagJSON.data.id else {
                    completionHandler(TagError.missingData)
                    return
                }
                let newTag = TagProperties(id: StringOrInt.integer(Int(tagId)),
                                           name: NetworkUtilities.utf8mb4String(from: name),
                                           lastmodified: "", counter: 0, url_name: "", url: "")

                // Import the new tag in a private queue context.
                if let server = self.serverProvider.getServer(inContext: self.bckgContext),
                   self.importOneBatch([newTag], from: server, asAdmin: true) {
                    completionHandler(nil)
                } else {
                    completionHandler(TagError.creationError)
                }

            } catch {
                // Alert the user if data cannot be digested.
                let error = error as NSError
                completionHandler(error)
                return
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            completionHandler(error)
        }
    }
    
    
    // MARK: - Get Tags with set of IDs
    /**
     Get all Tag instances of the current server matching the list of tag IDs
    */
    func getTags(withIDs tagIds: String, taskContext: NSManagedObjectContext) -> [Tag] {
        // Initialisation
        var tagList = [Tag]()
        
        taskContext.performAndWait {
            // Retrieve tags in persistent store
            let fetchRequest = Tag.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Tag.tagId), ascending: true)]
            
            // Look for tags belonging to the currently active server
            fetchRequest.predicate = NSPredicate(format: "server.path == %@", NetworkVars.serverPath)

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
            
            // Tag selection
            let cachedTags:[Tag] = controller.fetchedObjects ?? []
            let listOfIds = tagIds.components(separatedBy: ",").compactMap({ Int32($0) })
            tagList = cachedTags.filter({ listOfIds.contains($0.tagId)})
        }

        return tagList
    }
    
    
    // MARK: - Clear Tags
    /**
     Clears all Core Data tag entries of the current server.
    */
    public func clearTags() {
        
        // Create a fetch request for the Tag entity
        let fetchRequest = Tag.fetchRequest()

        // Select tags of the current server only
        fetchRequest.predicate = NSPredicate(format: "server.path == %@", NetworkVars.serverPath)

        // Create batch delete request
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)

        // Execute batch delete request
        try? mainContext.executeAndMergeChanges(using: batchDeleteRequest)
    }
    

    // MARK: - NSFetchedResultsController
    
    /**
     A fetched results controller delegate to give consumers a chance to update
     the TagsViewController user interface when content changes.
     */
    public weak var fetchedResultsControllerDelegate: NSFetchedResultsControllerDelegate?
    
    /**
     A fetched results controller to fetch Tag records of the current server, sorted by name.
     */
    public lazy var fetchedResultsController: NSFetchedResultsController<Tag> = {
        
        // Create a fetch request for the Tag entity sorted by name.
        let fetchRequest = Tag.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Tag.tagName), ascending: true,
                                         selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
        
        // Select tags of the current server only
        fetchRequest.predicate = NSPredicate(format: "server.path == %@", NetworkVars.serverPath)

        // Create a fetched results controller and set its fetch request, context, and delegate.
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                            managedObjectContext: mainContext,
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
}
