//
//  ImageProvider.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 12/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import CoreData

public class ImageProvider: NSObject {
    
    // MARK: - Core Data Object Contexts
//    private lazy var mainContext: NSManagedObjectContext = {
//        let context:NSManagedObjectContext = DataController.shared.mainContext
//        return context
//    }()
    
    private lazy var bckgContext: NSManagedObjectContext = {
        let context:NSManagedObjectContext = DataController.shared.bckgContext
        return context
    }()
    
    
    // MARK: - Core Data Providers
    private lazy var albumProvider: AlbumProvider = {
        let provider : AlbumProvider = AlbumProvider()
        return provider
    }()
    
    private lazy var userProvider: UserProvider = {
        let provider : UserProvider = UserProvider()
        return provider
    }()
    
    private lazy var tagProvider: TagProvider = {
        let provider : TagProvider = TagProvider()
        return provider
    }()
    
    
    // MARK: - Get Images
    func frcOfImage(inContext taskContext: NSManagedObjectContext,
                    withIds imageIds: Set<Int64>) -> NSFetchedResultsController<Image> {
        let fetchRequest = Image.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Image.pwgID), ascending: true)]

        // Select images:
        /// — of the current server accessible to the current user
        /// — having an ID matching one of the given image IDs
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "pwgID IN %@", Array(imageIds)))
        andPredicates.append(NSPredicate(format: "server.path == %@", NetworkVars.serverPath))
        andPredicates.append(NSPredicate(format: "ANY users.username == %@", NetworkVars.username))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)

        // Create a fetched results controller and set its fetch request and context.
        let image = NSFetchedResultsController(fetchRequest: fetchRequest,
                                               managedObjectContext: taskContext,
                                               sectionNameKeyPath: nil, cacheName: nil)
        return image
    }

    public func getImages(inContext taskContext: NSManagedObjectContext,
                          withIds imageIds: Set<Int64>) -> [Image] {

        // Initialisation
        var cachedImages = [Image]()
        
        // Retrieve image objects
        taskContext.performAndWait {
            
            // Create a fetched results controller and set its fetch request, context, and delegate.
            let controller = frcOfImage(inContext: taskContext, withIds: imageIds)
            
            // Perform the fetch.
            do {
                try controller.performFetch()
            } catch {
                fatalError("Unresolved error \(error)")
            }
            
            // Return image objects
            cachedImages = controller.fetchedObjects ?? []
        }

        return cachedImages
    }


    // MARK: - Fetch Images
    /**
     Fetches the image feed from the remote Piwigo server, and imports it into Core Data.
     */
    public func fetchImages(ofAlbumWithId albumId: Int32, withQuery query: String,
                            sort: pwgImageSort, fromPage page:Int, perPage: Int,
                            completion: @escaping (Set<Int64>, Int64, Error?) -> Void) {
        print("••> Fetch images of album \(albumId) at page \(page)…")
        // Prepare parameters for collecting image data
        var method = pwgCategoriesGetImages
        var paramsDict: [String : Any] = [
            "per_page"  : perPage,
            "page"      : page,
            "order"     : sort.param
        ]
        switch albumId {
        case pwgSmartAlbum.search.rawValue:
            method = pwgImagesSearch
            paramsDict["query"] = query

        case pwgSmartAlbum.visits.rawValue:
            paramsDict["recursive"] = true
            paramsDict["f_min_hit"] = 1
            
        case pwgSmartAlbum.best.rawValue:
            paramsDict["recursive"] = true
            paramsDict["f_min_rate"] = 1

        case pwgSmartAlbum.recent.rawValue:
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let threeMonthsAgo = Date(timeIntervalSinceNow: TimeInterval(-3600*24*31*3))
            let dateAvailableString = dateFormatter.string(from: threeMonthsAgo)
            paramsDict["recursive"] = true
            paramsDict["f_min_date_available"] = dateAvailableString

        case pwgSmartAlbum.favorites.rawValue:
            method = pwgUsersFavoritesGetList
            
        case Int32.min...pwgSmartAlbum.tagged.rawValue:
            method = pwgTagsGetImages
            paramsDict["tag_id"] = pwgSmartAlbum.tagged.rawValue - albumId
            paramsDict["order"] = "rank asc, id desc"

        default:    // Standard Piwigo album
            paramsDict["cat_id"] = albumId
        }
        
        // Launch the HTTP(S) request
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: method, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: CategoriesGetImagesJSON.self,
                                countOfBytesClientExpectsToReceive: NSURLSessionTransferSizeUnknown) { jsonData in
            // Decode the JSON object and import it into Core Data.
            DispatchQueue.global(qos: .background).async { [self] in
                do {
                    // Initialisation
                    var totalCount = Int64.zero
                    
                    // Decode the JSON into codable type CategoriesGetImagesJSON.
                    let decoder = JSONDecoder()
                    let imageJSON = try decoder.decode(CategoriesGetImagesJSON.self, from: jsonData)
                    
                    // Piwigo error?
                    if imageJSON.errorCode != 0 {
                        let error = PwgSession.shared.localizedError(for: imageJSON.errorCode,
                                                                     errorMessage: imageJSON.errorMessage)
                        completion(Set(), totalCount, error)
                        return
                    }
                    
                    // Import the imageJSON into Core Data.
                    try self.importImages(imageJSON.data, inAlbum: albumId)
                    
                    // Retrieve total number of images
                    if albumId == pwgSmartAlbum.favorites.rawValue {
                        totalCount = imageJSON.paging?.count ?? Int64.zero
                    } else {
                        totalCount = imageJSON.paging?.totalCount?.int64Value ?? Int64.zero
                    }
                    
                    // Retrieve IDs of fetched images
                    let fetchedImageIds = Set(imageJSON.data.compactMap({$0.id}))
                    completion(fetchedImageIds, totalCount, nil)
                    
                } catch {
                    // Alert the user if data cannot be digested.
                    completion(Set(), Int64.zero, error as NSError)
                }
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            completion(Set(), Int64.zero, error)
        }
    }
    
    /**
     Retrieves the complete image feed from the remote Piwigo server, and imports it into Core Data.
     */
    public func getInfos(forID imageId: Int64, inCategoryId albumId: Int32,
                         completion: @escaping () -> Void,
                         failure: @escaping (NSError) -> Void) {
        // Prepare parameters for retrieving image/video infos
        let paramsDict: [String : Any] = ["image_id" : imageId]
        
        // Launch request
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgImagesGetInfo, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: ImagesGetInfoJSON.self,
                                countOfBytesClientExpectsToReceive: 50000) { jsonData in
            // Decode the JSON object and store image data in cache.
            do {
                // Decode the JSON into codable type ImagesGetInfoJSON.
                let decoder = JSONDecoder()
                let imageJSON = try decoder.decode(ImagesGetInfoJSON.self, from: jsonData)

                // Piwigo error?
                if imageJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: imageJSON.errorCode,
                                                                    errorMessage: imageJSON.errorMessage)
                    failure(error as NSError)
                    return
                }

                // Import the imageJSON into Core Data.
                try self.importImages([imageJSON.data], inAlbum: albumId)
                
                completion()
            }
            catch {
                // Data cannot be digested
                let error = error as NSError
                failure(error)
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            failure(error)
        }
    }

    /**
     Imports a JSON dictionary into the Core Data store on a private queue,
     processing the record in batches to avoid a high memory footprint.
     */
    private let batchSize = 256
    private func importImages(_ imageArray: [ImagesGetInfo], inAlbum albumId: Int32) throws {
        // Get current user object (will create server object if needed)
        guard let user = userProvider.getUserAccount(inContext: bckgContext) else {
            fatalError("Unresolved error — Could not get user object!")
        }
        guard let album = user.albums?.first(where: {$0.pwgID == albumId}) else {
            fatalError("Unresolved error — Could not get album object!")
        }
        
        // We shall perform at least one import in case where
        // the user did delete all images
        guard imageArray.isEmpty == false else {
            _ = importOneBatch([ImagesGetInfo](), inAlbum: album, user: user)
            return
        }
        
        // Process records in batches to avoid a high memory footprint.
        let count = imageArray.count
        
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
            let imagesBatch = Array(imageArray[range])
            
            // Stop the entire import if any batch is unsuccessful.
            if !importOneBatch(imagesBatch, inAlbum: album, user: user) {
                return
            }
        }
    }
    
    /**
     Imports one batch of images, creating managed objects from the new data,
     and saving them to the persistent store, on a private queue. After saving,
     resets the context to clean up the cache and lower the memory footprint.
     
     NSManagedObjectContext.performAndWait doesn't rethrow so this function
     catches throws within the closure and uses a return value to indicate
     whether the import is successful.
     */
    private func importOneBatch(_ imagesBatch: [ImagesGetInfo], inAlbum album: Album, user: User) -> Bool {
        var success = false
        
        // taskContext.performAndWait runs on the URLSession's delegate queue
        // so it won’t block the main thread.
        bckgContext.performAndWait {
            
            // Create a fetched results controller and set its fetch request, context, and delegate.
            let imageIds = Set(imagesBatch.compactMap({$0.id}))
            let controller = frcOfImage(inContext: self.bckgContext, withIds: imageIds)
            
            // Perform the fetch.
            do {
                try controller.performFetch()
            } catch {
                fatalError("Unresolved error \(error)")
            }
            let cachedImages:[Image] = controller.fetchedObjects ?? []
            
            // Loop over new images
            for imageData in imagesBatch {
                
                // Check that this image belongs at least to the current album
                var albums = Set(arrayLiteral: album)
                if let albumIds = imageData.categories?.compactMap({$0.id}),
                   let allAlbums = user.server?.albums?.filter({albumIds.contains($0.pwgID)}) {
                    albums.formUnion(allAlbums)
                }

                // Index of this new image in cache
                guard let ID = imageData.id else { continue }
                if let index = cachedImages.firstIndex(where: { $0.pwgID == ID }) {
                    // Update the image's properties using the raw data
                    do {
                        // The current user will be added so that we know which images
                        // are accessible to that user.
                        try cachedImages[index].update(with: imageData, user: user, albums: albums)
                    }
                    catch ImageError.missingData {
                        // Could not perform the update
                        print(ImageError.missingData.localizedDescription)
                    }
                    catch {
                        print(error.localizedDescription)
                    }
                }
                else {
                    // Create an Image managed object on the private queue context.
                    guard let image = NSEntityDescription.insertNewObject(forEntityName: "Image",
                                                                          into: bckgContext) as? Image else {
                        print(ImageError.creationError.localizedDescription)
                        return
                    }
                    
                    // Populate the Image's properties using the raw data.
                    do {
                        try image.update(with: imageData, user: user, albums: albums)
                    }
                    catch ImageError.missingData {
                        // Delete invalid Image from the private queue context.
                        print(ImageError.missingData.localizedDescription)
                        bckgContext.delete(image)
                    }
                    catch {
                        print(error.localizedDescription)
                    }
                }
            }
            
            // Determine images to delete
//            let newImageIds = imagesBatch.compactMap({$0.id})
//            let cachedImagesToDelete = cachedImages.filter({newImageIds.contains($0.id) == false})
//            let cachedImageIdsToDelete = cachedImagesToDelete.compactMap({Int($0.id)})
            
            // Update uploaded images if needed
            
            // Delete images
//            cachedImagesToDelete.forEach { cachedImage in
//                print("••> delete image with ID:\(cachedImage.id) and name:\(cachedImage.title)")
//                bckgContext.delete(cachedImage)
//            }
            
            // Save all insertions from the context to the store.
            if bckgContext.hasChanges {
                do {
                    try bckgContext.save()
//                    if Thread.isMainThread == false {
//                        DispatchQueue.main.async {
//                            DataController.shared.saveMainContext()
//                        }
//                    }
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
    
    
    // MARK: - Clear Images
    /**
        Purge cache from orphaned images
     */
    public func purgeOrphans() {
        
        // Retrieve images in persistent store
        let fetchRequest = Image.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Image.pwgID), ascending: true)]
        
        // Select images of the current server not belonging to an album
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "server.path == %@", NetworkVars.serverPath))
        andPredicates.append(NSPredicate(format: "ANY users.username == %@", NetworkVars.username))
        andPredicates.append(NSPredicate(format: "albums.@count == 0"))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)

        // Delete associated files in the background
        bckgContext.performAndWait {
            
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
            let cachedImagesToDdelete:[Image] = controller.fetchedObjects ?? []
            if cachedImagesToDdelete.count == 0 {
                print("••> No need to purge cache from orphaned images.")
                return
            }
            
            // Delete cached image files
            for image in cachedImagesToDdelete {
                bckgContext.delete(image)
            }
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
//
//        // Create batch delete request
//        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)
//
//        // Execute batch delete request
//        try? bckgContext.executeAndMergeChanges(using: batchDeleteRequest)
    }
    

    /**
     Clear cached Core Data image entry
    */
    public func clearAll() {
        
        // Retrieve images in persistent store
        let fetchRequest = Image.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Image.pwgID), ascending: true)]
        
        // Select images of the current server
        fetchRequest.predicate = NSPredicate(format: "server.path == %@", NetworkVars.serverPath)

        // Create batch delete request
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)

        // Execute batch delete request
        try? bckgContext.executeAndMergeChanges(using: batchDeleteRequest)
    }
}
