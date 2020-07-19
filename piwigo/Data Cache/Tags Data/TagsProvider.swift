//
//  TagsProvider.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/01/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
//  A class to fetch data from the remote server and save it to the Core Data store.

import CoreData

class TagsProvider {

    // MARK: - Piwigo API methods

    let kPiwigoTagsGetList = "format=json&method=pwg.tags.getList"
    let kPiwigoTagsGetAdminList = "format=json&method=pwg.tags.getAdminList"
    let kPiwigoTagsGetImages = "format=json&method=pwg.tags.getImages"
    let kPiwigoTagsAdd = "format=json&method=pwg.tags.add"
    
    
    // MARK: - Core Data object context
    
    lazy var managedObjectContext: NSManagedObjectContext = {
        let context:NSManagedObjectContext = (UIApplication.shared.delegate as! AppDelegate).managedObjectContext
        return context
    }()

    
    // MARK: - Fetch Tags
    /**
     Fetches the tag feed from the remote Piwigo server, and imports it into Core Data.
    */
    func fetchTags(asAdmin: Bool, completionHandler: @escaping (Error?) -> Void) {

        NetworkHandler.post(asAdmin ? kPiwigoTagsGetAdminList : kPiwigoTagsGetList, urlParameters: nil, parameters: nil, progress: nil, success: { (task, jsonData) in

            // Alert the user if no data comes back.
            guard let data = try? JSONSerialization.data(withJSONObject:jsonData ?? "") else {
                completionHandler(TagError.networkUnavailable)
                return
            }

            // Decode the JSON and import it into Core Data.
            do {
                // Decode the JSON into codable type TagJSON.
                let decoder = JSONDecoder()
                let tagJSON = try decoder.decode(TagJSON.self, from: data)

                // Piwigo error?
                let error: NSError
                if (tagJSON.errorCode != 0) {
                    error = NSError.init(domain: "Piwigo", code: tagJSON.errorCode, userInfo: [NSLocalizedDescriptionKey : tagJSON.errorMessage])
                    completionHandler(error)
                    return
                }

                // Import the tagJSON into Core Data.
                try self.importTags(from: tagJSON)

            } catch {
                // Alert the user if data cannot be digested.
                completionHandler(TagError.wrongDataFormat)
                return
            }
            completionHandler(nil)
        }) { (task, error) in
            completionHandler(TagError.networkUnavailable)
        }
    }
    
    /**
     Imports a JSON dictionary into the Core Data store on a private queue,
     processing the record in batches to avoid a high memory footprint.
    */
    private func importTags(from tagJSON: TagJSON) throws {
        
        guard !tagJSON.tagPropertiesArray.isEmpty else { return }
        
        // Create a private queue context.
        let taskContext = DataController.getPrivateContext()
                
        // Process records in batches to avoid a high memory footprint.
        let batchSize = 256
        let count = tagJSON.tagPropertiesArray.count
        
        // Determine the total number of batches.
        var numBatches = count / batchSize
        numBatches += count % batchSize > 0 ? 1 : 0
        
        for batchNumber in 0 ..< numBatches {
            
            // Determine the range for this batch.
            let batchStart = batchNumber * batchSize
            let batchEnd = batchStart + min(batchSize, count - batchNumber * batchSize)
            let range = batchStart..<batchEnd
            
            // Create a batch for this range from the decoded JSON.
            let tagsBatch = Array(tagJSON.tagPropertiesArray[range])
            
            // Stop the entire import if any batch is unsuccessful.
            if !importOneBatch(tagsBatch, taskContext: taskContext) {
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

            // Initialise list of tags to delete
            let indexesOfTagsToUpdate: NSMutableIndexSet = NSMutableIndexSet.init()

            // Loop over new tags
            for tagData in tagsBatch {
            
                // Index of this new tag in cache
                let index = cachedTags.firstIndex { (item) -> Bool in
                    item.tagId == tagData.id!
                }
                
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
                    indexesOfTagsToUpdate.add(index!)
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
            
            // Delete cached tags which were not returned by the Piwigo server
            for index in 0..<cachedTags.count {
                
                // Delete tags which were not updated
                if !indexesOfTagsToUpdate.contains(index) {
                    taskContext.delete(cachedTags[index])
                }
            }
                        
            // Save all insertions and deletions from the context to the store.
            if taskContext.hasChanges {
                do {
                    try taskContext.save()
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
    func clearTags() {
        
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
    weak var fetchedResultsControllerDelegate: NSFetchedResultsControllerDelegate?
    
    /**
     A fetched results controller to fetch Tag records sorted by name.
     */
    lazy var fetchedResultsController: NSFetchedResultsController<Tag> = {
        
        // Create a fetch request for the Tag entity sorted by name.
        let fetchRequest = NSFetchRequest<Tag>(entityName: "Tag")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "tagName", ascending: true)]
        
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
