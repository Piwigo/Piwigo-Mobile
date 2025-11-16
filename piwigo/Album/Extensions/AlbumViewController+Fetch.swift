//
//  AlbumViewController+Fetch.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit
import uploadKit

extension AlbumViewController
{
    // MARK: - Fetch Album Data in the Background
    @MainActor
    func fetchAlbumsAndImages(completion: @escaping () -> Void) {
        // Remember query and which images belong to the album
        // from main context before calling background tasks
        /// - takes 662 ms for 2500 photos on iPhone 14 Pro with derivatives inside Image instances
        /// - takes 51 ms for 2584 photos on iPhone 14 Pro with derivatives in Sizes instances
//        var oldImageIDs = Set<Int64>()
//            let snapshot = self.diffableDataSource.snapshot() as Snaphot
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

        // Use the AlbumProvider to create the album data. On completion,
        // handle general UI updates and error alerts on the main queue.
        DispatchQueue.global(qos: .userInteractive).async { [self] in
            // Fetch albums and images
            if categoryId < 0 {
                // The number of images is unknown when a smart album is created.
                // Use the ImageProvider to fetch image data. On completion,
                // handle general UI updates and error alerts on the main queue.
                self.fetchImages(withInitialImageIds: oldImageIDs, query: query,
                                 fromPage: 0, toPage: 0) {
                    completion()
                }
            } else {
                self.fetchAlbums(withInitialImageIds: oldImageIDs, query: query) {
                    completion()
                }
            }
        }
    }
    
    private func fetchAlbums(withInitialImageIds oldImageIDs: Set<Int64>, query: String,
                             completion: @escaping () -> Void) {
        // Use the AlbumProvider to fetch album data. On completion,
        // handle general UI updates and error alerts on the main queue.
        let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
        albumProvider.fetchAlbums(forUser: user, inParentWithId: categoryId,
                                  thumbnailSize: thumnailSize) { [self] error in
            guard let error = error else {
                // No error ► Fetch image data?
                let nbImages = self.albumData.nbImages
                if self.categoryId == 0 || nbImages == 0 {
                    // Done fetching images
                    // ► Remove current album from list of album being fetched
                    AlbumVars.shared.isFetchingAlbumData.remove(self.categoryId)

                    // ► Check if the album has been deleted
                    if self.albumData.isDeleted {
                        DispatchQueue.main.async { [self] in
                            navigationController?.hideHUD { [self] in
                                navigationController?.popViewController(animated: true)
                            }
                        }
                        return
                    }
                    // ► Remove non-fetched images from album
                    self.removeImageWithIDs(oldImageIDs)
                    completion()
                    return
                }
                
                // Use the ImageProvider to fetch image data. On completion,
                // handle general UI updates and error alerts on the main queue.
                let (quotient, remainder) = nbImages.quotientAndRemainder(dividingBy: Int64(self.perPage))
                let lastPage = Int(quotient) + Int(remainder > 0 ? 1 : 0)
                self.fetchImages(withInitialImageIds: oldImageIDs, query: query,
                                 fromPage: 0, toPage: lastPage - 1,
                                 completion: completion)
                return
            }
            
            // Show the error
            DispatchQueue.main.async { [self] in
                // Done fetching album data
                // ► Remove current album from list of albums being fetched
                AlbumVars.shared.isFetchingAlbumData.remove(self.categoryId)

                completion()
                self.showError(error)
            }
        }
    }
    

    // MARK: - Fetch Image Data in the Background
    func fetchImages(withInitialImageIds oldImageIDs: Set<Int64>, query: String,
                     fromPage onPage: Int, toPage lastPage: Int,
                     completion: @escaping () -> Void) {
        // Use the ImageProvider to fetch image data. On completion,
        // handle general UI updates and error alerts on the main queue.
        imageProvider.fetchImages(ofAlbumWithId: albumData.pwgID, withQuery: query, sort: sortOption,
                                  fromPage: onPage, perPage: perPage) { [self] fetchedImageIds, totalCount, hasDownloadRight in
            // Store user's right to download
            user.downloadRights = hasDownloadRight
            
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
            }
            
            // Will not remove fetched images from album image list
            let imageIDs = oldImageIDs.subtracting(fetchedImageIds)
            
            // Should we continue?
            if onPage < newLastPage, query == albumData.query {
                // Pursue fetch without HUD
                DispatchQueue.main.async { [self] in
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
                // Load next page of images
                self.fetchImages(withInitialImageIds: imageIDs, query: query,
                                 fromPage: onPage + 1, toPage: newLastPage,
                                 completion: completion)
                return
            }
            
            // Done fetching images
            // ► Remove current album from list of album being fetched
            AlbumVars.shared.isFetchingAlbumData.remove(self.categoryId)
            // ► Remove non-fetched images from album
            removeImageWithIDs(imageIDs)
            // ► Delete orphaned images in the background
            imageProvider.purgeOrphans()

            completion()
            return
        }
        failure: { error in
            DispatchQueue.main.async { [self] in
                // Done fetching images
                // ► Remove current album from list of album being fetched
                AlbumVars.shared.isFetchingAlbumData.remove(self.categoryId)
                
                completion()
                self.showError(error)
            }
        }
    }
    
    private func removeImageWithIDs(_ imageIDs: Set<Int64>) {
        // Done fetching images ► Remove non-fetched images from album
        DispatchQueue.main.async { [self] in
            // Remember when images were fetched
            self.albumData.dateGetImages = Date().timeIntervalSinceReferenceDate
            // Update titleView
            self.setTitleViewFromAlbumData()
            
            // Remove images if necessary
            if let images = self.albumData.images {
                if imageIDs.isEmpty == false {
                    let toRemove = images.filter({ imageIDs.contains($0.pwgID) })
                    self.albumData.removeFromImages(toRemove)
                    self.deselectImages(withIDs: imageIDs)
                    self.mainContext.saveIfNeeded()
                } else if self.albumData.nbImages == Int64.zero,
                          images.isEmpty == false {
                    self.albumData.removeFromImages(images)
                    self.mainContext.saveIfNeeded()
                }
            }
        }
        
        // Delete upload requests of images deleted from the Piwigo server
        UploadManager.shared.backgroundQueue.async {
            UploadManager.shared.deleteUploadsOfDeletedImages(withIDs: Array(imageIDs))
        }
    }
    

    // MARK: - Error Management
    @MainActor
    private func showError(_ error: PwgKitError)
    {
        var title = NSLocalizedString("internetErrorGeneral_title", comment: "Connection Error")
        var detail = error.localizedDescription
        var buttonSelector = #selector(hideLoading)
        if error.requestCancelled {
            title = NSLocalizedString("internetCancelledConnection_title", comment: "Connection Cancelled")
        }
        else if error.failedAuthentication {
            title = NSLocalizedString("loginError_title", comment: "Login Fail")
            buttonSelector = #selector(hideLoadingAndCloseSession)
        }
        else if error.incompatibleVersion {
            title = NSLocalizedString("serverVersionNotCompatible_title", comment: "Server Incompatible")
            detail = String.localizedStringWithFormat(PwgKitError.incompatiblePwgVersion.localizedDescription, NetworkVars.shared.pwgVersion, NetworkVars.shared.pwgMinVersion)
            buttonSelector = #selector(hideLoadingAndCloseSession)
        }
        else if detail.isEmpty {
            detail = String(format: "%ld", (error as NSError?)?.code ?? 0)
        }
        navigationController?.showHUD(
            withTitle: title, detail: detail, minWidth: 240,
            buttonTitle: NSLocalizedString("alertDismissButton", comment: "Dismiss"),
            buttonTarget: self, buttonSelector: buttonSelector,
            inMode: .text)
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
            // End refreshing if needed
            self.collectionView?.refreshControl?.endRefreshing()
        }
    }
    
    
    // MARK: - Fetch Favorites in the background
    /// The below methods are only called if the Piwigo server version is between 2.10.0 and 13.0.0.
    func loadFavoritesInBckg() {
        // Check that an album of favorites exists in cache (create it if necessary)
        guard let album = self.albumProvider.getAlbum(ofUser: user, withId: pwgSmartAlbum.favorites.rawValue) else {
            // Remove favorite album from list of album being fetched
            AlbumVars.shared.isFetchingAlbumData.remove(pwgSmartAlbum.favorites.rawValue)
            return
        }
        if album.isFault {
            album.willAccessValue(forKey: nil)
            album.didAccessValue(forKey: nil)
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
        self.fetchFavorites(ofAlbum: album, imageIDs: oldImageIDs,
                            fromPage: 0, toPage: lastPage, perPage: perPage)
    }
    
    private func fetchFavorites(ofAlbum album: Album, imageIDs: Set<Int64>,
                                fromPage onPage: Int, toPage lastPage: Int, perPage: Int) {
        // Use the ImageProvider to fetch image data. On completion,
        // handle general UI updates and error alerts on the main queue.
        imageProvider.fetchImages(ofAlbumWithId: album.pwgID, withQuery: "", sort: sortOption,
                                  fromPage: onPage, perPage: perPage) { [self] fetchedImageIds, totalCount, hasDownloadRight in
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
                self.fetchFavorites(ofAlbum: album, imageIDs: newImageIds,
                                    fromPage: onPage + 1, toPage: newLastPage, perPage: perPage)
                return
            }
            
            // Done fetching images
            // ► Remove non-fetched images from album
            let images = imageProvider.getImages(inContext: albumBckgContext, withIds: newImageIds)
            album.removeFromImages(images)
            // ► Remember when favorites were fetched
            album.dateGetImages = Date().timeIntervalSinceReferenceDate
            // ► Remove favorite album from list of album being fetched
            AlbumVars.shared.isFetchingAlbumData.remove(pwgSmartAlbum.favorites.rawValue)
            
            // Save changes
            albumBckgContext.saveIfNeeded()
            DispatchQueue.main.async { [self] in
                self.mainContext.saveIfNeeded()
            }
        } failure: { error in
            // Remove favorite album from list of album being fetched
            AlbumVars.shared.isFetchingAlbumData.remove(pwgSmartAlbum.favorites.rawValue)
        }
    }
}
