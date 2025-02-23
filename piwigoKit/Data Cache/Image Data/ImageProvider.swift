//
//  ImageProvider.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 12/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation

public class ImageProvider: NSObject {
    
    // MARK: - Singleton
    public static let shared = ImageProvider()
    
    
    // MARK: - Core Data Object Contexts
    private lazy var mainContext: NSManagedObjectContext = {
        return DataController.shared.mainContext
    }()
    
    private lazy var bckgContext: NSManagedObjectContext = {
        return DataController.shared.newTaskContext()
    }()
    
    
    // MARK: - Core Data Providers
    private lazy var albumProvider: AlbumProvider = {
        let provider : AlbumProvider = AlbumProvider.shared
        return provider
    }()
    
    private lazy var userProvider: UserProvider = {
        let provider : UserProvider = UserProvider.shared
        return provider
    }()
    
    private lazy var tagProvider: TagProvider = {
        let provider : TagProvider = TagProvider.shared
        return provider
    }()
    
    
    // MARK: - Get Images
    public func getObjectCount() -> Int64 {

        // Create a fetch request for the Image entity
        let fetchRequest = NSFetchRequest<NSNumber>(entityName: "Image")
        fetchRequest.resultType = .countResultType
        
        // Select images of the current server
        fetchRequest.predicate = NSPredicate(format: "server.path == %@", NetworkVars.serverPath)

        // Fetch number of objects
        do {
            let countResult = try bckgContext.fetch(fetchRequest)
            return countResult.first!.int64Value
        }
        catch let error {
            debugPrint("••> Could not ftech image count, \(error)")
        }
        return Int64.zero
    }

    func frcOfImage(inContext taskContext: NSManagedObjectContext,
                    withIds imageIds: Set<Int64>) -> NSFetchedResultsController<Image> {
        let fetchRequest = Image.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Image.pwgID), ascending: true)]
        
        // Select images:
        /// — of the current server
        /// — having an ID matching one of the given image IDs
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "pwgID IN %@", Array(imageIds)))
        andPredicates.append(NSPredicate(format: "server.path == %@", NetworkVars.serverPath))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)

        // Create a fetched results controller and set its fetch request and context.
        let image = NSFetchedResultsController(fetchRequest: fetchRequest,
                                               managedObjectContext: taskContext,
                                               sectionNameKeyPath: nil, cacheName: nil)
        return image
    }
    
    public func getImages(inContext taskContext: NSManagedObjectContext,
                          withIds imageIds: Set<Int64>) -> Set<Image> {
        
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
        
        return Set(cachedImages)
    }
    
    
    // MARK: - Fetch Images
    /**
     Fetches the image feed from the remote Piwigo server, and imports it into Core Data.
     */
    public func fetchImages(ofAlbumWithId albumId: Int32, withQuery query: String,
                            sort: pwgImageSort, fromPage page:Int, perPage: Int,
                            completion: @escaping (Set<Int64>, Int64, Error?) -> Void) {
        debugPrint("••> Fetch images of album \(albumId) at page \(page)…")
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
            let recentPeriod = CacheVars.shared.recentPeriodList[CacheVars.shared.recentPeriodIndex]
            let maxPeriod = CacheVars.shared.recentPeriodList.last ?? 99
            let nberDays = recentPeriod == 0 ? maxPeriod : recentPeriod
            let daysAgo1 = Date(timeIntervalSinceNow: TimeInterval(-3600 * 24 * nberDays))
            let daysAgo2 = Calendar.current.date(byAdding: .day, value: -nberDays, to: Date()) ?? daysAgo1
            let dateAvailableString = DateUtilities.string(from: daysAgo2.timeIntervalSinceReferenceDate)
            paramsDict["recursive"] = true
            paramsDict["f_min_date_available"] = dateAvailableString
            
        case pwgSmartAlbum.favorites.rawValue:
            method = pwgUsersFavoritesGetList
            
        case Int32.min...pwgSmartAlbum.tagged.rawValue:
            method = pwgTagsGetImages
            paramsDict["tag_id"] = pwgSmartAlbum.tagged.rawValue - albumId
            
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
                    let pwgData = try decoder.decode(CategoriesGetImagesJSON.self, from: jsonData)
                    
                    // Piwigo error?
                    if pwgData.errorCode != 0 {
                        let error = PwgSessionError.otherError(code: pwgData.errorCode, msg: pwgData.errorMessage)
                        completion(Set(), totalCount, error)
                        return
                    }
                    
                    // Import the imageJSON into Core Data.
                    if [.rankAscending, .random].contains(sort) {
                        let startRank = Int64(page * perPage)
                        try self.importImages(pwgData.data, inAlbum: albumId,
                                              sort: sort, fromRank: startRank)
                    } else {
                        try self.importImages(pwgData.data, inAlbum: albumId, sort: sort)
                    }
                    
                    // Retrieve total number of images
                    if albumId == pwgSmartAlbum.favorites.rawValue {
                        totalCount = pwgData.paging?.count ?? Int64.zero
                    } else {
                        // Bug leading to server providing wrong total_count value
                        // Discovered in Piwigo 13.5.0, appeared in 13.0.0, fixed in 13.6.0.
                        // See https://github.com/Piwigo/Piwigo/issues/1871
                        if NetworkVars.pwgVersion.compare("13.0.0", options: .numeric) == .orderedAscending ||
                            NetworkVars.pwgVersion.compare("13.5.0", options: .numeric) == .orderedDescending {
                            totalCount = pwgData.paging?.totalCount?.int64Value ?? Int64.zero
                        } else {
                            totalCount = pwgData.paging?.count ?? Int64.zero
                        }
                    }
                    
                    // Retrieve IDs of fetched images
                    let fetchedImageIds = Set(pwgData.data.compactMap({$0.id}))
                    completion(fetchedImageIds, totalCount, nil)
                    
                } catch {
                    // Alert the user if data cannot be digested.
                    completion(Set(), Int64.zero, error)
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
     Imports uploaded image data into Core Data.
     */
    public func didUploadImage(_ imageData: ImagesGetInfo, asVideo: Bool, inAlbumId albumId: Int32) {
        // Import the image data into Core Data.
        // The provided sort option will not change the rankManual/rankRandom values of Int64.min
        try? self.importImages([imageData], inAlbum: albumId, withAlbumUpdate: true, sort: .albumDefault)
    }

    /**
     Retrieves the complete image feed from the remote Piwigo server, and imports it into Core Data.
     */
    public func getInfos(forID imageId: Int64, inCategoryId albumId: Int32,
                         completion: @escaping () -> Void,
                         failure: @escaping (Error) -> Void) {
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
                let pwgData = try decoder.decode(ImagesGetInfoJSON.self, from: jsonData)
                
                // Piwigo error?
                if pwgData.errorCode != 0 {
                    let error = PwgSessionError.otherError(code: pwgData.errorCode, msg: pwgData.errorMessage)
                    failure(error)
                    return
                }
                
                // Import the imageJSON into Core Data
                // The provided sort option will not change the rankManual/rankRandom values.
                try self.importImages([pwgData.data], inAlbum: albumId, sort: .albumDefault)
                
                completion()
            }
            catch {
                // Data cannot be digested
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
    public var userDidCancelSearch = false
    private let batchSize = 25
    private func importImages(_ imageArray: [ImagesGetInfo],
                              inAlbum albumId: Int32, withAlbumUpdate: Bool = false,
                              sort: pwgImageSort, fromRank rank: Int64 = Int64.min) throws {
        // We shall perform at least one import in case where
        // the user did delete all images
        guard imageArray.isEmpty == false else {
            _ = importOneBatch([ImagesGetInfo](), inAlbum: albumId, sort: sort)
            return
        }
        
        // Process records in batches to avoid a high memory footprint.
        let count = imageArray.count
        
        // Determine the total number of batches.
        var numBatches = count / batchSize
        numBatches += count % batchSize > 0 ? 1 : 0
        
        // Loop over the batches
        for batchNumber in 0 ..< numBatches {
            // Stop importing images if user cancelled the search
            if userDidCancelSearch { break }
            
            // Determine the range for this batch.
            let batchStart = batchNumber * batchSize
            let batchEnd = batchStart + min(batchSize, count - batchNumber * batchSize)
            let range = batchStart..<batchEnd
            
            // Create a batch for this range from the decoded JSON.
            let imagesBatch = Array(imageArray[range])
            
            // Stop the entire import if any batch is unsuccessful.
            let startRank = rank + Int64(batchStart)
            if !importOneBatch(imagesBatch, inAlbum: albumId,
                               withAlbumUpdate: withAlbumUpdate,
                               sort: sort, fromRank: startRank) {
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
    private func importOneBatch(_ imagesBatch: [ImagesGetInfo],
                                inAlbum albumId: Int32, withAlbumUpdate: Bool = false,
                                sort: pwgImageSort, fromRank startRank: Int64 = Int64.min) -> Bool {
        // Initialisation
        var success = false
        
        // Get current user object (will create server and user objects if needed)
        guard let user = userProvider.getUserAccount(inContext: bckgContext) else {
            debugPrint("ImageProvider.importOneBatch() unresolved error: Could not get user object!")
            return false
        }
        if user.isFault {
            // user is not fired yet.
            user.willAccessValue(forKey: nil)
            user.didAccessValue(forKey: nil)
        }
        
        // Get album of selected ID (should exist at this stage)
        guard let album = user.albums?.first(where: {$0.pwgID == albumId}) else {
            debugPrint("ImageProvider.importOneBatch() unresolved error: Could not get album object!")
            return false
        }
        if album.isFault {
            // album is not fired yet.
            album.willAccessValue(forKey: nil)
            album.didAccessValue(forKey: nil)
        }
        
        // Import tags which are not yet in cache
        let imageTags = imagesBatch.compactMap({$0.tags}).reduce([],+)
        let isAdmin = [pwgUserStatus.admin.rawValue, pwgUserStatus.webmaster.rawValue].contains(user.status)
        let _ = tagProvider.importOneBatch(imageTags, asAdmin: isAdmin, tagIDs: Set<Int32>())

        // Get favorite album if possible (will not prevent import)
        let favAlbum = albumProvider.getAlbum(ofUser: user, withId: pwgSmartAlbum.favorites.rawValue)
        
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
            var rank = startRank
            for imageData in imagesBatch {
                
                // Stop importing images if user cancelled the search
                if userDidCancelSearch { break }
                
                // Check that this image belongs at least to the current album
                var albums = Set(arrayLiteral: album)
                if let albumIds = imageData.categories?.compactMap({$0.id}),
                   let allAlbums = user.albums?.filter({albumIds.contains($0.pwgID)}) {
                    albums.formUnion(allAlbums)
                }
                
                // Check whether this image is a favorite
                /// (available since version 13.0.0 of the Piwigo server)
                if let favAlbum = favAlbum, let isFavorite = imageData.isFavorite, isFavorite {
                    albums.insert(favAlbum)
                }
                
                // Rank of image in album
                rank = startRank == Int64.min ? Int64.min : rank + 1
                
                // Index of this new image in cache
                guard let ID = imageData.id else { continue }
                if let index = cachedImages.firstIndex(where: { $0.pwgID == ID }) {
                    // Update the image's properties using the raw data
                    do {
                        // The current user will be added so that we know which images
                        // are accessible to that user.
                        try cachedImages[index].update(with: imageData,
                                                       sort: sort, rank: rank,
                                                       user: user, albums: albums)
                    }
                    catch ImageError.missingData {
                        // Could not perform the update
                        debugPrint(ImageError.missingData.localizedDescription)
                    }
                    catch {
                        debugPrint(error.localizedDescription)
                    }
                }
                else {
                    // Create a Sizes managed object on the private queue context.
                    guard let sizes = NSEntityDescription.insertNewObject(forEntityName: "Sizes",
                                                                          into: bckgContext) as? Sizes else {
                        debugPrint(ImageError.creationError.localizedDescription)
                        return
                    }

                    // Create an Image managed object on the private queue context.
                    guard let image = NSEntityDescription.insertNewObject(forEntityName: "Image",
                                                                          into: bckgContext) as? Image else {
                        debugPrint(ImageError.creationError.localizedDescription)
                        return
                    }
                    
                    // Populate the Image's properties using the raw data.
                    image.sizes = sizes
                    do {
                        try image.update(with: imageData,
                                         sort:sort, rank: rank,
                                         user: user, albums: albums)
                        
                        // Update album data if asked
                        if withAlbumUpdate {
                            // Add image to cached albums
                            albums.forEach { album in
                                self.albumProvider.updateAlbums(addingImages: 1, toAlbum: album)
                            }
                        }
                    }
                    catch ImageError.missingData {
                        // Delete invalid Image from the private queue context.
                        debugPrint(ImageError.missingData.localizedDescription)
                        bckgContext.delete(image)
                    }
                    catch {
                        debugPrint(error.localizedDescription)
                    }
                }
            }
            
            // Save all insertions from the context to the store.
            bckgContext.saveIfNeeded()
            DispatchQueue.main.async {
                self.mainContext.saveIfNeeded()
            }

            // Reset the taskContext to free the cache and lower the memory footprint.
            bckgContext.reset()
            
            success = true
        }
        return success
    }
    
    
    // MARK: - Clear Images
    // Purge cache from orphaned images
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
        
        // Create batch delete request
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)

        // Execute batch delete request
        try? bckgContext.executeAndMergeChanges(using: batchDeleteRequest)
    }
        
    // Clear cached Core Data image entry
    public func clearAll() {
        
        // Retrieve images in persistent store
        let fetchRequest = Image.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Image.pwgID), ascending: true)]
        
        // Select images of the current server
        fetchRequest.predicate = NSPredicate(format: "server.path == %@", NetworkVars.serverPath)

        // Create batch delete request
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)

        // Execute batch delete request
        try? mainContext.executeAndMergeChanges(using: batchDeleteRequest)
    }
}
