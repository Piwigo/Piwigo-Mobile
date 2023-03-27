//
//  AlbumViewController+DataSource.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 29/07/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

extension AlbumViewController
{
    // MARK: Album and Image Data
    func fetchAlbumsAndImages(completion: @escaping () -> Void) {
        // Remember query and which images belong to the album
        // from main context before calling background tasks
        let oldImageIds = Set(albumData.images?.map({$0.pwgID}) ?? [])
        let query = albumData.query

        // Use the AlbumProvider to create the album data. On completion,
        // handle general UI updates and error alerts on the main queue.
        DispatchQueue.global(qos: .userInteractive).async { [self] in
            // Fetch albums and images
            if categoryId < 0 {
                // The number of images is unknown when a smart album is created.
                // Use the ImageProvider to fetch image data. On completion,
                // handle general UI updates and error alerts on the main queue.
                let perPage = AlbumUtilities.numberOfImagesToDownloadPerPage()
                self.fetchImages(withInitialImageIds: oldImageIds, query: query,
                                 fromPage: 0, toPage: 0, perPage: perPage) {
                    completion()
                }
            } else {
                fetchAlbums(withInitialImageIds: oldImageIds, query: query) {
                    completion()
                }
            }
        }
    }
    
    private func fetchAlbums(withInitialImageIds oldImageIds: Set<Int64>, query: String,
                             completion: @escaping () -> Void) {
        // Use the AlbumProvider to fetch album data. On completion,
        // handle general UI updates and error alerts on the main queue.
        let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
        albumProvider.fetchAlbums(inParentWithId: categoryId,
                                  thumbnailSize: thumnailSize) { [self] error in
            guard let error = error else {
                // No error ► Fetch image data?
                let nbImages = self.albumData.nbImages
                if self.categoryId == 0 || nbImages == 0 {
                    // Done fetching images
                    self.removeImageWithIDs(oldImageIds)
                    completion()
                    return
                }
                
                // Use the ImageProvider to fetch image data. On completion,
                // handle general UI updates and error alerts on the main queue.
                let perPage = AlbumUtilities.numberOfImagesToDownloadPerPage()
                let (quotient, remainder) = nbImages.quotientAndRemainder(dividingBy: Int64(perPage))
                let lastPage = Int(quotient) + Int(remainder > 0 ? 1 : 0)
                self.fetchImages(withInitialImageIds: oldImageIds, query: query,
                                 fromPage: 0, toPage: lastPage - 1, perPage: perPage,
                                 completion: completion)
                return
            }
            
            // Show the error
            DispatchQueue.main.async { [self] in
                completion()
                self.showError(error)
            }
        }
    }
    
    func fetchImages(withInitialImageIds oldImageIds: Set<Int64>, query: String,
                     fromPage onPage: Int, toPage lastPage: Int,
                     perPage: Int, completion: @escaping () -> Void) {
        // Use the ImageProvider to fetch image data. On completion,
        // handle general UI updates and error alerts on the main queue.
        imageProvider.fetchImages(ofAlbumWithId: albumData.pwgID, withQuery: query,
                                  sort: AlbumVars.shared.defaultSort,
                                  fromPage: onPage, perPage: perPage) { [self] fetchedImageIds, totalCount, error in
            guard let error = error else {
                // No error ► Smart album?
                var newLastPage = lastPage
                if albumData.pwgID < 0 {
                    // Re-calculate number of pages
                    newLastPage = Int(totalCount.quotientAndRemainder(dividingBy: Int64(perPage)).quotient)

                    // Update smart album data
                    if albumData.nbImages != totalCount {
                        albumData.nbImages = totalCount
                    }
                    if albumData.totalNbImages != totalCount {
                        albumData.totalNbImages = totalCount
                    }
                }
                
                // Will not remove fetched images from album image list
                let imageIds = oldImageIds.subtracting(fetchedImageIds)
                
                // Should we continue?
                if onPage < newLastPage, query == albumData.query {
                    // Pursue fetch without HUD
                    DispatchQueue.main.async { [self] in
                        navigationController?.hidePiwigoHUD { }
                    }
                    // Is user editing the search string?
                    if pauseSearch {
                        // Remove non-fetched images from album
                        removeImageWithIDs(imageIds)
                        // Store parameters
                        self.oldImageIds = imageIds
                        self.onPage = onPage + 1
                        self.lastPage = newLastPage
                        self.perPage = perPage
                        return
                    }
                    // Load next page of images
                    self.fetchImages(withInitialImageIds: imageIds, query: query,
                                     fromPage: onPage + 1, toPage: newLastPage,
                                     perPage: perPage, completion: completion)
                    return
                }
                
                // Done fetching images ► Remove non-fetched images from album
                removeImageWithIDs(imageIds)
                
                // Delete orphaned images in background
                imageProvider.purgeOrphans()

                completion()
                return
            }
            self.showError(error)
        }
    }
    
    private func removeImageWithIDs(_ imageIDs: Set<Int64>) {
        // Done fetching images ► Remove non-fetched images from album
        DispatchQueue.main.async {
            // Remember when images were fetched
            self.albumData.dateGetImages = Date()
            
            // Remove images if necessary
            if let images = self.albumData.images {
                if imageIDs.isEmpty == false {
                    let toRemove = images.filter({ imageIDs.contains($0.pwgID) })
                    self.albumData.removeFromImages(toRemove)
                } else if self.albumData.nbImages == Int64.zero {
                    self.albumData.removeFromImages(images)
                }
            }
            
            try? self.mainContext.save()
        }
        
        // Delete upload requests of images deleted from the Piwigo server
        UploadManager.shared.backgroundQueue.async {
            UploadManager.shared.deleteUploadsOfDeletedImages(withIDs: Array(imageIDs))
        }
    }
    
    func updateNberOfImagesInFooter() {
        // Update number of images in footer
        DispatchQueue.main.async { [self] in
            let indexPath = IndexPath(item: 0, section: 1)
            if let footer = self.imagesCollection?.supplementaryView(forElementKind: UICollectionView.elementKindSectionFooter, at: indexPath) as? NberImagesFooterCollectionReusableView {
                footer.noImagesLabel?.text = getImageCount()
            }
        }
    }
    
    private func showError(_ error: Error?) {
        DispatchQueue.main.async { [unowned self] in
            guard let error = error as? NSError else {
                navigationController?.showPiwigoHUD(
                    withTitle: NSLocalizedString("internetCancelledConnection_title", comment: "Connection Cancelled"),
                    detail: " ",
                    buttonTitle: NSLocalizedString("alertDismissButton", comment: "Dismiss"),
                    buttonTarget: self, buttonSelector: #selector(hideLoading),
                    inMode: .text)
                return
            }
            
            // Returns to login view only when credentials are rejected
            if [NSURLErrorUserAuthenticationRequired, 401, 403].contains(error.code) ||
                NetworkVars.didFailHTTPauthentication {
                // Invalid Piwigo or HTTP credentials
                navigationController?.showPiwigoHUD(
                    withTitle: NSLocalizedString("sessionStatusError_message", comment: "Failed to authenticate…."),
                    detail: error.localizedDescription,
                    buttonTitle: NSLocalizedString("alertDismissButton", comment: "Dismiss"),
                    buttonTarget: self, buttonSelector: #selector(hideLoading),
                    inMode: .text)
            }
            else if let err = error as? JsonError, err == .missingParameter {
                // Hide HUD
                navigationController?.hidePiwigoHUD() {
                    // End refreshing if needed
                    self.imagesCollection?.refreshControl?.endRefreshing()
                }
            }
        }
    }

    @objc func hideLoading() {
        // Hide HUD
        navigationController?.hidePiwigoHUD() {
            // Return to login view
            ClearCache.closeSession {}
        }
    }

    
    // MARK: - Fetch Favorites in the background
    func loadFavoritesInBckg() {
        DispatchQueue.global(qos: .default).async {
            // Should we load favorites?
            if NetworkVars.userStatus == .guest { return }
            if "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric) == .orderedDescending { return }

            // Check that an album of favorites exists in cache (create it if necessary)
            guard let album = self.albumProvider.getAlbum(withId: pwgSmartAlbum.favorites.rawValue) else {
                return
            }

            // Remember which images belong to this album
            // from main context before calling background tasks
            let oldImageIds = Set(album.images?.map({$0.pwgID}) ?? [])

            // Load favorites data in the background
            // Use the ImageProvider to fetch image data. On completion,
            // handle general UI updates and error alerts on the main queue.
            let perPage = AlbumUtilities.numberOfImagesToDownloadPerPage()
            let albumNbImages = album.nbImages
            let (quotient, remainer) = albumNbImages.quotientAndRemainder(dividingBy: Int64(perPage))
            let lastPage = Int(quotient) + Int(remainer) > 0 ? 1 : 0
            self.fetchFavorites(ofAlbum: album, imageIds: oldImageIds,
                                fromPage: 0, toPage: lastPage, perPage: perPage)
        }
    }
    
    private func fetchFavorites(ofAlbum album: Album, imageIds: Set<Int64>,
                                fromPage onPage: Int, toPage lastPage: Int, perPage: Int) {
        // Use the ImageProvider to fetch image data. On completion,
        // handle general UI updates and error alerts on the main queue.
        imageProvider.fetchImages(ofAlbumWithId: album.pwgID, withQuery: "",
                                  sort: .dateCreatedAscending,
                                  fromPage: onPage, perPage: perPage) { [self] fetchedImageIds, totalCount, error in
            // Any error?
            if error != nil {
                return
            }
            
            // No error
            var newLastPage = lastPage
            // Re-calculate number of pages
            newLastPage = Int(totalCount.quotientAndRemainder(dividingBy: Int64(perPage)).quotient)

            // Update smart album data
            if album.nbImages != totalCount {
                album.nbImages = totalCount
            }
            if album.totalNbImages != totalCount {
                album.totalNbImages = totalCount
            }

            // Will not remove fetched images from album image list
            let newImageIds = imageIds.subtracting(fetchedImageIds)
            
            // Should we continue?
            if onPage < newLastPage {
                // Load next page of images
                self.fetchFavorites(ofAlbum: album, imageIds: newImageIds,
                                    fromPage: onPage + 1, toPage: newLastPage, perPage: perPage)
                return
            }
            
            // Done fetching images ► Remove non-fetched images from album
            let images = imageProvider.getImages(inContext: bckgContext, withIds: newImageIds)
            album.removeFromImages(images)
                        
            // Remember when favorites were fetched
            album.dateGetImages = Date()
            
            // Save changes
            do {
                try bckgContext.save()
            } catch let error as NSError {
                print("Could not fetch \(error), \(error.userInfo)")
            }
        }
    }
}
