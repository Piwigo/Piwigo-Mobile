//
//  AlbumProvider.swift
//  PwgCacheKit
//
//  Created by Eddy Lelièvre-Berna on 10/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import PwgKit

public final class AlbumProvider {
        
    public init() {}    // To make this class public

    // MARK: - Fetch Request
    fileprivate func fetchRequestOfAlbum(withID pwgID: Int32,
                                         ofUser username: String = ServerVars.shared.username,
                                         onServerAtPath serverPath: String = ServerVars.shared.serverPath) -> NSFetchRequest<Album> {
        // Create a fetch request sorted by ID
        let fetchRequest = Album.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.pwgID), ascending: true)]
        
        // Select album:
        /// — from the current server which is accessible to the current user
        /// — whose ID is the ID of the displayed album
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "user.server.path == %@", serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", username))
        andPredicates.append(NSPredicate(format: "pwgID == %i", pwgID))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.shouldRefreshRefetchedObjects = true
        fetchRequest.fetchLimit = 1
        return fetchRequest
    }
    
    
    // MARK: - Create/Get Album of Current User
    /// Returns the requested album of the current user if it exists in the persistent store.
    /// Unlike getOrCreateAlbum(withID:name:inContext:),
    /// this method never creates smart albums and never saves the context,
    /// so it can be called while a snapshot is being applied to a diffable data source
    /// without triggering a nested apply.
    public func getAlbum(withID pwgID: Int32,
                         inContext taskContext: NSManagedObjectContext) -> Album? {
        // Synchronous execution
        return taskContext.performAndWait { () -> Album? in
            let fetchRequest = fetchRequestOfAlbum(withID: pwgID)
            return try? taskContext.fetch(fetchRequest).first
        }
    }
    
    public func getProperties(ofAlbumWithID pwgID: Int32,
                              inContext taskContext: NSManagedObjectContext) -> AlbumProperties? {
        // Synchronous execution
        return getAlbum(withID: pwgID, inContext: taskContext)?.getProperties()
    }
    
    public func getOrCreateAlbum(withID pwgID: Int32, name: String = "",
                                 inContext taskContext: NSManagedObjectContext) throws(PwgKitError) -> Album {
        // Do {} below is used to allow typed throws
        do {
            // Synchronous execution
            return try taskContext.performAndWait { () -> Album in
                // Create a fetch request for the Album entity
                let fetchRequest = fetchRequestOfAlbum(withID: pwgID)
                
                // Return the album if is exists
                let album = try taskContext.fetch(fetchRequest).first
                if let album { return album }
                
                // Create a smart Album on the current queue context if needed
                if pwgID <= 0 {     // We should not create standard albums manually
                    let newAlbum = Album(context: taskContext)
                    do {
                        let smartAlbum = CategoryGetInfo(withId: pwgID, albumName: name)
                        let user = try UserProvider().getCurrentUser(inContext: taskContext)
                        let userURIstr = user.objectID.uriRepresentation().absoluteString
                        try newAlbum.update(with: smartAlbum, userURIstr: userURIstr)
                    }
                    catch {
                        taskContext.delete(newAlbum)
                        throw error
                    }
                    taskContext.saveIfNeeded()
                    return newAlbum
                }
                
                // The album does not exist!
                // Will select the default album or root album
                throw PwgKitError.albumNotFound
            }
        }
        catch let error as PwgKitError { throw error }
        catch let error as NSError { throw PwgKitError.CoreDataError(innerError: error)}
        catch { throw PwgKitError.otherError(innerError: error) }
    }
    
    public func getOrCreateProperties(ofAlbumWithID pwgID: Int32, name: String = "",
                                      inContext taskContext: NSManagedObjectContext) throws(PwgKitError) -> AlbumProperties {
        return try getOrCreateAlbum(withID: pwgID, name: name, inContext: taskContext).getProperties()
    }

    
    // MARK: - Get Album of Other User
    /// Returns the requested album of the current user if it exists in the persistent store.
    public func getAlbum(withID pwgID: Int32, ofUserWithURI userURIstr: String,
                         inContext taskContext: NSManagedObjectContext) -> Album? {
        // Synchronous execution
        return taskContext.performAndWait { () -> Album? in
            guard let userData = try? UserProvider().getUser(withURIstr: userURIstr, inContext: taskContext),
                  let serverPath = userData.server?.path
            else { return nil }
            
            let fetchRequest = fetchRequestOfAlbum(withID: pwgID, ofUser: userData.username, onServerAtPath: serverPath)
            return try? taskContext.fetch(fetchRequest).first
        }
    }
    
    public func getProperties(ofAlbumWithID pwgID: Int32, ofUserWithURI userURIstr: String,
                              inContext taskContext: NSManagedObjectContext) -> AlbumProperties? {
        // Synchronous execution
        return getAlbum(withID: pwgID, ofUserWithURI: userURIstr,inContext: taskContext)?.getProperties()
    }
    
    
    // MARK: - Import Album Data
    /**
     Imports a JSON dictionary into the Core Data store on a private queue,
     processing the record in batches to avoid a high memory footprint.
     */
    private let batchSize = 256
    /// Returns the properties of the current user as stored at the end of the import:
    /// each batch updates the album IDs in which the user may upload images,
    /// so a snapshot taken before the import is stale (and must not be written back).
    @discardableResult
    public func importAlbums(_ albumArray: [CategoryGetInfo], recursively: Bool = false,
                             inParent parentId: Int32) async throws(PwgKitError) -> UserProperties {
        // We keep album UUIDs of albums to delete
        // Initialised and then updated at each iteration
        var albumToDeleteUUIDs: Set<String>? = nil

        // We shall perform at least one import in case where
        // the user did delete all albums
        guard albumArray.isEmpty == false else {
            let (_, userProperties) = try await importOneBatch([CategoryGetInfo](), recursively: recursively,
                                                               inParent: parentId, albumUUIDs: albumToDeleteUUIDs)
            return userProperties
        }
        
        // Process records in batches to avoid a high memory footprint.
        let count = albumArray.count
        
        // Determine the total number of batches.
        var numBatches = count / batchSize
        numBatches += count % batchSize > 0 ? 1 : 0
        
        // Loop over the batches
        var importedUserProperties: UserProperties? = nil
        for batchNumber in 0 ..< numBatches {
            
            // Determine the range for this batch.
            let batchStart = batchNumber * batchSize
            let batchEnd = batchStart + min(batchSize, count - batchNumber * batchSize)
            let range = batchStart..<batchEnd
            
            // Create a batch for this range from the decoded JSON.
            let albumsBatch = Array(albumArray[range])
            
            // Stop the entire import if any batch is unsuccessful.
            let (albumUUIDs, userProperties) = try await importOneBatch(albumsBatch, recursively: recursively,
                                                                        inParent: parentId, albumUUIDs: albumToDeleteUUIDs)
            albumToDeleteUUIDs = albumUUIDs
            importedUserProperties = userProperties
        }
        
        // The last batch holds the rights of every album imported above
        guard let importedUserProperties
        else { throw PwgKitError.userNotFound }
        return importedUserProperties
    }
    
    /**
     Imports one batch of albums, creating managed objects from the new data,
     and saving them to the persistent store, on a private queue. After saving,
     resets the context to clean up the cache and lower the memory footprint.
     
     This function catches throws within the closure and uses a return value
     to indicate whether the import is successful.
     */
    private func importOneBatch(_ albumsBatch: [CategoryGetInfo], recursively: Bool = false,
                                inParent parentId: Int32, albumUUIDs: Set<String>?) async throws(PwgKitError) -> (Set<String>, UserProperties) {
        // For remembering which albums to delete
        var albumToDeleteUUIDs = Set<String>()
        
        // The import is the only writer of the album IDs in which the user may upload.
        // Its properties are collected once saved, so that views
        // adopt them instead of a snapshot taken before this import.
        var importedUserProperties: UserProperties? = nil
        
        // Get background context
        let bckgContext = DataController.shared.newTaskContext()
        
        // Copied locally so that the closure below does not capture self
        let batchSize = self.batchSize
        
        // The asynchronous variant of perform() suspends this task instead of
        // blocking the thread it runs on. performAndWait() would park a thread of
        // the cooperative pool for the whole import, starving the other tasks and
        // actors (e.g. the ImageDownloader would not serve any thumbnail).
        do {
            try await bckgContext.perform { () throws -> Void in
                
                // Retrieve albums in persistent store
                let fetchRequest = Album.fetchRequest()
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.globalRank), ascending: true)]
                
                // Retrieve albums:
                /// — from the current server
                /// — whose ID is the ID of the parent album because pwg.categories.getList also returns the parent album
                /// — whose parent ID is the ID of the parent album
                /// — whose ID is positive i.e. not a smart album
                var andPredicates = [NSPredicate]()
                andPredicates.append(NSPredicate(format: "user.server.path == %@", ServerVars.shared.serverPath))
                andPredicates.append(NSPredicate(format: "user.username == %@", ServerVars.shared.username))
                if recursively {
                    andPredicates.append(NSPredicate(format: "pwgID >= 0"))
                } else {
                    var orSubpredicates = [NSPredicate]()
                    orSubpredicates.append(NSPredicate(format: "pwgID == %i", parentId))
                    orSubpredicates.append(NSPredicate(format: "parentId == %i", parentId))
                    andPredicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: orSubpredicates))
                }
                fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
                fetchRequest.returnsObjectsAsFaults = false
                fetchRequest.shouldRefreshRefetchedObjects = true
                
                // Perform the fetch.
                let cachedAlbums:[Album] = try bckgContext.fetch(fetchRequest)
                
                // Initialise set of album UUIDs during the first iteration
                if albumUUIDs == nil {
                    // Store UUIDs of present list of albums, except root which must not be deleted
                    albumToDeleteUUIDs = Set(cachedAlbums.filter({$0.pwgID != 0}).map({$0.uuid}))
                } else {
                    // Resume UUIDs of albums to delete
                    albumToDeleteUUIDs = albumUUIDs ?? Set<String>()
                }
                
                // Get current user object (should exist at this stage)
                let user = try UserProvider().getCurrentUser(inContext: bckgContext)
                let userURIstr = user.objectID.uriRepresentation().absoluteString

                // Loop over fetched albums
                for albumData in albumsBatch {
                    
                    // Index of this new album in cache
                    guard let ID = albumData.id else { continue }
                    if let index = cachedAlbums.firstIndex(where: { $0.pwgID == ID }) {
                        // Update the album's properties using the raw data
                        // The current user will be added so that we know which albums
                        // are accessible to that user.
                        try cachedAlbums[index].update(with: albumData, userURIstr: userURIstr)
                        
                        // IDs of albums to which the user has upload access
                        // are stored in the uploadRights attribute.
                        if albumData.hasUploadRights {
                            user.addUploadRightsToAlbum(withID: ID)
                        } else {
                            user.removeUploadRightsToAlbum(withID: ID)
                        }
                        
                        // Do not delete this album during the last iteration of the import
                        albumToDeleteUUIDs.remove(cachedAlbums[index].uuid)
                    }
                    else {
                        // Create an Album managed object on the private queue context.
                        let album = Album(context: bckgContext)
                        
                        // Populate the Album's properties using the raw data.
                        do {
                            try album.update(with: albumData, userURIstr: userURIstr)
                            if albumData.hasUploadRights {
                                user.addUploadRightsToAlbum(withID: ID)
                            } else {
                                user.removeUploadRightsToAlbum(withID: ID)
                            }
                        }
                        catch {
                            // Delete invalid Album from the private queue context.
                            bckgContext.delete(album)
                            throw error
                        }
                    }
                }
                
                // Delete albums if this is the last iteration
                if albumsBatch.count < batchSize,
                   albumToDeleteUUIDs.isEmpty == false {
                    // Select albums not returned by the fetch, i.e. albums deleted on the server
                    let albumsToDelete = cachedAlbums.filter({albumToDeleteUUIDs.contains($0.uuid)})
                    
                    // Check whether the auto-upload destination album was deleted on the server
                    if cachedAlbums.first(where: { $0.pwgID == UploadVars.shared.autoUploadCategoryId }) == nil,
                       albumsToDelete.first(where: { $0.pwgID == UploadVars.shared.autoUploadCategoryId }) != nil {
                        NotificationCenter.default.post(name: .pwgDisableAutoUpload, object: nil)
                    }
                    
                    // Delete from the cache albums deleted on the server
                    albumsToDelete.forEach { album in
                        debugPrint("••> delete album with ID:\(album.pwgID), name:\(album.name), UUID:\(album.uuid)")
                        bckgContext.delete(album)
                    }
                }
                
                // Save all insertions from the context to the store.
                bckgContext.saveIfNeeded()

                // Collect the user's rights as stored, i.e. after the save and
                // before reset() turns the User instance into a fault.
                importedUserProperties = user.getProperties()

                // Reset the taskContext to free the cache and lower the memory footprint.
                bckgContext.reset()
                
                // Save cached data in the main thread
                Task { @MainActor in
                    DataController.shared.mainContext.saveIfNeeded()
                }
            }
        }
        catch let error as PwgKitError { throw error }
        catch let error as NSError { throw PwgKitError.CoreDataError(innerError: error)}
        catch let error { throw PwgKitError.otherError(innerError: error) }

        guard let importedUserProperties
        else { throw PwgKitError.userNotFound }
        return (albumToDeleteUUIDs, importedUserProperties)
    }
    
    
    // MARK: - Update Albums
    public func updateAlbum(withProperties properties: AlbumProperties,
                            inContext taskContext: NSManagedObjectContext) throws(PwgKitError) {
        // Do {} below is used to allow typed throws
        do {
            // Synchronous execution
            return try taskContext.performAndWait {
                // Retrieve Album instance
                guard let albumURI = URL(string: properties.URIstr),
                      let albumID = taskContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: albumURI),
                      let album = try taskContext.existingObject(with: albumID) as? Album
                else { throw PwgKitError.albumNotFound }
                                
                // Update properties
                try album.update(with: properties)
                taskContext.saveIfNeeded()
            }
        }
        catch let error as PwgKitError { throw error }
        catch let error as NSError { throw PwgKitError.CoreDataError(innerError: error)}
        catch let error { throw PwgKitError.otherError(innerError: error) }
    }
    
    
    // MARK: - Images Related Utilities
    /**
     Add/substract the number of moved images to
     - the attribute 'nbImages' of the album.
     - the attribute 'totalNbImages' of the album and its parent albums.
     N.B.: Parent albums are updated in the background.
     */
    public func updateAlbums(addingImages nbImages: Int64, toAlbumWithID pwgID: Int32,
                             belongingToUser userURIstr: String,
                             inContext taskContext: NSManagedObjectContext) throws(PwgKitError) {
        // Do {} below is used to allow typed throws
        do {
            // Synchronous execution
            try taskContext.performAndWait { () -> Void in
                // Retrieve album instance
                guard let album = getAlbum(withID: pwgID, ofUserWithURI: userURIstr, inContext: taskContext)
                else { throw PwgKitError.albumNotFound }
                
                // Update album instance
                try self.updateAlbums(addingImages: nbImages, toAlbum: album, inContext: taskContext)
            }
        }
        catch let error as PwgKitError { throw error }
        catch { throw PwgKitError.otherError(innerError: error) }
    }
    
    public func updateAlbums(addingImages nbImages: Int64, toAlbum album: Album,
                             inContext taskContext: NSManagedObjectContext) throws {
        // Add images from album
        album.nbImages += nbImages
        if album.totalNbImages < (Int64.max - nbImages) {   // Avoids possible crash with e.g. smart albums
            album.totalNbImages += nbImages
        }
        
        // Keep 'date_last' set as expected by the server
        album.dateLast = max(Date.timeIntervalSinceReferenceDate, album.dateLast)
        
        // Update parent albums in the background
        try self.updateParents(ofAlbum: album, nbImages: +(nbImages), inContext: taskContext)
    }
    
    public func updateAlbums(removingImages nbImages: Int64, fromAlbum album: Album,
                             inContext taskContext: NSManagedObjectContext) throws {
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
        try self.updateParents(ofAlbum: album, nbImages: -(nbImages), inContext: taskContext)
    }
    
    private func updateParents(ofAlbum album: Album, nbImages: Int64,
                               inContext taskContext: NSManagedObjectContext) throws {
        // Retrieve parent albums
        let fetchRequest = Album.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.globalRank), ascending: true,
                                                         selector: #selector(NSString.localizedStandardCompare(_:)))]
        // Retrieve all parent albums:
        /// — from the current server
        /// — whose ID is the ID of a parent album
        /// — whose ID is not the one of the root album
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "user.server.path == %@", ServerVars.shared.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", ServerVars.shared.username))
        let parentIDs = album.upperIds.components(separatedBy: ",").compactMap({Int32($0)})
            .filter({ [0, album.pwgID].contains($0) == false })
        andPredicates.append(NSPredicate(format: "pwgID IN %@", parentIDs))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.shouldRefreshRefetchedObjects = true
        
        // Update parent albums
        let parentAlbums = try taskContext.fetch(fetchRequest)
        parentAlbums.forEach { parentAlbum in
            // Update number of images
            parentAlbum.totalNbImages += nbImages
        }
    }
    
    
    // MARK: - Clear Album Data
    /**
     Return number of albums stored in cache
     */
    public func getObjectCount(inContext taskContext: NSManagedObjectContext) -> Int64 {
        
        // Create a fetch request for the Album entity
        let fetchRequest = NSFetchRequest<NSNumber>(entityName: "Album")
        fetchRequest.resultType = .countResultType
        
        // Select albums of the current server and user only
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "user.server.path == %@", ServerVars.shared.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", ServerVars.shared.username))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        
        // Fetch number of objects
        do {
            let countResult = try taskContext.fetch(fetchRequest)
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
        
        // Select albums of the current server and user only
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "user.server.path == %@", ServerVars.shared.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", ServerVars.shared.username))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        fetchRequest.returnsObjectsAsFaults = true
        fetchRequest.shouldRefreshRefetchedObjects = true

        // Create batch delete request
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<any NSFetchRequestResult>)
        
        // Execute batch delete request
        let bckgContext = DataController.shared.newTaskContext()
        try? bckgContext.executeAndMergeChanges(using: batchDeleteRequest)
    }
}
