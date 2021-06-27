//
//  TagsProvider.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/01/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
//  A class to fetch data from the remote server and save it to the Core Data store.

import CoreData

public class TagsProvider {

    public init() { }
    
    // MARK: - Piwigo API methods
    public let kPiwigoTagsGetImages = "format=json&method=pwg.tags.getImages"
    
    
    // MARK: - Core Data object context
    public lazy var managedObjectContext: NSManagedObjectContext = {
        let context:NSManagedObjectContext = DataController.managedObjectContext
        return context
    }()

    
    // MARK: - Fetch Tags
    /**
     Fetches the tag feed from the remote Piwigo server, and imports it into Core Data.
     The API method for admin pwg.tags.getAdminList does not return the number of tagged photos,
     so we must call pwg.tags.getList to present tagged photos when the user has admin rights.
     Because we wish to keep the tag list up-to-date, calling pwg.tags.getList leads to the deletions of unused tags in the store.
    */
    public func fetchTags(asAdmin: Bool, completionHandler: @escaping (Error?) -> Void) {

        // Prepare Piwigo JSON request
        let urlStr = "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)"
        let url = URL(string: urlStr + "/ws.php?\(asAdmin ? kPiwigoTagsGetAdminList : kPiwigoTagsGetList)")
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"

        // Launch the HTTP(S) request
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: asAdmin ? kPiwigoTagsGetAdminList : kPiwigoTagsGetList, paramDict: [:],
                                countOfBytesClientExpectsToReceive: NSURLSessionTransferSizeUnknown) { jsonData, error in
            // Any error?
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            if let error = error {
                completionHandler(error)
                return
            }
            
            // Decode the JSON and import it into Core Data.
            DispatchQueue.global(qos: .background).async {
                do {
                    // Decode the JSON into codable type TagJSON.
                    let decoder = JSONDecoder()
                    let tagJSON = try decoder.decode(TagJSON.self, from: jsonData)

                    // Piwigo error?
                    let error: NSError
                    if (tagJSON.errorCode != 0) {
                        error = NSError(domain: "Piwigo", code: tagJSON.errorCode,
                                        userInfo: [NSLocalizedDescriptionKey : tagJSON.errorMessage])
                        completionHandler(error)
                        return
                    }

                    // Import the tagJSON into Core Data.
                    try self.importTags(from: tagJSON.data)

                } catch {
                    // Alert the user if data cannot be digested.
                    completionHandler(TagError.wrongDataFormat)
                    return
                }
                completionHandler(nil)
            }
        }
    }
    
    /**
     Imports a JSON dictionary into the Core Data store on a private queue,
     processing the record in batches to avoid a high memory footprint.
    */
    private let batchSize = 256
    private func importTags(from tagPropertiesArray: [TagProperties]) throws {
        
        // Create a private queue context.
        let taskContext = DataController.privateManagedObjectContext
                
        // We shall perform at least one import in case where
        // the user did delete all tags or untag all photos
        guard !tagPropertiesArray.isEmpty else {
            _ = importOneBatch([TagProperties](), taskContext: taskContext)
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
            if !importOneBatch(tagsBatch, taskContext: taskContext) {
                return
            }
        }

        // Delete cached tags not in server
        deleteTagsNotOnServer(tagPropertiesArray, taskContext: taskContext)
    }
    
    /**
     Imports one batch of tags, creating managed objects from the new data,
     and saving them to the persistent store, on a private queue. After saving,
     resets the context to clean up the cache and lower the memory footprint.
     
     NSManagedObjectContext.performAndWait doesn't rethrow so this function
     catches throws within the closure and uses a return value to indicate
     whether the import is successful.
    */
    private func importOneBatch(_ tagsBatch: [TagProperties], taskContext: NSManagedObjectContext) -> Bool {
        
        var success = false

        // taskContext.performAndWait runs on the URLSession's delegate queue
        // so it won’t block the main thread.
        taskContext.performAndWait {
            
            // Retrieve existing tags
            // Create a fetch request for the Tag entity sorted by Id
            let fetchRequest = NSFetchRequest<Tag>(entityName: "Tag")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "tagId", ascending: true)]
            
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
            let cachedTags:[Tag] = controller.fetchedObjects ?? []

            // Loop over new tags
            for tagData in tagsBatch {
            
                // Index of this new tag in cache
                let index = cachedTags.firstIndex { $0.tagId == tagData.id! }
                
                // Is this tag already cached?
                if (index == nil) {
                    // Create a Tag managed object on the private queue context.
                    guard let tag = NSEntityDescription.insertNewObject(forEntityName: "Tag", into: taskContext) as? Tag else {
                        print(TagError.creationError.localizedDescription)
                        return
                    }
                    
                    // Populate the Tag's properties using the raw data.
                    do {
                        try tag.update(with: tagData)
                    }
                    catch TagError.missingData {
                        // Delete invalid Tag from the private queue context.
                        print(TagError.missingData.localizedDescription)
                        taskContext.delete(tag)
                    }
                    catch {
                        print(error.localizedDescription)
                    }
                }
                else {
                    // Update the tag's properties using the raw data
                    do {
                        try cachedTags[index!].update(with: tagData)
                    }
                    catch TagError.missingData {
                        // Could not perform the update
                        print(TagError.missingData.localizedDescription)
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
                    print("Error: \(error)\nCould not save Core Data context.")
                    return
                }
                // Reset the taskContext to free the cache and lower the memory footprint.
                taskContext.reset()
            }

            success = true
        }
        return success
    }
    
    private func deleteTagsNotOnServer(_ allTags: [TagProperties], taskContext: NSManagedObjectContext) {
        // Retrieve existing tags
        // Create a fetch request for the Tag entity sorted by Id
        let fetchRequest = NSFetchRequest<Tag>(entityName: "Tag")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "tagId", ascending: true)]
        
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
        let cachedTags:[Tag] = controller.fetchedObjects ?? []

        // Loop over tags in cache
        cachedTags.forEach { cachedTag in
            if cachedTag.isFault {
                cachedTag.willAccessValue(forKey: nil)
                cachedTag.didAccessValue(forKey: nil)
            }
            if !allTags.contains(where: { $0.id == cachedTag.tagId }) {
//                print("=> delete tag with ID:\(cachedTag.tagId) and name:\(cachedTag.tagName)")
                taskContext.delete(cachedTag)
            }
        }
        
        // Save all deletions from the context to the store.
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
                print("Error: \(error)\nCould not save Core Data context.")
                return
            }
            // Reset the taskContext to free the cache and lower the memory footprint.
            taskContext.reset()
        }
    }

    
    // MARK: - Add Tags
    /**
     Adds the tag to the remote Piwigo server, and imports it into Core Data (in the foreground).
    */
    public func addTag(with name: String, completionHandler: @escaping (Error?) -> Void) {
        
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kPiwigoTagsAdd, paramDict: ["name" : name],
                                countOfBytesClientExpectsToReceive: 3000) { jsonData, error in
            // Any error?
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            if let error = error {
                completionHandler(error)
                return
            }
            
            // Decode the JSON and import it into Core Data.
            do {
                // Decode the JSON into codable type TagJSON.
                let decoder = JSONDecoder()
                let tagJSON = try decoder.decode(TagAddJSON.self, from: jsonData)

                // Piwigo error?
                let error: NSError
                if (tagJSON.errorCode != 0) {
                    error = NSError(domain: "Piwigo", code: tagJSON.errorCode,
                                    userInfo: [NSLocalizedDescriptionKey : tagJSON.errorMessage])
                    completionHandler(error)
                    return
                }

                // Import the tagJSON into Core Data.
                let newTag = TagProperties(id: tagJSON.data.id,
                                           name: NetworkUtilities.utf8mb4String(from: name),
                                           lastmodified: "", counter: 0, url_name: "", url: "")

                // Import the new tag in a private queue context.
                let taskContext = DataController.privateManagedObjectContext
                if self.importOneTag(newTag, taskContext: taskContext) {
                    completionHandler(nil)
                } else {
                    completionHandler(TagError.creationError)
                }

            } catch {
                // Alert the user if data cannot be digested.
                completionHandler(TagError.wrongDataFormat)
                return
            }
        }
    }

    /**
     Imports one tag, creating managed object from the new data,
     and saving it to the persistent store, on a private queue. After saving,
     resets the context to clean up the cache and lower the memory footprint.
     
     NSManagedObjectContext.performAndWait doesn't rethrow so this function
     catches throws within the closure and uses a return value to indicate
     whether the import is successful.
    */
    private func importOneTag(_ tagData: TagProperties, taskContext: NSManagedObjectContext) -> Bool {
        
        var success = false

        // taskContext.performAndWait runs on the URLSession's delegate queue
        // so it won’t block the main thread.
        taskContext.performAndWait {
            
            // Retrieve existing tags
            // Create a fetch request for the Tag entity sorted by Id
            let fetchRequest = NSFetchRequest<Tag>(entityName: "Tag")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "tagId", ascending: true)]
            
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
            let cachedTags:[Tag] = controller.fetchedObjects ?? []

            // Index of this new tag in cache
            let index = cachedTags.firstIndex { $0.tagId == tagData.id! }
            
            // Is this tag already cached?
            if (index == nil) {
                // Create a Tag managed object on the private queue context.
                guard let tag = NSEntityDescription.insertNewObject(forEntityName: "Tag", into: taskContext) as? Tag else {
                    print(TagError.creationError.localizedDescription)
                    return
                }
                
                // Populate the Tag's properties using the raw data.
                do {
                    try tag.update(with: tagData)
                }
                catch TagError.missingData {
                    // Delete invalid Tag from the private queue context.
                    print(TagError.missingData.localizedDescription)
                    taskContext.delete(tag)
                }
                catch {
                    print(error.localizedDescription)
                }
            }
            else {
                // Update the tag's properties using the raw data
                do {
                    try cachedTags[index!].update(with: tagData)
                }
                catch TagError.missingData {
                    // Could not perform the update
                    print(TagError.missingData.localizedDescription)
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
                    print("Error: \(error)\nCould not save Core Data context.")
                    return
                }
                // Reset the taskContext to free the cache and lower the memory footprint.
                taskContext.reset()
            }

            success = true
        }
        return success
    }
    
    
    // MARK: - Clear Tags
    /**
     Clear cached Core Data tag entry
    */
    public func clearTags() {
        
        // Create a fetch request for the Tag entity
        let fetchRequest = NSFetchRequest<Tag>(entityName: "Tag")

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
     A fetched results controller delegate to give consumers a chance to update
     the user interface when content changes.
     */
    public weak var fetchedResultsControllerDelegate: NSFetchedResultsControllerDelegate?
    
    /**
     A fetched results controller to fetch Tag records sorted by name.
     */
    public lazy var fetchedResultsController: NSFetchedResultsController<Tag> = {
        
        // Create a fetch request for the Tag entity sorted by name.
        let fetchRequest = NSFetchRequest<Tag>(entityName: "Tag")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "tagName", ascending: true,
                                         selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
        
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
}
