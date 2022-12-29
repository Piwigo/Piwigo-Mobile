//
//  AlbumProvider.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 10/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import CoreData

public class AlbumProvider: NSObject {
    
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
    private lazy var userProvider: UserProvider = {
        let provider : UserProvider = UserProvider()
        return provider
    }()
    
    
    // MARK: - Get/Create Album
    func frcOfAlbum(inContext taskContext: NSManagedObjectContext,
                    withId albumId: Int32) -> NSFetchedResultsController<Album> {
        let fetchRequest = Album.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.pwgID), ascending: true)]
        
        // Select album:
        /// — from the current server which is accessible to the current user
        /// — whose ID is the ID of the displayed album
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "server.path == %@", NetworkVars.serverPath))
        andPredicates.append(NSPredicate(format: "ANY users.username == %@", NetworkVars.username))
        andPredicates.append(NSPredicate(format: "pwgID == %i", albumId))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        fetchRequest.fetchBatchSize = 1
        
        // Create a fetched results controller and set its fetch request and context.
        let album = NSFetchedResultsController(fetchRequest: fetchRequest,
                                               managedObjectContext: taskContext,
                                               sectionNameKeyPath: nil, cacheName: nil)
        return album
    }
    
    public func getAlbum(inContext taskContext: NSManagedObjectContext,
                         withId albumId: Int32, name: String = "") -> Album? {
        // Initialisation
        var currentAlbum: Album?
        
        // Does this album exist?
        taskContext.performAndWait {
            
            // Create a fetched results controller and set its fetch request and context.
            let controller = frcOfAlbum(inContext: taskContext, withId: albumId)
            
            // Perform the fetch.
            do {
                try controller.performFetch()
            } catch {
                fatalError("Unresolved error \(error)")
            }
            
            // Did we find an Album instance?
            if let cachedAlbum: Album = controller.fetchedObjects?.first {
                currentAlbum = cachedAlbum
            }
            else if albumId <= 0 {     // We should not create standard albums manually
                // Get current User object (will create Server object if needed)
                guard let user = userProvider.getUserAccount(inContext: taskContext),
                      let album = NSEntityDescription.insertNewObject(forEntityName: "Album",
                                                                      into: taskContext) as? Album else {
                    print(AlbumError.creationError.localizedDescription)
                    return
                }
                
                // Populate the Album's properties using the default data.
                do {
                    let smartAlbum = CategoryData(withId: albumId, albumName: name)
                    try album.update(with: smartAlbum, user: user)
                    currentAlbum = album
                }
                catch {
                    print(error.localizedDescription)
                    taskContext.delete(album)
                }
                
                // Save all insertions from the context to the store.
                do {
                    try taskContext.save()
                    if Thread.isMainThread == false {
                        DispatchQueue.main.async {
                            DataController.shared.saveMainContext()
                        }
                    }
                }
                catch {
                    print("Error: \(error)\nCould not save Core Data context.")
                }
            } else {
                // This album should not exist!
            }
        }
        
        return currentAlbum
    }
    
    //    public func resetSearchAlbum() {
    //        // Does this smart album exist?
    //        bckgContext.performAndWait {
    //
    //            // Create a fetched results controller and set its fetch request and context.
    //            let controller = frcOfAlbum(inContext: bckgContext, withId: pwgSmartAlbum.search.rawValue)
    //
    //            // Perform the fetch.
    //            do {
    //                try controller.performFetch()
    //            } catch {
    //                fatalError("Unresolved error \(error)")
    //            }
    //
    //            // Initialise search album
    //            guard let searchAlbum = controller.fetchedObjects?.first as? Album else {
    //                fatalError("••> No Search album in cache!")
    //            }
    //            searchAlbum.query = ""
    //            searchAlbum.nbImages = Int64.min
    //            searchAlbum.totalNbImages = Int64.min
    //            searchAlbum.images = nil
    //
    //            // Save all modifications from the context to the store.
    //            do {
    //                try bckgContext.save()
    //                DispatchQueue.main.async {
    //                    DataController.shared.saveMainContext()
    //                }
    //            }
    //            catch {
    //                print("Error: \(error)\nCould not save Core Data context.")
    //                return
    //            }
    //        }
    //    }
    
    
    // MARK: - Fetch Album Data
    /**
     Fetches the album feed from the remote Piwigo server, and imports it into Core Data.
     */
    public func fetchAlbums(inParentWithId parentId: Int32, recursively: Bool = false,
                            thumbnailSize: pwgImageSize, completion: @escaping (Error?) -> Void) {
        // Smart album requested?
        if parentId < 0 { fatalError("••> Cannot fetch data of smart album!") }
        print("••> Fetch albums in parent with ID: \(parentId)")
        
        // Prepare parameters for collecting recursively album data
        let paramsDict: [String : Any] = [
            "cat_id"            : parentId,
            "recursive"         : recursively,
            "faked_by_community": NetworkVars.usesCommunityPluginV29 ? "false" : "true",
            "thumbnail_size"    : thumbnailSize.argument
        ]
        
        // Launch the HTTP(S) request
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgCategoriesGetList, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: CategoriesGetListJSON.self,
                                countOfBytesClientExpectsToReceive: NSURLSessionTransferSizeUnknown) { jsonData in
            // Decode the JSON object and import it into Core Data.
            DispatchQueue.global(qos: .background).async {
                do {
                    // Decode the JSON into codable type CategoriesGetListJSON.
                    let decoder = JSONDecoder()
                    let albumJSON = try decoder.decode(CategoriesGetListJSON.self, from: jsonData)
                    
                    // Piwigo error?
                    if albumJSON.errorCode != 0 {
                        let error = PwgSession.shared.localizedError(for: albumJSON.errorCode,
                                                                     errorMessage: albumJSON.errorMessage)
                        completion(error)
                        return
                    }
                    
                    // Update albums if Community installed (not needed for admins)
                    if NetworkVars.hasAdminRights == false,
                       NetworkVars.usesCommunityPluginV29 {
                        // Non-admin user and Community installed —> collect Community albums
                        self.fetchCommunityAlbums(inParentWithId: parentId, recursively: recursively,
                                                  albums: albumJSON.data, completion: completion)
                        return
                    }
                    
                    // Import the albumJSON into Core Data.
                    try self.importAlbums(albumJSON.data, recursively: recursively, inParent: parentId)
                    completion(nil)
                    
                } catch {
                    // Alert the user if data cannot be digested.
                    completion(error as NSError)
                }
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            completion(error)
        }
    }
    
    private func fetchCommunityAlbums(inParentWithId parentId: Int32, recursively: Bool = false,
                                      albums: [CategoryData], completion: @escaping (Error?) -> Void) {
        print("••> Fetch Community albums in parent with ID: \(parentId)")
        // Prepare parameters
        let paramsDict: [String : Any] = ["cat_id"    : parentId,
                                          "recursive" : recursively]
        
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kCommunityCategoriesGetList, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: CommunityCategoriesGetListJSON.self,
                                countOfBytesClientExpectsToReceive: NSURLSessionTransferSizeUnknown) { jsonData in
            // Decode the JSON object and return the Community albums
            do {
                // Decode the JSON into codable type CommunityCategoriesGetListJSON.
                let decoder = JSONDecoder()
                let albumsJSON = try decoder.decode(CommunityCategoriesGetListJSON.self, from: jsonData)
                
                // Piwigo error?
                if albumsJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: albumsJSON.errorCode,
                                                                 errorMessage: albumsJSON.errorMessage)
                    print("••> fetchCommunityAlbums error: \(error as NSError)")
                    try self.importAlbums(albums, inParent: parentId)
                    completion(nil)
                    return
                }
                
                // No Community albums?
                if albumsJSON.data.isEmpty == true {
                    try self.importAlbums(albums, recursively: recursively, inParent: parentId)
                    completion(nil)
                    return
                }
                
                // Update album list
                var combinedAlbums = albums
                for comAlbum in albumsJSON.data {
                    if let index = combinedAlbums.firstIndex(where: { $0.id == comAlbum.id }) {
                        combinedAlbums[index].hasUploadRights = true
                    } else {
                        var newAlbum = comAlbum
                        newAlbum.hasUploadRights = true
                        combinedAlbums.append(newAlbum)
                    }
                }
                try self.importAlbums(combinedAlbums, recursively: recursively, inParent: parentId)
                completion(nil)
            }
            catch {
                // Data cannot be digested
                do {
                    try self.importAlbums(albums, recursively: recursively, inParent: parentId)
                } catch {
                    completion(error as NSError)
                }
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            do {
                try self.importAlbums(albums, recursively: recursively, inParent: parentId)
            } catch {
                completion(error as NSError)
            }
        }
    }
    
    /**
     Imports a JSON dictionary into the Core Data store on a private queue,
     processing the record in batches to avoid a high memory footprint.
     */
    private let batchSize = 256
    public func importAlbums(_ albumArray: [CategoryData], recursively: Bool = false,
                             inParent parentId: Int32, delete: Bool = true) throws {
        // Get current user object (will create server object if needed)
        guard let user = userProvider.getUserAccount(inContext: bckgContext) else {
            fatalError("Unresolved error!")
        }
        
        // We shall perform at least one import in case where
        // the user did delete all albums
        guard albumArray.isEmpty == false else {
            _ = importOneBatch([CategoryData](), recursively: recursively,
                               inParent: parentId, for: user, delete: delete)
            return
        }
        
        // Process records in batches to avoid a high memory footprint.
        let count = albumArray.count
        
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
            let albumsBatch = Array(albumArray[range])
            
            // Stop the entire import if any batch is unsuccessful.
            if !importOneBatch(albumsBatch, recursively: recursively,
                               inParent: parentId, for: user, delete: delete) {
                return
            }
        }
    }
    
    /**
     Imports one batch of albums, creating managed objects from the new data,
     and saving them to the persistent store, on a private queue. After saving,
     resets the context to clean up the cache and lower the memory footprint.
     
     NSManagedObjectContext.performAndWait doesn't rethrow so this function
     catches throws within the closure and uses a return value to indicate
     whether the import is successful.
     */
    private func importOneBatch(_ albumsBatch: [CategoryData], recursively: Bool = false,
                                inParent parentId: Int32, for user: User, delete: Bool) -> Bool {
        var success = false
        
        // taskContext.performAndWait runs on the URLSession's delegate queue
        // so it won’t block the main thread.
        bckgContext.performAndWait {
            
            // Retrieve albums in persistent store
            let fetchRequest = Album.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.globalRank), ascending: true)]
            
            // Retrieve albums:
            /// — from the current server
            /// — whose ID is the ID of the parent album because pwg.categories.getList also returns the parent album
            /// — whose parent ID is the ID of the parent album
            var andPredicates = [NSPredicate]()
            andPredicates.append(NSPredicate(format: "server.path == %@", NetworkVars.serverPath))
            if recursively == false {
                var orSubpredicates = [NSPredicate]()
                orSubpredicates.append(NSPredicate(format: "pwgID == %i", parentId))
                orSubpredicates.append(NSPredicate(format: "parentId == %i", parentId))
                andPredicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: orSubpredicates))
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
            let cachedAlbums:[Album] = controller.fetchedObjects ?? []
            
            // Loop over new albums
            for albumData in albumsBatch {
                
                // Index of this new album in cache
                guard let ID = albumData.id else { continue }
                if let index = cachedAlbums.firstIndex(where: { $0.pwgID == ID }) {
                    // Update the album's properties using the raw data
                    do {
                        // The current user will be added so that we know which albums
                        // are accessible to that user.
                        try cachedAlbums[index].update(with: albumData, user: user)
                        
                        // IDs of albums to which the user has upload access
                        // are stored in the uploadRights attribute.
                        if albumData.hasUploadRights {
                            user.addAlbumWithUploadRights(ID)
                        }
                    }
                    catch AlbumError.missingData {
                        // Could not perform the update
                        print(AlbumError.missingData.localizedDescription)
                    }
                    catch {
                        print(error.localizedDescription)
                    }
                }
                else {
                    // Create an Album managed object on the private queue context.
                    guard let album = NSEntityDescription.insertNewObject(forEntityName: "Album",
                                                                          into: bckgContext) as? Album else {
                        print(AlbumError.creationError.localizedDescription)
                        return
                    }
                    
                    // Populate the Album's properties using the raw data.
                    do {
                        try album.update(with: albumData, user: user)
                        if albumData.hasUploadRights {
                            user.addAlbumWithUploadRights(ID)
                        }
                    }
                    catch AlbumError.missingData {
                        // Delete invalid Album from the private queue context.
                        print(AlbumError.missingData.localizedDescription)
                        bckgContext.delete(album)
                    }
                    catch {
                        print(error.localizedDescription)
                    }
                }
            }
            
            // Determine albums to delete
            if delete, parentId > 0 {   // Smart albums should not be deleted here
                let newAlbumIds = albumsBatch.compactMap({$0.id})
                let cachedAlbumsToDelete = cachedAlbums.filter({newAlbumIds.contains($0.pwgID) == false})
                let cachedAlbumIdsToDelete = cachedAlbumsToDelete.compactMap({$0.pwgID})
                
                // Check whether the auto-upload category will be deleted
                if cachedAlbumIdsToDelete.contains(UploadVars.autoUploadCategoryId) {
                    UploadManager.shared.disableAutoUpload()
                }
                
                // Delete albums
                cachedAlbumsToDelete.forEach { cachedAlbum in
                    print("••> delete album with ID:\(cachedAlbum.pwgID) and name:\(cachedAlbum.name)")
                    bckgContext.delete(cachedAlbum)
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
            
            success = true
        }
        return success
    }
    
    
    // MARK: - Update Albums
    /**
     Create an album inside a parent album stored in the persistent cache.
     - the album is created with a 'globalRank' corresponding to the top position,
     - the attributes 'nbSubAlbums' of parent albums are incremented,
     - the attributes 'globalRank' of albums in the parent album are updated accordingly.
     N.B.: All parent albums are already in cache because the user created the album from one of them.
     N.B.: Task performed in the background.
     */
    public func addAlbum(_ catID: Int32, withName name: String, comment: String,
                         intoAlbumWithId parentID: Int32) {
        // Job performed in the background
        bckgContext.performAndWait {
            
            // Get current user and parent album objects
            // Create an Album managed object on the private queue context.
            guard let user = userProvider.getUserAccount(inContext: bckgContext),
                  let parent = getAlbum(inContext: bckgContext, withId: parentID),
                  let album = NSEntityDescription.insertNewObject(forEntityName: "Album",
                                                                  into: bckgContext) as? Album else {
                print(AlbumError.creationError.localizedDescription)
                return
            }
            
            // Populate the Album's properties using the raw data.
            let upperIDs = parentID == Int32.zero ? String(catID) : parent.upperIds + "," + String(catID)
            let newCat = CategoryData(withId: catID,
                                      albumName: name, albumComment: comment,
                                      albumRank: parent.globalRank,
                                      parentId: String(parentID), parentIds: upperIDs,
                                      nberImages: Int64.zero, totalNberImages: Int64.zero)
            do {
                try album.update(with: newCat, user: user)
                if newCat.hasUploadRights {
                    user.addAlbumWithUploadRights(catID)
                }
                
                // Update parent and sub-albums albums
                if parentID == Int32.zero {
                    // Update ranks of albums and sub-albums in root
                    updateRankOfAlbums(by: +1, inAlbum: Int32.zero,
                                       afterRank: parent.globalRank)
                } else {
                    // Update parent albums and sub-albums
                    updateParents(adding: album)
                }
            }
            catch AlbumError.missingData {
                // Delete invalid Album from the private queue context.
                print(AlbumError.missingData.localizedDescription)
                bckgContext.delete(album)
            }
            catch {
                print(error.localizedDescription)
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
        }
    }
    
    /**
     Move an album with its sub-albums.
     - the attributes 'nbSubAlbums' of parent albums are decremented,
     - the number of moved images is subtracted from the attributes 'totalNbImages' of parent albums,
     - the parent ID of the album is changed,
     - the parents IDs of the album with its sub-albums are changed,
     - the 'globalRank' of the album is set to correspond to the top position,
     - the attributes 'nbSubAlbums' of parent albums are incremented,
     - the attributes 'globalRank' of albums in the parent album are updated accordingly.
     N.B.: All albums are already in cache because the album selector was called before.
     N.B.: Task performed in the background.
     */
    public func moveAlbum(_ catID: Int32, intoAlbumWithId parentID: Int32) {
        // Job performed in the background
        bckgContext.performAndWait {
            
            // Get album to move and new parent album
            guard let albumToMove = getAlbum(inContext: bckgContext, withId: catID),
                  let parent = getAlbum(inContext: bckgContext, withId: parentID) else {
                return
            }
            
            // Update parent and sub-albums albums
            if albumToMove.parentId == Int32.zero {
                // Update ranks of albums and sub-albums in root
                updateRankOfAlbums(by: -1, inAlbum: Int32.zero,
                                   afterRank: albumToMove.globalRank)
            } else {
                // Update parent albums and sub-albums
                updateParents(removing: albumToMove)
            }
            
            // Move album
            let upperIDs = parentID == Int32.zero ? String(catID) : parent.upperIds + "," + String(catID)
            albumToMove.parentId = parentID
            albumToMove.upperIds = upperIDs
            albumToMove.globalRank = parentID == 0 ? "0" : parent.globalRank + ".0"
            
            // Update parent and sub-albums albums
            if parentID == Int32.zero {
                // Update ranks of albums and sub-albums in root
                updateRankOfAlbums(by: +1, inAlbum: Int32.zero,
                                   afterRank: parent.globalRank)
            } else {
                // Update parent albums and sub-albums
                updateParents(adding: albumToMove)
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
        }
    }
    
    
    /**
     Delete an album with its sub-albums.
     - the attributes 'nbSubAlbums' of parent albums are decremented,
     - the number of moved images is subtracted from the attributes 'totalNbImages' of parent albums,
     - the attributes 'globalRank' of albums in the parent album are updated accordingly.
     N.B.: Sub-albums of the album to delete may not be in cache.
     N.B.: Task performed in the background.
     */
    public func deleteAlbum(_ catID: Int32, inParent parentID: Int32,
                            inMode mode: pwgAlbumDeletionMode) {
        // Job performed in the background
        bckgContext.performAndWait {
            
            // Retrieve albums in persistent store
            let fetchRequest = Album.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.pwgID), ascending: true)]
            
            // Retrieve albums to delete:
            /// — from the current server
            /// — whose ID is the ID of the album to delete
            /// — whose one of the upper album IDs is the ID of the album to delete
            var andPredicates = [NSPredicate]()
            andPredicates.append(NSPredicate(format: "server.path == %@", NetworkVars.serverPath))
            var orSubpredicates = [NSPredicate]()
            orSubpredicates.append(NSPredicate(format: "pwgID == %i", catID))
            orSubpredicates.append(NSPredicate(format: "parentId == %i", catID))
            let regExp =  NSRegularExpression.escapedPattern(for: String(catID))
            let pattern = String(format: "(^|.*,)%@(,.*|$)", regExp)
            orSubpredicates.append(NSPredicate(format: "upperIds MATCHES %@", pattern))
            andPredicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: orSubpredicates))
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
            let albumsToDelete:[Album] = controller.fetchedObjects ?? []
            
            // Delete images if demanded
            switch mode {
            case .none:     // Keep all images
                break
            case .orphaned: // Delete orphaned image objects (including image files)
                albumsToDelete.forEach { album in
                    if let images = album.images {
                        images.forEach { image in
                            if image.albums?.count == 1 {
                                bckgContext.delete(image)
                            }
                        }
                    }
                }
            case .all:      // Delete all image objects (including image files)
                albumsToDelete.forEach { album in
                    if let images = album.images {
                        images.forEach { image in
                            bckgContext.delete(image)
                        }
                    }
                }
            }
            
            // Update parent and sub-albums albums
            if let albumToDelete = albumsToDelete.first(where: {$0.pwgID == catID}) {
                if parentID == Int32.zero {
                    // Update ranks of albums and sub-albums in root
                    updateRankOfAlbums(by: -1, inAlbum: Int32.zero,
                                       afterRank: albumToDelete.globalRank)
                } else {
                    // Update parent albums and sub-albums
                    updateParents(removing: albumToDelete)
                }
            }
            
            // Delete album and sub-albums
            albumsToDelete.forEach { cachedAlbum in
                print("••> delete album with ID:\(cachedAlbum.pwgID) and name:\(cachedAlbum.name)")
                bckgContext.delete(cachedAlbum)
            }
            
            // Save all modifications from the context to the store.
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
        }
    }
    
    public func updateAlbums(addingImages nbImages: Int64, toAlbum album: Album) {
        // Remove image from album
        album.nbImages += nbImages
        album.totalNbImages += nbImages

        // Keep 'date_last' set as expected by the server
        let tz = NSTimeZone.default as NSTimeZone
        let seconds = -TimeInterval(tz.secondsFromGMT(for: Date()))
        album.dateLast = max(Date(timeInterval: seconds, since: Date()), album.dateLast)

        // Update album and its parent albums in the background
        updateParents(ofAlbum: album, nbImages: +(nbImages))
   }

    public func updateAlbums(removingImages nbImages: Int64, fromAlbum album: Album) {
        // Remove image from album
        album.nbImages -= nbImages
        album.totalNbImages -= nbImages

        // Keep 'date_last' set as expected by the server
        var dateLast = Date(timeIntervalSince1970: 0)
        for keptImage in album.images ?? Set<Image>() {
            if dateLast.compare(keptImage.datePosted) == .orderedAscending {
                dateLast = keptImage.datePosted
            }
        }
        album.dateLast = dateLast
        
        // Reset source album thumbnail if necessary
        if album.nbImages == 0 {
            album.thumbnailId = Int64.zero
            album.thumbnailUrl = nil
        }

        // Update album and its parent albums in the background
        updateParents(ofAlbum: album, nbImages: -(nbImages))
    }
    
    /**
     Clear cached Core Data album entry
     */
    public func clearAll() {
        
        // Create a fetch request for the Album entity
        let fetchRequest = Album.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.globalRank), ascending: true)]
        
        // Select albums of the current server only
        fetchRequest.predicate = NSPredicate(format: "server.path == %@", NetworkVars.serverPath)
        
        // Create batch delete request
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)
        
        // Execute batch delete request
        try? bckgContext.executeAndMergeChanges(using: batchDeleteRequest)
    }
    
    
    // MARK: - Albums Related Utilities
    /**
     The attribute 'nbSubAlbums' of parent albums must be:
     - incremented when an album is added to an album,
     - decremented when an album is removed from an album.
     The attribute 'totalNbImages' of parent albums must be:
     - increased by the number of images contained in added sub-albums,
     - subtracted from the number of images contained in removed sub-albums
     N.B.: Task exectued in the background.
     */
    private func updateParents(adding album: Album) {
        updateParents(of: album, sign: +1)
    }

    private func updateParents(removing album: Album) {
        updateParents(of: album, sign: -1)
    }
    
    private func updateParents(of album: Album, sign: Int) {
        let parentIDs = album.upperIds.components(separatedBy: ",")
            .compactMap({Int32($0)})
        for upperID in parentIDs {
            // Check that it is not the root album, nor the album
            if (upperID == 0) || (upperID == album.pwgID) { continue }
            
            // Get a parent album
            if let upperAlbum = getAlbum(inContext: bckgContext, withId: upperID) {
                // Update number of sub-albums and images
                upperAlbum.nbSubAlbums += Int32(sign) * (album.nbSubAlbums + 1)
                upperAlbum.totalNbImages += Int64(sign) * (album.totalNbImages)

                // Update rank of sub-albums
                if upperID == album.parentId, upperAlbum.nbSubAlbums > 0 {
                    updateRankOfAlbums(by: sign, inAlbum: upperID,
                                       afterRank: album.globalRank)
                }
            }
        }
    }
    
    /**
     The attribute 'globalRank' of albums belonging to a parent album is:
     - incremented when an album is added so that the new album appears at the top.
     - decremented when an album is removed so that the rank is properly set.
     N.B.: Task exectued in the background.
     */
    private func updateRankOfAlbums(by diff: Int, inAlbum albumID: Int32, afterRank rank: String) {
        // Retrieve albums in parent album
        let fetchRequest = Album.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.globalRank), ascending: true,
                                                         selector: #selector(NSString.localizedStandardCompare(_:)))]
        
        // Retrieve sub-albums at first level:
        /// — from the current server
        /// — whose ID is the ID of the deleted album
        /// — whose one of the upper album IDs is the ID of the deleted album
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "server.path == %@", NetworkVars.serverPath))
        andPredicates.append(NSPredicate(format: "parentId == %i", albumID))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        
        // Create a fetched results controller and set its fetch request and context.
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                    managedObjectContext: bckgContext,
                                                    sectionNameKeyPath: nil, cacheName: nil)
        // Perform the fetch.
        do {
            try controller.performFetch()
        } catch {
            fatalError("Unresolved error \(error)")
        }
        
        // Update the rank of all sub-albums
        let minRank = rank.components(separatedBy: ",").compactMap({Int($0)}).last ?? 0
        let otherAlbums = controller.fetchedObjects ?? []
        for otherAlbum in otherAlbums {
            // Update rank of sub-albums at first level
            var rankArray = otherAlbum.globalRank.components(separatedBy: ".").compactMap({Int($0)})
            if var rank = rankArray.last, rank >= minRank {
                rank += diff
                rankArray[rankArray.count - 1] = rank
                otherAlbum.globalRank = String(rankArray.map({"\($0)."}).reduce("", +).dropLast(1))
            }
            
            // Update global rank of sub-albums deeper in hierarchy
            if otherAlbum.nbSubAlbums > 0 {
                updateRankOfSubAlbums(inAlbum: otherAlbum)
            }
        }
    }
    
    private func updateRankOfSubAlbums(inAlbum album: Album) {
        // Retrieve sub-albums in parent album
        let fetchRequest = Album.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.globalRank), ascending: true)]
        
        // Retrieve all sub-albums to update:
        /// — from the current server
        /// — whose one of the upper album IDs is the ID of the parent album
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "server.path == %@", NetworkVars.serverPath))
        let regExp =  NSRegularExpression.escapedPattern(for: String(album.pwgID))
        let pattern = String(format: "(^|.*,)%@(,.*|$)", regExp)
        andPredicates.append(NSPredicate(format: "upperIds MATCHES %@", pattern))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        
        // Create a fetched results controller and set its fetch request and context.
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                    managedObjectContext: bckgContext,
                                                    sectionNameKeyPath: nil, cacheName: nil)
        // Perform the fetch.
        do {
            try controller.performFetch()
        } catch {
            fatalError("Unresolved error \(error)")
        }
        
        // Update the rank of the other albums
        let parentRank = album.globalRank
        let range = parentRank.startIndex..<parentRank.endIndex
        let subAlbums = controller.fetchedObjects ?? []
        for subAlbum in subAlbums {
            let rank = subAlbum.globalRank
            subAlbum.globalRank = rank.replacingCharacters(in: range, with: parentRank)
        }
    }
    
    
    // MARK: - Images Related Utilities
    /**
     Add/substract the number of moved images to
     - the attibute 'nbImages' of the album.
     - the attribute 'totalNbImages' of the album and its parent albums.
     N.B.: Task exectued in the background.
     */
    private func updateParents(ofAlbum album: Album, nbImages: Int64) {
        guard let taskContext = album.managedObjectContext else { return }
        let parentIDs = album.upperIds.components(separatedBy: ",")
            .compactMap({Int32($0)})
        for upperID in parentIDs {
            // Check that it is not the root album nor the selected album
            if (upperID == 0) || (upperID == album.pwgID) { continue }

            // Get a parent album
            if let upperAlbum =  getAlbum(inContext: taskContext, withId: upperID) {
                // Update number of images
                upperAlbum.totalNbImages += nbImages
            }
        }
    }
}
