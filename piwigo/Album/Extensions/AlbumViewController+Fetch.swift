//
//  AlbumViewController+Fetch.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import PwgKit
import PwgAPIKit
import PwgCacheKit
import PwgUIKit
import PwgUploadKit

extension AlbumViewController
{
    // MARK: - Fetch Album Data in the Background
    @MainActor
    func fetchAlbumsAndImages() async {
        // Remember query and which images belong to the album
        // from main context before calling background tasks
        /// - takes 662 ms for 2500 photos on iPhone 14 Pro with derivatives inside Image instances
        /// - takes 51 ms for 2584 photos on iPhone 14 Pro with derivatives in Sizes instances
//        var oldImageIDs = Set<Int64>()
//            let snapshot = self.diffableDataSource.snapshot() as Snapshot
//            oldImageIDs = Set(snapshot.itemIdentifiers
//                .compactMap({ try? self.mainContext.existingObject(with: $0) as? Image})
//                .compactMap({ $0.pwgID }) )
//            if let _ = snapshot.indexOfSection(pwgAlbumGroup.none.sectionKey) {
//                oldImageIDs.subtract(Set(snapshot.itemIdentifiers(inSection: pwgAlbumGroup.none.sectionKey)
//                    .compactMap({ try? self.mainContext.existingObject(with: $0) as? Image})
//                    .compactMap({ $0.pwgID })) )
//            }
        let oldImageIDs = Set((images.fetchedObjects ?? []).map({$0.pwgID}))
        let query = albumData.query

        // Fetch albums and images
        if categoryId < 0 {
            // The number of images is unknown when a smart album is created.
            // Use the ImageProvider to fetch image data. On completion,
            // handle general UI updates and error alerts on the main queue.
            await self.fetchImages(withInitialImageIds: oldImageIDs, query: query,
                                   fromPage: 0, toPage: 0)
        } else {
            // Fetch the root album recursively after a successful login
            // so that the share extension can present the whole album tree
            if (categoryId == pwgSmartAlbum.root.rawValue) && AlbumVars.shared.fetchAlbumDataRecursively {
                AlbumVars.shared.fetchAlbumDataRecursively = false
                #if DEBUG
                debugPrint("••> Fetching root album data recursively for user \(userData.username)")
                #endif
                await self.fetchAlbums(forUserWithAdminRights: userData.hasAdminRights, recursively: true,
                                       withInitialImageIds: oldImageIDs, query: query)
            } else {
                #if DEBUG
                debugPrint("••> Fetching data of album with ID: \(categoryId) for user \(userData.username)")
                #endif
                await self.fetchAlbums(forUserWithAdminRights: userData.hasAdminRights, recursively: false,
                                       withInitialImageIds: oldImageIDs, query: query)
            }
        }
    }
    
    @concurrent
    private func fetchAlbums(forUserWithAdminRights hasAdminRights: Bool, recursively: Bool,
                             withInitialImageIds oldImageIDs: Set<Int64>, query: String) async {
        // Use the AlbumProvider to fetch album data. On completion,
        // handle general UI updates and error alerts on the main queue.
        let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
        Task {
            do throws(PwgKitError) {
                // Fetch albums
                let pwgData = try await JSONManager.shared.fetchAlbums(forUserWithAdminRights: hasAdminRights,
                                                                       inParentWithId: categoryId,
                                                                       recursively: recursively,
                                                                       thumbnailSize: thumnailSize)
                // Update album data in cache
                /// The import owns the album IDs in which the user may upload photo
                /// Retrieve the properties it returns (see below)
                let importedUserData: UserProperties? = pwgData.isEmpty
                    ? nil
                    : try await albumProvider.importAlbums(pwgData, recursively: recursively, inParent: categoryId)
                
                // Remember when all album data was last refreshed with success
                if recursively {
                    CacheVars.shared.dateOfLastAlbumRefresh = Date.timeIntervalSinceReferenceDate
                }

                // Refresh the list of shared albums
                /// Performed after importing the albums so that the albums the shares refer to
                /// are in cache, and only when fetching the root album because a single request
                /// returns every share of the server.
                if await categoryId == pwgSmartAlbum.root.rawValue {
                    await self.fetchSharedAlbums()
                }
                
                // Fetch image data?
                await MainActor.run { [self] in
                    // Album data fetched, image data may still be missing
                    /// The album remains in the list of albums being fetched until fetchCompleted()

                    // Current album still exist?
                    guard let updatedAlbumData = albumProvider.getProperties(ofAlbumWithID: categoryId, inContext: mainContext)
                    else {  // ► The album has been deleted
                        // ► Remove current album from list of albums being fetched
                        AlbumVars.shared.isFetchingAlbumData.remove(self.categoryId)
                        navigationController?.hideHUD { [self] in
                            navigationController?.popViewController(animated: true)
                        }
                        return
                    }
                    
                    // Update album properties
                    self.albumData = updatedAlbumData
                    
                    // Update the user's upload rights, which the import
                    // did refresh for every album it returned
                    if let importedUserData {
                        self.userData = importedUserData
                    }
                    
                    // Any image data to fetch?
                    if self.categoryId == pwgSmartAlbum.root.rawValue {
                        // ► Update navigtion bar, number of images, etc.
                        Task {
                            await self.fetchCompleted()
                        }
                        return
                    }
                    else if self.albumData.nbImages == 0 {
                        // ► Remove non-fetched images from album
                        self.removeImageWithIDs(oldImageIDs)
                        // ► Update navigtion bar, number of images, etc.
                        Task {
                            await self.fetchCompleted()
                        }
                        return
                    }
                    
                    // Use the ImageProvider to fetch image data. On completion,
                    // handle general UI updates and error alerts on the main queue.
                    let (quotient, remainder) = self.albumData.nbImages.quotientAndRemainder(dividingBy: Int64(self.perPage))
                    let lastPage = Int(quotient) + Int(remainder > 0 ? 1 : 0)
                    Task {
                        await self.fetchImages(withInitialImageIds: oldImageIDs, query: query,
                                               fromPage: 0, toPage: lastPage - 1)
                    }
                }
                
            }
            catch {
                // Show the error
                await MainActor.run { [self] in
                    // Done fetching album data
                    // ► Remove current album from list of albums being fetched
                    AlbumVars.shared.isFetchingAlbumData.remove(self.categoryId)
                    // ► Update navigtion bar, number of images, etc.
                    self.showError(error)
                }
            }
        }
    }
    
    
    // MARK: - Fetch Shared Albums
    /// Retrieves the albums shared with users having no Piwigo account and stores
    /// the share data in the albums of the current user.
    ///
    /// The share data only decorates albums and enables the Share Album command,
    /// so a failure must neither interrupt the album fetch nor be reported to the user.
    private func fetchSharedAlbums() async {
        // Is the ShareAlbum plugin installed on the server?
        /// Users rejected by the plugin during this session are not asked again.
        guard ServerVars.shared.usesShareAlbum,
              AlbumVars.shared.canShareAlbums != false
        else { return }
        
        do throws(PwgKitError) {
            // Fetch the shares of the server and store them in the albums of the current user
            let pwgData = try await JSONManager.shared.getSharedAlbums()
            try await albumProvider.importShares(pwgData)
            AlbumVars.shared.canShareAlbums = true
        }
        catch {
            // The plugin rejects users who are neither administrators
            // nor members of the "sharealbum_powerusers" group.
            if case .pwgError(let code, _) = error, code == kShareAlbumForbiddenError {
                AlbumVars.shared.canShareAlbums = false
            }
            #if DEBUG
            debugPrint("••> Could not fetch shared albums: \(error.localizedDescription)")
            #endif
        }
    }
    
    /// Refreshes the share of the displayed album with sharealbum.getInfo.
    ///
    /// Called each time the album appears because a share can be created, renewed or cancelled
    /// from the web UI at any time, and because the album data restored with a scene knows
    /// nothing about shares — the list fetched by fetchSharedAlbums() only lives for a session.
    ///
    /// This request is also the probe telling whether the plugin accepts this user, so it is
    /// performed even when the album is not shared yet: without it, a restored scene would
    /// propose no Share command until the root album is fetched again.
    @MainActor
    func fetchShareOfAlbum() async {
        // Is the ShareAlbum plugin installed, does it accept this user, and can this album be shared?
        /// Users rejected by the plugin during this session are not asked again.
        guard ServerVars.shared.usesShareAlbum,
              AlbumVars.shared.canShareAlbums != false,
              categoryId > 0,
              albumData.status == .privateStatus
        else { return }
        
        do throws(PwgKitError) {
            // Retrieve the share of this album, nil when it is not shared
            let shareData = try await JSONManager.shared.getShare(ofAlbumWithID: categoryId)
            try albumProvider.updateShare(shareData, ofAlbumWithID: categoryId, inContext: mainContext)
            AlbumVars.shared.canShareAlbums = true
            
            // Propose the commands matching the refreshed state
            if inSelectionMode == false {
                updateBarsInPreviewMode()
            }
        }
        catch {
            // The plugin rejects users who are neither administrators
            // nor members of the "sharealbum_powerusers" group.
            if case .pwgError(let code, _) = error, code == kShareAlbumForbiddenError {
                AlbumVars.shared.canShareAlbums = false
            }
            #if DEBUG
            debugPrint("••> Could not refresh the share of album #\(categoryId): \(error.localizedDescription)")
            #endif
        }
    }
    
    
    // MARK: - Fetch Image Data in the Background
    @concurrent
    func fetchImages(withInitialImageIds oldImageIDs: Set<Int64>, query: String,
                     fromPage onPage: Int, toPage lastPage: Int) async {
        // Use the ImageProvider to fetch image data. On completion,
        // handle general UI updates and error alerts on the main queue.
        Task {
            do throws(PwgKitError) {
                // Fetch images
                let (fetchedImageIds, totalCount, hasDownloadRight) =
                try await fetchImages(ofAlbumWithId: albumData.pwgID, withQuery: query, sort: sortOption,
                                      fromPage: onPage, perPage: perPage)
                
                await MainActor.run { [self] in
                    // Store user's download right
                    /// Only that attribute: the other rights belong to the album import
                    userData.downloadRights = hasDownloadRight
                    try? userProvider.updateDownloadRights(hasDownloadRight, inContext: mainContext)
                    
                    // Smart album?
                    var newLastPage = lastPage
                    if albumData.pwgID < 0, onPage == 0 {
                        // Re-calculate number of pages for some smart albums
                        if [pwgSmartAlbum.visits.rawValue, pwgSmartAlbum.best.rawValue].contains(albumData.pwgID) {
                            // Update smart album data (limited to 'perPage' photos - 15 on webUI)
                            albumData.nbImages = min(totalCount, Int64(perPage))
                            albumData.totalNbImages = albumData.nbImages
                        } else {
                            // Calculate number of pages to fetch
                            newLastPage = Int(totalCount.quotientAndRemainder(dividingBy: Int64(perPage)).quotient)
                            
                            // Update smart album data
                            albumData.nbImages = totalCount
                            albumData.totalNbImages = totalCount
                            
                            // Limit image searches
                            if albumData.pwgID == pwgSmartAlbum.search.rawValue {
                                let maxPages: Int = 5
                                newLastPage = min(newLastPage, maxPages)
                                let maxCount = Int64(maxPages * perPage)
                                albumData.nbImages = min(totalCount, maxCount)
                                albumData.totalNbImages = min(totalCount, maxCount)
                            }
                        }
                        try? albumProvider.updateAlbum(withProperties: albumData, inContext: mainContext)
                    }
                    
                    // Will not remove fetched images from album image list
                    let imageIDs = oldImageIDs.subtracting(fetchedImageIds)
                    
                    // Should we continue?
                    if onPage < newLastPage, query == albumData.query {
                        // Pursue fetch without HUD
                        if navigationController?.isShowingHUD() ?? false {
                            navigationController?.hideHUD { [self] in
                                // Set navigation bar buttons
                                if self.inSelectionMode {
                                    self.updateBarsInSelectMode()
                                } else {
                                    self.updateBarsInPreviewMode()
                                    if newLastPage > 2 {
                                        let progress = Float(onPage + 1) / Float(newLastPage)
                                        self.setTitleViewFromAlbumData(progress: progress)
                                    }
                                }
                                
                                // End refreshing if needed
                                self.collectionView?.refreshControl?.endRefreshing()
                            }
                        } else {
                            if newLastPage > 2 {
                                let progress = Float(onPage + 1) / Float(newLastPage)
                                let userInfo = ["pwgID" : self.albumData.pwgID,
                                                "fetchProgressFraction" : progress]
                                NotificationCenter.default.post(name: Notification.Name.pwgFetchedImages,
                                                                object: nil, userInfo: userInfo)
                            }
                        }
                        
                        // Is user editing the search string?
                        if imageProvider.userDidCancelSearch {
                            // Remove non-fetched images from album
                            removeImageWithIDs(imageIDs)
                            // Store parameters
                            self.oldImageIDs = imageIDs
                            self.onPage = onPage + 1
                            self.lastPage = newLastPage
                            return
                        }
                        
                        Task {
                            // Load next page of images
                            await self.fetchImages(withInitialImageIds: imageIDs, query: query,
                                                   fromPage: onPage + 1, toPage: newLastPage)
                        }
                        return
                    }
                    
                    // Done fetching images
                    // ► Remove non-fetched images from album
                    self.removeImageWithIDs(imageIDs)
                    // ► Delete orphaned images in the background
                    self.imageProvider.purgeOrphans()
                    // ► Update navigation bar, number of images, etc.
                    Task {
                        await self.fetchCompleted()
                    }
                }
            }
            catch {
                await MainActor.run { [self] in
                    // Done fetching images
                    // ► Remove current album from list of album being fetched
                    AlbumVars.shared.isFetchingAlbumData.remove(self.categoryId)
                    // Display error if needed
                    self.showError(error)
                }
            }
        }
    }
    
    private func fetchImages(ofAlbumWithId albumId: Int32, withQuery query: String,
                             sort: pwgImageSort, fromPage page:Int, perPage: Int) async throws(PwgKitError) -> (Set<Int64>, Int64, Bool) {
        #if DEBUG
        debugPrint("••> Fetch images of album \(albumId) at page \(page)…")
        #endif

        // Fetch image data
        let (paging, data) = try await JSONManager.shared.getImages(ofAlbumWithId: albumId, withQuery: query, sort: sort, fromPage: page, perPage: perPage)

        // Import image data into Core Data.
        do {
            if [.rankAscending, .random].contains(sort) {
                let startRank = Int64(page * perPage)
                try await imageProvider.importImages(data, inAlbum: albumId,
                                                     sort: sort, fromRank: startRank)
            } else {
                try await imageProvider.importImages(data, inAlbum: albumId, sort: sort)
            }

            // Retrieve total number of images
            var totalCount = Int64.zero
            if albumId == pwgSmartAlbum.favorites.rawValue {
                totalCount = paging.count
            } else {
                // Bug leading to server providing wrong total_count value
                // Discovered in Piwigo 13.5.0, appeared in 13.0.0, fixed in 13.6.0.
                // See https://github.com/Piwigo/Piwigo/issues/1871
                if ServerVars.shared.pwgVersion.compare("13.0.0", options: .numeric) == .orderedAscending ||
                    ServerVars.shared.pwgVersion.compare("13.5.0", options: .numeric) == .orderedDescending {
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
        catch {
            throw error
        }
    }
    
    private func removeImageWithIDs(_ imageIDs: Set<Int64>) {
        // Done fetching images
        // ► Remove non-fetched images from album
        if let album = albumProvider.getAlbum(withID: self.albumData.pwgID, inContext: mainContext) {
            album.dateGetImages = self.albumData.dateGetImages
            
            // Remove images if necessary
            if imageIDs.isEmpty == false {
                if let toRemove = album.images?.filter({ imageIDs.contains($0.pwgID) }) {
                    album.removeFromImages(toRemove)
                }
                self.deselectImages(withIDs: imageIDs)
            }
            else if self.albumData.nbImages == Int64.zero,
                    let images = album.images, images.isEmpty == false {
                album.removeFromImages(images)
            }
            self.mainContext.saveIfNeeded()
        }
        
        // Update titleView
        self.setTitleViewFromAlbumData()
                
        // Delete upload requests of images deleted from the Piwigo server
        if imageIDs.isEmpty == false {
            Task(priority: .utility) { @UploadManagerActor in
                UploadManager.shared.deleteUploadsOfDeletedImages(withIDs: Array(imageIDs))
            }
        }
    }
    

    // MARK: - Error Management
    @MainActor
    private func showError(_ error: PwgKitError)
    {
        var title = String(localized: "internetErrorGeneral_title", comment: "Connection Error")
        var detail = error.localizedDescription
        var buttonSelector = #selector(hideLoading)
        if error.requestCancelled {
            title = String(localized: "internetCancelledConnection_title", comment: "Connection Cancelled")
        }
        else if error.failedAuthentication {
            title = String(localized: "loginError_title", comment: "Login Fail")
            buttonSelector = #selector(hideLoadingAndCloseSession)
        }
        else if error.incompatibleVersion {
            title = String(localized: "serverVersionNotCompatible_title", comment: "Server Incompatible")
            detail = String.localizedStringWithFormat(PwgKitError.incompatiblePwgVersion.localizedDescription, ServerVars.shared.pwgVersion, pwgMinVersion)
            buttonSelector = #selector(hideLoadingAndCloseSession)
        }
        else if detail.isEmpty {
            detail = String(format: "%ld", (error as NSError?)?.code ?? 0)
        }
        navigationController?.showHUD(
            withTitle: title, detail: detail, minWidth: 240,
            buttonTitle: Localized.dismiss,
            buttonTarget: self, buttonSelector: buttonSelector,
            inMode: pwgHudMode.none)
    }
    
    @objc func hideLoadingAndCloseSession() {
        // Hide HUD
        navigationController?.hideHUD() { [self] in
            // End refreshing if needed
            self.collectionView?.refreshControl?.endRefreshing()
            
            // Return to login view
            ClearCache.closeSession()
        }
    }

    @objc func hideLoading() {
        // Hide HUD
        navigationController?.hideHUD() { [self] in
            // Update title
            self.setTitleViewFromAlbumData()

            // Update number of images in footer
            self.updateNberOfImagesInFooter()

            // Set navigation bar buttons
            if self.inSelectionMode {
                self.updateBarsInSelectMode()
            } else {
                self.updateBarsInPreviewMode()
            }

            // End refreshing if needed
            self.collectionView?.refreshControl?.endRefreshing()
        }
    }
    
    
    // MARK: - Fetch Favorites in the background
    /// The below methods are only called if the Piwigo server version is between 2.10.0 and 13.0.0.
    func loadFavoritesInBckg() async {
        // Check that an album of favorites exists in cache (create it if necessary)
        let bckgContext = DataController.shared.newTaskContext()
        guard let album = try? albumProvider.getOrCreateAlbum(withID: pwgSmartAlbum.favorites.rawValue,
                                                              inContext: bckgContext) else {
            // Remove favorite album from list of album being fetched
            AlbumVars.shared.isFetchingAlbumData.remove(pwgSmartAlbum.favorites.rawValue)
            return
        }

        // Remember which images belong to this album
        // from main context before calling background tasks
        let oldImageIDs = Set(album.images?.map({$0.pwgID}) ?? [])

        // Load favorites data in the background
        // Use the ImageProvider to fetch image data. On completion,
        // handle general UI updates and error alerts on the main queue.
        let albumNbImages = album.nbImages
        let (quotient, remainer) = albumNbImages.quotientAndRemainder(dividingBy: Int64(self.perPage))
        let lastPage = Int(quotient) + Int(remainer) > 0 ? 1 : 0
        await self.fetchFavorites(ofAlbum: album, imageIDs: oldImageIDs,
                                  fromPage: 0, toPage: lastPage, perPage: perPage)
    }
    
    private func fetchFavorites(ofAlbum album: Album, imageIDs: Set<Int64>,
                                fromPage onPage: Int, toPage lastPage: Int, perPage: Int) async {
        // Use the ImageProvider to fetch image data. On completion,
        // handle general UI updates and error alerts on the main queue.
        Task {
            do {
                let (fetchedImageIds, totalCount, _) =
                try await fetchImages(ofAlbumWithId: album.pwgID, withQuery: "", sort: sortOption,
                                      fromPage: onPage, perPage: perPage)
                
                // Re-calculate number of pages
                var newLastPage = lastPage
                newLastPage = Int(totalCount.quotientAndRemainder(dividingBy: Int64(perPage)).quotient)
                
                // Update smart album data
                if album.nbImages != totalCount {
                    album.nbImages = totalCount
                }
                if album.totalNbImages != totalCount {
                    album.totalNbImages = totalCount
                }
                
                // Will not remove fetched images from album image list
                let newImageIds = imageIDs.subtracting(fetchedImageIds)
                
                // Should we continue?
                if onPage < newLastPage {
                    // Load next page of images
                    await self.fetchFavorites(ofAlbum: album, imageIDs: newImageIds,
                                              fromPage: onPage + 1, toPage: newLastPage, perPage: perPage)
                    return
                }
                
                // ► Remove non-fetched images from album
                if let toRemove = album.images?.filter({ newImageIds.contains($0.pwgID) }) {
                    album.removeFromImages(toRemove)
                }
                
                // ► Remember when favorites were fetched
                album.dateGetImages = Date.timeIntervalSinceReferenceDate
                
                // ► Remove favorite album from list of album being fetched
                AlbumVars.shared.isFetchingAlbumData.remove(pwgSmartAlbum.favorites.rawValue)
                
                // Save changes
                album.managedObjectContext?.saveIfNeeded()
                Task { @MainActor in
                    self.mainContext.saveIfNeeded()
                }
            }
            catch {
                // Remove favorite album from list of album being fetched
                AlbumVars.shared.isFetchingAlbumData.remove(pwgSmartAlbum.favorites.rawValue)
            }
        }
    }
}
