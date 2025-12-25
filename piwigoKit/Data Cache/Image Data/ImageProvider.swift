//
//  ImageProvider.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 12/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation

public final class ImageProvider {
    
    public init() {}    // To make this class public
    
    // MARK: - Get Images
    public func getObjectCount(inContext taskContext: NSManagedObjectContext) -> Int64 {

        // Create a fetch request for the Image entity
        let fetchRequest = NSFetchRequest<NSNumber>(entityName: "Image")
        fetchRequest.resultType = .countResultType
        
        // Select images of the current server
        fetchRequest.predicate = NSPredicate(format: "server.path == %@", NetworkVars.shared.serverPath)

        // Fetch number of objects
        do {
            let countResult = try taskContext.fetch(fetchRequest)
            return countResult.first!.int64Value
        }
        catch let error {
            debugPrint("••> Could not fetch image count, \(error.localizedDescription)")
        }
        return Int64.zero
    }

    func fetchRequestOfImage(inContext taskContext: NSManagedObjectContext,
                             withIds imageIds: Set<Int64>) -> NSFetchRequest<Image> {
        let fetchRequest = Image.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Image.pwgID), ascending: true)]
        
        // Select images:
        /// — of the current server
        /// — having an ID matching one of the given image IDs
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "pwgID IN %@", Array(imageIds)))
        andPredicates.append(NSPredicate(format: "server.path == %@", NetworkVars.shared.serverPath))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)

        return fetchRequest
    }
    
    public func getImages(inContext taskContext: NSManagedObjectContext,
                          withIds imageIds: Set<Int64>) throws -> Set<Image> {
        
        // Retrieve image objects
        try taskContext.performAndWait {
            
            // Create a fetch request for the Album entity
            let fetchRequest = fetchRequestOfImage(inContext: taskContext, withIds: imageIds)

            // Return the Album entity if possible
            do {
                let images = try taskContext.fetch(fetchRequest)
                return Set(images)
            }
            catch let error as PwgKitError {
                throw error
            }
            catch let error {
                throw PwgKitError.otherError(innerError: error)
            }
        }
    }
    
    
    // MARK: - Fetch Images
    /**
     Fetches the image feed from the remote Piwigo server, and imports it into Core Data.
     */
    public func fetchImages(ofAlbumWithId albumId: Int32, withQuery query: String,
                            sort: pwgImageSort, fromPage page:Int, perPage: Int) async throws(PwgKitError) -> (Set<Int64>, Int64, Bool) {
        debugPrint("••> Fetch images of album \(albumId) at page \(page)…")

        // Fetch image data
        let (paging, data) = try await JSONManager.shared.getImages(ofAlbumWithId: albumId, withQuery: query, sort: sort, fromPage: page, perPage: perPage)

        // Import image data into Core Data.
        do {
            if [.rankAscending, .random].contains(sort) {
                let startRank = Int64(page * perPage)
                try self.importImages(data, inAlbum: albumId,
                                      sort: sort, fromRank: startRank)
            } else {
                try self.importImages(data, inAlbum: albumId, sort: sort)
            }

            // Retrieve total number of images
            var totalCount = Int64.zero
            if albumId == pwgSmartAlbum.favorites.rawValue {
                totalCount = paging.count
            } else {
                // Bug leading to server providing wrong total_count value
                // Discovered in Piwigo 13.5.0, appeared in 13.0.0, fixed in 13.6.0.
                // See https://github.com/Piwigo/Piwigo/issues/1871
                if NetworkVars.shared.pwgVersion.compare("13.0.0", options: .numeric) == .orderedAscending ||
                    NetworkVars.shared.pwgVersion.compare("13.5.0", options: .numeric) == .orderedDescending {
                    totalCount = paging.totalCount?.int64Value ?? Int64.zero
                } else {
                    totalCount = paging.count
                }
            }

            // Retrieve IDs of fetched images
            let fetchedImageIds = Set(data.compactMap({$0.id}))

            // Determine if the user has the right to download images
            var hasDownloadRight = false
            if data.isEmpty == false,
               data.firstIndex(where: { $0.downloadUrl == nil }) == nil {
                hasDownloadRight = true
            }
            return (fetchedImageIds, totalCount, hasDownloadRight)
        }
        catch let error as PwgKitError {
            throw error
        }
        catch {
            throw .otherError(innerError: error)
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
    @concurrent
    public func getInfos(forID imageId: Int64, inCategoryId albumId: Int32) async throws(PwgKitError) {
        // Retrieve image data
        let pwgData = try await JSONManager.shared.getInfos(forID: imageId)

        // Import the imageJSON into Core Data
        do {
            // The provided sort option will not change the rankManual/rankRandom values.
            try self.importImages([pwgData], inAlbum: albumId, sort: .albumDefault)
        }
        catch let error as PwgKitError {
            throw error
        }
        catch {
            throw .otherError(innerError: error)
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
        guard imageArray.isEmpty == false
        else {
            _ = try importOneBatch([ImagesGetInfo](), inAlbum: albumId, sort: sort)
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
            try importOneBatch(imagesBatch, inAlbum: albumId,
                               withAlbumUpdate: withAlbumUpdate,
                               sort: sort, fromRank: startRank)
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
                                sort: pwgImageSort, fromRank startRank: Int64 = Int64.min) throws {
        
        // Get current user object (will create server and user objects if needed)
        let bckgContext = DataController.shared.newTaskContext()
        guard let user = try UserProvider().getUserAccount(inContext: bckgContext)
        else { throw PwgKitError.userCreationError }
        if user.isFault {
            // user is not fired yet.
            user.willAccessValue(forKey: nil)
            user.didAccessValue(forKey: nil)
        }
        
        // Get album of selected ID (should exist at this stage)
        guard let album = user.albums?.first(where: {$0.pwgID == albumId})
        else { throw PwgKitError.albumCreationError }
        if album.isFault {
            // album is not fired yet.
            album.willAccessValue(forKey: nil)
            album.didAccessValue(forKey: nil)
        }
        
        // Import tags which are not yet in cache
        let imageTags = imagesBatch.compactMap({$0.tags}).reduce([],+)
        let isAdmin = [pwgUserStatus.admin.rawValue, pwgUserStatus.webmaster.rawValue].contains(user.status)
        _ = try TagProvider().importOneBatch(imageTags, asAdmin: isAdmin, tagIDs: Set<Int32>())

        // Get favorite album if possible (will not prevent import)
        let favAlbum = try AlbumProvider().getAlbum(ofUser: user, withId: pwgSmartAlbum.favorites.rawValue)
        
        // taskContext.performAndWait runs on the URLSession's delegate queue
        // so it won’t block the main thread.
        try bckgContext.performAndWait {
            
            // Create a fetched results controller and set its fetch request, context, and delegate.
            let imageIds = Set(imagesBatch.compactMap({$0.id}))
            let fetchRequest = fetchRequestOfImage(inContext: bckgContext, withIds: imageIds)
            
            // Loop over new images
            let cachedImages:[Image] = try bckgContext.fetch(fetchRequest)
            var rank = startRank
            for imageData in imagesBatch {
                
                // Stop importing images if user cancelled the search
                if userDidCancelSearch {
                    break
                }
                
                // Check that this image belongs at least to the current album
                var albums: Set<Album> = [album]
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
                    catch let error as PwgKitError {
                        // Could not perform the update
                        throw error
                    }
                    catch let error {
                        throw PwgKitError.otherError(innerError: error)
                    }
                }
                else {
                    // Create a Sizes managed object on the private queue context.
                    let sizes = Sizes(context: bckgContext)
                    
                    // Create an Image managed object on the private queue context.
                    let image = Image(context: bckgContext)
                    
                    // Populate the Image's properties using the raw data.
                    image.sizes = sizes
                    do {
                        try image.update(with: imageData,
                                         sort:sort, rank: rank,
                                         user: user, albums: albums)
                        
                        // Update album data if asked
                        if withAlbumUpdate {
                            // Add image to cached albums
                            try albums.forEach { album in
                                try AlbumProvider().updateAlbums(addingImages: 1, toAlbum: album)
                            }
                        }
                    }
                    catch let error as PwgKitError {
                        // Delete invalid Image from the private queue context.
                        bckgContext.delete(image)
                        throw error
                    }
                    catch {
                        // Delete invalid Image from the private queue context.
                        bckgContext.delete(image)
                        throw PwgKitError.otherError(innerError: error)
                    }
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
    }
    
    
    // MARK: - Clear Images
    // Purge cache from orphaned images
    public func purgeOrphans() {
        
        // Retrieve images in persistent store
        let fetchRequest = Image.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Image.pwgID), ascending: true)]
        
        // Select images of the current server not belonging to an album
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "server.path == %@", NetworkVars.shared.serverPath))
        andPredicates.append(NSPredicate(format: "ANY users.username == %@", NetworkVars.shared.user))
        andPredicates.append(NSPredicate(format: "albums.@count == 0"))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        
        // Create batch delete request
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<any NSFetchRequestResult>)

        // Execute batch delete request
        let bckgContext = DataController.shared.newTaskContext()
        try? bckgContext.executeAndMergeChanges(using: batchDeleteRequest)
    }
        
    // Clear cached Core Data image entry
    public func clearAll() {
        
        // Retrieve images in persistent store
        let fetchRequest = Image.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Image.pwgID), ascending: true)]
        
        // Select images of the current server
        fetchRequest.predicate = NSPredicate(format: "server.path == %@", NetworkVars.shared.serverPath)

        // Create batch delete request
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<any NSFetchRequestResult>)

        // Execute batch delete request
        let bckgContext = DataController.shared.newTaskContext()
        try? bckgContext.executeAndMergeChanges(using: batchDeleteRequest)
    }
}
