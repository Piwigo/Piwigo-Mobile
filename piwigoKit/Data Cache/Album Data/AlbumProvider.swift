//
//  AlbumProvider.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 10/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation

public class AlbumProvider: NSObject {
    
    // MARK: - Singleton
    public static let shared = AlbumProvider()
    
    
    // MARK: - Core Data Object Contexts
    private lazy var mainContext: NSManagedObjectContext = {
        return DataController.shared.mainContext
    }()
    
    public private(set) lazy var bckgContext: NSManagedObjectContext = {
        return DataController.shared.newTaskContext()
    }()
    
    
    // MARK: - Core Data Providers
    private lazy var userProvider: UserProvider = {
        let provider : UserProvider = UserProvider.shared
        return provider
    }()
    
    
    // MARK: - Get/Create Album
    func frcOfAlbum(withId albumId: Int32, forUser user: User) -> NSFetchedResultsController<Album> {
        let fetchRequest = Album.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.pwgID), ascending: true)]
        
        // Select album:
        /// — from the current server which is accessible to the current user
        /// — whose ID is the ID of the displayed album
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.shared.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", user.username))
        andPredicates.append(NSPredicate(format: "pwgID == %i", albumId))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        fetchRequest.fetchLimit = 1
        
        // Create a fetched results controller and set its fetch request and context.
        let album = NSFetchedResultsController(fetchRequest: fetchRequest,
                                               managedObjectContext: user.managedObjectContext ?? bckgContext,
                                               sectionNameKeyPath: nil, cacheName: nil)
        return album
    }
    
    public func getAlbum(ofUser user: User? = nil, withId albumId: Int32, name: String = "") -> Album? {
        // Initialisation
        var taskUser: User
        var currentAlbum: Album?
        var taskContext: NSManagedObjectContext
        if let user = user, let context = user.managedObjectContext {
            taskUser = user
            taskContext = context
        } else if let user = userProvider.getUserAccount(inContext: bckgContext) {
            taskUser = user
            taskContext = bckgContext
        } else {
            return nil
        }
        
        // Does this album exist?
        taskContext.performAndWait {
            
            // Create a fetched results controller and set its fetch request and context.
            let controller = frcOfAlbum(withId: albumId, forUser: taskUser)
            
            // Perform the fetch.
            do {
                try controller.performFetch()
            } catch {
                debugPrint("••> getAlbum() unresolved error: \(error.localizedDescription)")
                return
            }
            
            // Did we find an Album instance?
            if let cachedAlbum: Album = (controller.fetchedObjects ?? []).first {
                currentAlbum = cachedAlbum
            }
            else if albumId <= 0 {     // We should not create standard albums manually
                // Get current User object (will create Server object if needed)
                guard let album = NSEntityDescription.insertNewObject(forEntityName: "Album",
                                                                      into: taskContext) as? Album else {
                    debugPrint(PwgKitError.albumCreationError.localizedDescription)
                    return
                }
                
                // Populate the Album's properties using the default data.
                do {
                    let smartAlbum = CategoryData(withId: albumId, albumName: name)
                    try album.update(with: smartAlbum, userObjectID: taskUser.objectID)
                    currentAlbum = album
                }
                catch {
                    debugPrint(error.localizedDescription)
                    taskContext.delete(album)
                }
                
                // Save all insertions from the context to the store.
                taskContext.saveIfNeeded()
                if Thread.isMainThread == false {
                    DispatchQueue.main.async {
                        self.mainContext.saveIfNeeded()
                    }
                }
            } else {
                // This album does not exist!
                // Will select the default album or root album
            }
        }
        
        return currentAlbum
    }
    
    
    // MARK: - Fetch Album Data
    /**
     Fetches the album feed from the remote Piwigo server, and imports it into Core Data.
     */
    public func fetchAlbums(forUser user: User, inParentWithId parentId: Int32, recursively: Bool = false,
                            thumbnailSize: pwgImageSize, completion: @escaping (PwgKitError?) -> Void) {
        // Smart album requested?
        if parentId < 0 { fatalError("••> Cannot fetch data of smart album!") }
        debugPrint("••> Fetch albums in parent with ID: \(parentId)")
        
        // Prepare parameters for collecting recursively album data
        let paramsDict: [String : Any] = [
            "cat_id"            : parentId,
            "recursive"         : recursively,
            "faked_by_community": NetworkVars.shared.usesCommunityPluginV29 ? "false" : "true",
            "thumbnail_size"    : thumbnailSize.argument
        ]
        
        // Launch the HTTP(S) request
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgCategoriesGetList, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: CategoriesGetListJSON.self,
                                countOfBytesClientExpectsToReceive: NSURLSessionTransferSizeUnknown) { result in
            switch result {
            case .success(let pwgData):
                // Piwigo error?
                if pwgData.errorCode != 0 {
                    completion(PwgKitError.pwgError(code: pwgData.errorCode, msg: pwgData.errorMessage))
                    return
                }
                
                // Import album data into Core Data.
                do {
                    // Update albums if Community installed (not needed for admins)
                    if user.hasAdminRights == false,
                       NetworkVars.shared.usesCommunityPluginV29 {
                        // Non-admin user and Community installed —> collect Community albums
                        self.fetchCommunityAlbums(inParentWithId: parentId, recursively: recursively,
                                                  albums: pwgData.data, completion: completion)
                        return
                    }
                    
                    // Import the albumJSON into Core Data.
                    try self.importAlbums(pwgData.data, recursively: recursively, inParent: parentId)
                    completion(nil)
                }
                catch let error as DecodingError {
                    completion(.decodingFailed(innerError: error))
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
    
    private func fetchCommunityAlbums(inParentWithId parentId: Int32, recursively: Bool = false,
                                      albums: [CategoryData], completion: @escaping (PwgKitError?) -> Void) {
        debugPrint("••> Fetch Community albums in parent with ID: \(parentId)")
        // Prepare parameters
        let paramsDict: [String : Any] = ["cat_id"    : parentId,
                                          "recursive" : recursively]
        
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kCommunityCategoriesGetList, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: CommunityCategoriesGetListJSON.self,
                                countOfBytesClientExpectsToReceive: NSURLSessionTransferSizeUnknown) { result in
            switch result {
            case .success(let pwgData):
                // Import Community albums into Core Data.
                do {
                    // No Community albums?
                    if pwgData.data.isEmpty == true {
                        try self.importAlbums(albums, recursively: recursively, inParent: parentId)
                        completion(nil)
                        return
                    }
                    
                    // Update album list
                    var combinedAlbums = albums
                    for comAlbum in pwgData.data {
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
                        completion(nil)
                    }
                    catch let error as DecodingError {
                        completion(.decodingFailed(innerError: error))
                    }
                    catch {
                        completion(.otherError(innerError: error))
                    }
                }
                
            case .failure:
                /// - Network communication errors
                /// - Returned JSON data is empty
                /// - Cannot decode data returned by Piwigo server
                do {
                    try self.importAlbums(albums, recursively: recursively, inParent: parentId)
                    completion(nil)
                }
                catch let error as DecodingError {
                    completion(.decodingFailed(innerError: error))
                }
                catch {
                    completion(.otherError(innerError: error))
                }
            }
        }
    }
    
    /**
     Imports a JSON dictionary into the Core Data store on a private queue,
     processing the record in batches to avoid a high memory footprint.
     */
    private let batchSize = 256
    public func importAlbums(_ albumArray: [CategoryData], recursively: Bool = false,
                             inParent parentId: Int32) throws {
        // We keep album IDs of albums to delete
        // Initialised and then updated at each iteration
        var albumToDeleteIDs: Set<Int32>? = nil
        
        // We shall perform at least one import in case where
        // the user did delete all albums
        guard albumArray.isEmpty == false else {
            _ = importOneBatch([CategoryData](), recursively: recursively,
                               inParent: parentId, albumIDs: albumToDeleteIDs)
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
            let (success, albumIDs) = importOneBatch(albumsBatch, recursively: recursively,
                                                     inParent: parentId, albumIDs: albumToDeleteIDs)
            if success ==  false { return }
            albumToDeleteIDs = albumIDs
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
                                inParent parentId: Int32, albumIDs: Set<Int32>?) -> (Bool, Set<Int32>) {
        var success = false
        var albumToDeleteIDs = Set<Int32>()
        
        // Get current user object (will create server and user objects if needed)
        guard let user = userProvider.getUserAccount(inContext: bckgContext) else {
            debugPrint("AlbumProvider.importOneBatch() unresolved error: Could not get user object!")
            return (success, albumToDeleteIDs)
        }
        if user.isFault {
            // user is not fired yet.
            user.willAccessValue(forKey: nil)
            user.didAccessValue(forKey: nil)
        }
        
        // Runs on the URLSession's delegate queue
        // so it won’t block the main thread.
        bckgContext.performAndWait {
            
            // Retrieve albums in persistent store
            let fetchRequest = Album.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.globalRank), ascending: true)]
            
            // Retrieve albums:
            /// — from the current server
            /// — whose ID is the ID of the parent album because pwg.categories.getList also returns the parent album
            /// — whose parent ID is the ID of the parent album
            /// — whose ID is positive i.e. not a smart album
            var andPredicates = [NSPredicate]()
            andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.shared.serverPath))
            andPredicates.append(NSPredicate(format: "user.username == %@", user.username))
            if recursively {
                andPredicates.append(NSPredicate(format: "pwgID >= 0"))
            } else {
                var orSubpredicates = [NSPredicate]()
                orSubpredicates.append(NSPredicate(format: "pwgID == %i", parentId))
                orSubpredicates.append(NSPredicate(format: "parentId == %i", parentId))
                andPredicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: orSubpredicates))
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
            let cachedAlbums:[Album] = controller.fetchedObjects ?? []
            
            // Initialise set of album IDs during the first iteration
            if albumIDs == nil {
                // Store IDs of present list of albums, except root which must not be deleted
                albumToDeleteIDs = Set(cachedAlbums.filter({$0.pwgID != 0}).map({$0.pwgID}))
            } else {
                // Resume IDs of albums to delete
                albumToDeleteIDs = albumIDs ?? Set<Int32>()
            }
            
            // Loop over new albums
            for albumData in albumsBatch {
                
                // Index of this new album in cache
                guard let ID = albumData.id else { continue }
                if let index = cachedAlbums.firstIndex(where: { $0.pwgID == ID }) {
                    // Update the album's properties using the raw data
                    do {
                        // The current user will be added so that we know which albums
                        // are accessible to that user.
                        try cachedAlbums[index].update(with: albumData, userObjectID: user.objectID)
                        
                        // IDs of albums to which the user has upload access
                        // are stored in the uploadRights attribute.
                        if albumData.hasUploadRights {
                            user.addUploadRightsToAlbum(withID: ID)
                        } else {
                            user.removeUploadRightsToAlbum(withID: ID)
                        }
                        
                        // Do not delete this album during the last iteration of the import
                        albumToDeleteIDs.remove(ID)
                    }
                    catch PwgKitError.missingAlbumData {
                        // Could not perform the update
                        debugPrint(PwgKitError.missingAlbumData.localizedDescription)
                    }
                    catch {
                        debugPrint(error.localizedDescription)
                    }
                }
                else {
                    // Create an Album managed object on the private queue context.
                    guard let album = NSEntityDescription.insertNewObject(forEntityName: "Album",
                                                                          into: bckgContext) as? Album else {
                        debugPrint(PwgKitError.albumCreationError.localizedDescription)
                        return
                    }
                    
                    // Populate the Album's properties using the raw data.
                    do {
                        try album.update(with: albumData, userObjectID: user.objectID)
                        if albumData.hasUploadRights {
                            user.addUploadRightsToAlbum(withID: ID)
                        } else {
                            user.removeUploadRightsToAlbum(withID: ID)
                        }
                    }
                    catch PwgKitError.missingAlbumData {
                        // Delete invalid Album from the private queue context.
                        debugPrint(PwgKitError.missingAlbumData.localizedDescription)
                        bckgContext.delete(album)
                    }
                    catch {
                        debugPrint(error.localizedDescription)
                    }
                }
            }
            
            // Delete albums if this is the last iteration
            if albumsBatch.count < batchSize {
                // Albums not returned by the fetch are deleted first
                if albumToDeleteIDs.isEmpty == false {
                    // Check whether the auto-upload category will be deleted
                    if albumToDeleteIDs.contains(UploadVars.shared.autoUploadCategoryId) {
                        NotificationCenter.default.post(name: .pwgDisableAutoUpload, object: nil, userInfo: nil)
                    }
                    
                    // Delete albums not returned by the fetch
                    let albumsToDelete = cachedAlbums.filter({albumToDeleteIDs.contains($0.pwgID)})
                    albumsToDelete.forEach { album in
                        debugPrint("••> delete album with ID:\(album.pwgID) and name:\(album.name)")
                        bckgContext.delete(album)
                    }
                    
                    // Delete duplicate albums, if any
                    let otherAlbums = cachedAlbums.filter({albumToDeleteIDs.contains($0.pwgID) == false})
                    let duplicates = duplicates(inArray: otherAlbums)
                    duplicates.forEach { album in
                        bckgContext.delete(album)
                    }
                } else {
                    // Delete duplicates if any
                    let duplicates = duplicates(inArray: cachedAlbums)
                    duplicates.forEach { album in
                        bckgContext.delete(album)
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
        return (success, albumToDeleteIDs)
    }
    
    private func duplicates(inArray albums: [Album]) -> [Album] {
        var seenID = Set<Int32>(), duplicates = [Album]()
        for album in albums {
            let catID = album.pwgID
            if seenID.contains(catID) {
                duplicates.append(album)
            } else {
                seenID.insert(catID)
            }
        }
        return duplicates
    }
    
    
    // MARK: - Albums Related Utilities
    /**
     Create an album inside a parent album stored in the persistent cache.
     - the album is created with a 'globalRank' corresponding to the top position,
     - the attributes 'nbSubAlbums' of parent albums are incremented,
     - the attributes 'globalRank' of albums in the parent album are updated accordingly.
     N.B.: All parent albums are already in cache because the user created the album from one of them.
     N.B.: Task performed in the background.
     */
    public func addAlbum(_ catID: Int32, withName name: String, comment: String,
                         inAlbumWithObjectID parentObjectID: NSManagedObjectID,
                         forUserWithObjectID userObjectID: NSManagedObjectID) {
        // Job performed in the background
        bckgContext.performAndWait {
            do {
                // Get current user and parent album objects
                // Create an Album managed object on the private queue context.
                guard let user = try bckgContext.existingObject(with: userObjectID) as? User,
                      let parent = try bckgContext.existingObject(with: parentObjectID) as? Album,
                      let album = NSEntityDescription.insertNewObject(forEntityName: "Album",
                                                                      into: bckgContext) as? Album else {
                    debugPrint(PwgKitError.albumCreationError.localizedDescription)
                    return
                }
                
                // Populate the Album's properties using the raw data.
                let upperIDs = parent.pwgID == Int32.zero ? String(catID) : parent.upperIds + "," + String(catID)
                let newCat = CategoryData(withId: catID,
                                          albumName: name, albumComment: comment,
                                          albumRank: parent.globalRank,
                                          parentId: String(parent.pwgID), parentIds: upperIDs,
                                          nberImages: Int64.zero, totalNberImages: Int64.zero)
                do {
                    try album.update(with: newCat, userObjectID: userObjectID)
                    if newCat.hasUploadRights {
                        user.addUploadRightsToAlbum(withID: catID)
                    } else {
                        user.removeUploadRightsToAlbum(withID: catID)
                    }
                    
                    // Update parent and sub-albums albums
                    if parent.pwgID == Int32.zero {
                        // Update ranks of albums and sub-albums in root
                        updateRankOfAlbums(by: +1, inAlbumWithID: Int32.zero, afterRank: parent.globalRank)
                    } else {
                        // Update parent albums and sub-albums
                        updateParents(adding: album)
                    }
                }
                catch PwgKitError.missingAlbumData {
                    // Delete invalid Album from the private queue context.
                    debugPrint(PwgKitError.missingAlbumData.localizedDescription)
                    bckgContext.delete(album)
                }
                catch {
                    debugPrint(error.localizedDescription)
                }
                
                // Save all insertions from the context to the store.
                bckgContext.saveIfNeeded()
                DispatchQueue.main.async {
                    self.mainContext.saveIfNeeded()
                }
                
                // Reset the taskContext to free the cache and lower the memory footprint.
                bckgContext.reset()
            } catch {
                debugPrint(error.localizedDescription)
                return
            }
        }
    }
    
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
        // Retrieve parent albums
        let fetchRequest = Album.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.globalRank), ascending: true,
                                                         selector: #selector(NSString.localizedStandardCompare(_:)))]
        // Retrieve all parent albums:
        /// — from the current server
        /// — whose ID is the ID of a parent album
        /// — whose ID is not the one of the root album
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.shared.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.shared.user))
        let parentIDs = album.upperIds.components(separatedBy: ",").compactMap({Int32($0)})
            .filter({ [0, album.pwgID].contains($0) == false })
        andPredicates.append(NSPredicate(format: "pwgID IN %@", parentIDs))
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
        
        // Update parent albums
        let parentAlbums = controller.fetchedObjects ?? []
        parentAlbums.forEach { parentAlbum in
            // Update number of sub-albums and images
            parentAlbum.nbSubAlbums += Int32(sign) * (album.nbSubAlbums + 1)
            parentAlbum.totalNbImages += Int64(sign) * (album.totalNbImages)
            
            // Update rank of sub-albums
            if parentAlbum.pwgID == album.parentId, parentAlbum.nbSubAlbums > 0 {
                updateRankOfAlbums(by: sign, inAlbumWithID: parentAlbum.pwgID, afterRank: album.globalRank)
            }
        }
        
        // Save modifications
        bckgContext.saveIfNeeded()
        DispatchQueue.main.async {
            self.mainContext.saveIfNeeded()
        }
        
        // Reset the taskContext to free the cache and lower the memory footprint.
        bckgContext.reset()
    }
    
    /**
     The attribute 'globalRank' of albums belonging to a parent album is:
     - incremented when an album is added so that the new album appears at the top.
     - decremented when an album is removed so that the rank is properly set.
     N.B.: Task exectued in the background.
     */
    private func updateRankOfAlbums(by diff: Int, inAlbumWithID albumID: Int32, afterRank rank: String) {
        // Retrieve albums in parent album
        let fetchRequest = Album.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.globalRank), ascending: true,
                                                         selector: #selector(NSString.localizedStandardCompare(_:)))]
        
        // Retrieve sub-albums at first level:
        /// — from the current server
        /// — whose ID is the ID of the deleted album
        /// — whose one of the upper album IDs is the ID of the deleted album
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.shared.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.shared.user))
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
        otherAlbums.forEach { otherAlbum in
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
    
    // N.B.: Task exectued in the background.
    private func updateRankOfSubAlbums(inAlbum album: Album) {
        // Retrieve sub-albums in parent album
        let fetchRequest = Album.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.globalRank), ascending: true)]
        
        // Retrieve all sub-albums to update:
        /// — from the current server
        /// — whose one of the upper album IDs is the ID of the parent album
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.shared.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.shared.user))
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
        subAlbums.forEach { subAlbum in
            let rank = subAlbum.globalRank
            subAlbum.globalRank = rank.replacingCharacters(in: range, with: parentRank)
        }
    }
    
    
    // MARK: - Images Related Utilities
    /**
     Add/substract the number of moved images to
     - the attibute 'nbImages' of the album.
     - the attribute 'totalNbImages' of the album and its parent albums.
     N.B.: Parent albums are updated in the background.
     */
    public func updateAlbums(addingImages nbImages: Int64, toAlbum album: Album) {
        // Add images from album
        album.nbImages += nbImages
        if album.totalNbImages < (Int64.max - nbImages) {   // Avoids possible crash with e.g. smart albums
            album.totalNbImages += nbImages
        }
        
        // Keep 'date_last' set as expected by the server
        album.dateLast = max(Date().timeIntervalSinceReferenceDate, album.dateLast)
        
        // Update parent albums in the background
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            self.updateParents(ofAlbum: album, nbImages: +(nbImages))
        }
    }
    
    public func updateAlbums(removingImages nbImages: Int64, fromAlbum album: Album) {
        // Removes image from album
        album.nbImages -= nbImages
        if album.totalNbImages > (Int64.min + nbImages) {   // Avoids possible crash with e.g. smart albums
            album.totalNbImages -= nbImages
        }
        
        // Keep 'date_last' set as expected by the server
        var dateLast = DateUtilities.unknownDateInterval    // i.e. unknown date
        for keptImage in album.images ?? Set<Image>() {
            if dateLast < keptImage.datePosted {
                dateLast = keptImage.datePosted
            }
        }
        album.dateLast = dateLast
        
        // Reset source album thumbnail if necessary
        if album.nbImages == 0 {
            album.thumbnailId = Int64.zero
            album.thumbnailUrl = nil
        }
        
        // Update parent albums in the background
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            self.updateParents(ofAlbum: album, nbImages: -(nbImages))
        }
    }
    
    // N.B.: Task exectued in the background.
    private func updateParents(ofAlbum album: Album, nbImages: Int64) {
        // Retrieve parent albums
        let fetchRequest = Album.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.globalRank), ascending: true,
                                                         selector: #selector(NSString.localizedStandardCompare(_:)))]
        // Retrieve all parent albums:
        /// — from the current server
        /// — whose ID is the ID of a parent album
        /// — whose ID is not the one of the root album
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.shared.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.shared.user))
        let parentIDs = album.upperIds.components(separatedBy: ",").compactMap({Int32($0)})
            .filter({ [0, album.pwgID].contains($0) == false })
        andPredicates.append(NSPredicate(format: "pwgID IN %@", parentIDs))
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
        
        // Update parent albums
        let parentAlbums = controller.fetchedObjects ?? []
        parentAlbums.forEach { parentAlbum in
            // Update number of images
            parentAlbum.totalNbImages += nbImages
        }
        
        // Save modifications
        bckgContext.saveIfNeeded()
        DispatchQueue.main.async {
            self.mainContext.saveIfNeeded()
        }
        
        // Reset the taskContext to free the cache and lower the memory footprint.
        bckgContext.reset()
    }
    
    
    // MARK: - Clear Album Data
    /**
     Return number of albums stored in cache
     */
    public func getObjectCount() -> Int64 {
        
        // Create a fetch request for the Album entity
        let fetchRequest = NSFetchRequest<NSNumber>(entityName: "Album")
        fetchRequest.resultType = .countResultType
        
        // Select albums of the current server only
        fetchRequest.predicate = NSPredicate(format: "user.server.path == %@", NetworkVars.shared.serverPath)
        
        // Fetch number of objects
        do {
            let countResult = try bckgContext.fetch(fetchRequest)
            return countResult.first!.int64Value
        }
        catch let error {
            debugPrint("••> Album count not fetched \(error)")
        }
        return Int64.zero
    }
    
    /**
     Clear cached Core Data album entry
     */
    public func clearAll() {
        
        // Create a fetch request for the Album entity
        let fetchRequest = Album.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.globalRank), ascending: true)]
        
        // Select albums of the current server only
        fetchRequest.predicate = NSPredicate(format: "user.server.path == %@", NetworkVars.shared.serverPath)
        
        // Create batch delete request
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)
        
        // Execute batch delete request
        try? mainContext.executeAndMergeChanges(using: batchDeleteRequest)
    }
}
