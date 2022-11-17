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
        andPredicates.append(NSPredicate(format: "pwgID == %ld", albumId))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        fetchRequest.fetchBatchSize = 1

        // Create a fetched results controller and set its fetch request and context.
        let album = NSFetchedResultsController(fetchRequest: fetchRequest,
                                               managedObjectContext: taskContext,
                                               sectionNameKeyPath: nil, cacheName: nil)
        return album
    }
    
//    public func createSmartAlbums() {
//        // Called while creating the discover menu
//        bckgContext.performAndWait {
//
//            // Loop over the smart albums except albums of tagged images
//            for albumId in pwgSmartAlbum.favorites.rawValue...pwgSmartAlbum.search.rawValue {
//
//                // Create a fetched results controller and set its fetch request and context.
//                let controller = frcOfAlbum(inContext: bckgContext, withId: albumId)
//
//                // Perform the fetch.
//                do {
//                    try controller.performFetch()
//                } catch {
//                    fatalError("Unresolved error \(error)")
//                }
//
//                // Did we find an Album instance?
//                let cachedAlbum: [Album] = controller.fetchedObjects ?? []
//                if cachedAlbum.isEmpty {
//                    // Get current User object (will create Server object if needed)
//                    guard let user = userProvider.getUserAccount(inContext: bckgContext),
//                          let album = NSEntityDescription.insertNewObject(forEntityName: "Album",
//                                                                          into: bckgContext) as? Album else {
//                        print(AlbumError.creationError.localizedDescription)
//                        return
//                    }
//
//                    // Populate the Album's properties using the default data.
//                    do {
//                        try album.update(with: CategoryData(withId: Int32(albumId)), user: user)
//                    }
//                    catch {
//                        print(error.localizedDescription)
//                        bckgContext.delete(album)
//                    }
//                }
//            }
//
//            // Save all insertions from the context to the store.
//            if bckgContext.hasChanges {
//                do {
//                    try bckgContext.save()
//                    DispatchQueue.main.async {
//                        DataController.shared.saveMainContext()
//                    }
//                }
//                catch {
//                    print("Error: \(error)\nCould not save Core Data context.")
//                    return
//                }
//            }
//        }
//    }

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
                            thumbnailSize: String, completion: @escaping (Error?) -> Void) {
        // Smart album requested?
        if parentId < 0 { fatalError("••> Cannot fetch data of smart album!") }
        print("••> Fetch albums in parent with ID: \(parentId)")

        // Prepare parameters for collecting recursively album data
        let paramsDict: [String : Any] = [
            "cat_id"            : parentId,
            "recursive"         : recursively,
            "faked_by_community": NetworkVars.usesCommunityPluginV29 ? "false" : "true",
            "thumbnail_size"    : thumbnailSize
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
                orSubpredicates.append(NSPredicate(format: "pwgID == %ld", parentId))
                orSubpredicates.append(NSPredicate(format: "parentId == %ld", parentId))
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
    
    
    // MARK: - Delete Albums
    /**
        Delete album and its sub-albums
     */
    public func deleteAlbum(_ catID: Int32) {
        // Job performed in the background
        bckgContext.performAndWait {
            
            // Retrieve albums in persistent store
            let fetchRequest = Album.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.globalRank), ascending: true)]
            
            // Retrieve albums:
            /// — from the current server
            /// — whose ID is the ID of the deleted album
            /// — whose one of the upper album IDs is the ID of the deleted album
            var andPredicates = [NSPredicate]()
            andPredicates.append(NSPredicate(format: "server.path == %@", NetworkVars.serverPath))
            var orSubpredicates = [NSPredicate]()
            orSubpredicates.append(NSPredicate(format: "pwgID == %ld", catID))
            orSubpredicates.append(NSPredicate(format: "parentId == %ld", catID))
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
            let cachedAlbumsToDdelete:[Album] = controller.fetchedObjects ?? []
            
            // Delete album and sub-albums
            cachedAlbumsToDdelete.forEach { cachedAlbum in
                print("••> delete album with ID:\(cachedAlbum.pwgID) and name:\(cachedAlbum.name)")
                bckgContext.delete(cachedAlbum)
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
     Clear cached Core Data album entry
    */
    public func clearAlbums() {
        
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
}
