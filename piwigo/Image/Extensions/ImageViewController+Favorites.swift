//
//  ImageViewController+Favorites.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import PwgKit
import PwgAPIKit
import PwgCacheKit

extension ImageViewController
{
    // MARK: - Favorite Bar Button
    @MainActor
    func getFavoriteBarButton() -> UIBarButtonItem? {
        // pwg.users.favorites… methods available from Piwigo version 2.10 for registered users
        if userData.canManageFavorites() == false {
            return nil
        }
        
        // Is this image a favorite?
        let isFavorite = (imageData?.albums ?? Set<Album>())
            .contains(where: {$0.pwgID == pwgSmartAlbum.favorites.rawValue})
        let button = UIBarButtonItem.favoriteImageButton(isFavorite, target: self)
        button.action = isFavorite ? #selector(removeFromFavorites) : #selector(addToFavorites)
        return button
    }
    

    // MARK: - Add/Remove Image from Favorites
    @MainActor
    @objc func addToFavorites() {
        guard let imageData = imageData else { return }
        // Disable button during action
        favoriteBarButton?.isEnabled = false

        // Send requests to Piwigo server
        Task {
            do throws(PwgKitError) {
                // Check session
                try await LoginUtilities().checkSession(ofUserWithID: userData.URIstr, lastConnected: userData.lastUsed)
                
                // Add image to favorites
                try await JSONManager.shared.addToFavorites(imageWithID: imageData.pwgID)
                
                // Update cache and UI
                await MainActor.run {
                    // Image added to favorites ► Add it to the cached album
                    if let favAlbum = try? AlbumProvider().getOrCreateAlbum(withID: pwgSmartAlbum.favorites.rawValue,
                                                                            inContext: mainContext) {
                        // Add image to favorites album
                        favAlbum.addToImages(imageData)
                        
                        // Add images to album
                        favAlbum.nbImages += 1
                        favAlbum.totalNbImages += 1
                        
                        // Keep 'date_last' set as expected by the server
                        favAlbum.dateLast = max(Date.timeIntervalSinceReferenceDate, favAlbum.dateLast)
                        
                        // Save changes
                        mainContext.saveIfNeeded()
                    }

                    // Set button
                    favoriteBarButton?.setFavoriteImage(for: true)
                    favoriteBarButton?.action = #selector(self.removeFromFavorites)
                    favoriteBarButton?.isEnabled = true

                    // Update thumbnails if needed
                    if let children = presentingViewController?.children {
                        let albumVCs = children.compactMap({$0 as? AlbumViewController}).filter({$0.categoryId != Int32.zero})
                        albumVCs.forEach { albumVC in
                            let visibleCells = albumVC.collectionView?.visibleCells ?? []
                            let imageCells = visibleCells.compactMap({$0 as? ImageCollectionViewCell})
                            if let cell = imageCells.first(where: { $0.imageData.pwgID == imageData.pwgID}) {
                                cell.isFavorite = true
                            }
                        }
                    }
                }
            } catch {
                self.addToFavoritesError(error)
            }
        }
    }
    
    @MainActor
    private func addToFavoritesError(_ error: PwgKitError) {
        // Session logout required?
        if error.requiresLogout {
            ClearCache.closeSessionWithPwgError(from: self, error: error)
            return
        }

        // Report error
        let title = String(localized: "imageFavorites_title", comment: "Favorites")
        let message = String(localized: "imageFavoritesAddError_message", comment: "Failed to add this photo to your favorites.")
        dismissPiwigoError(withTitle: title, message: message, errorMessage: error.localizedDescription) { [self] in
            favoriteBarButton?.isEnabled = true
        }
    }

    @MainActor
    @objc func removeFromFavorites() {
        guard let imageData = imageData else { return }
        // Disable button during action
        favoriteBarButton?.isEnabled = false

        // Send requests to Piwigo server
        Task {
            do throws(PwgKitError) {
                // Check session
                try await LoginUtilities().checkSession(ofUserWithID: userData.URIstr, lastConnected: userData.lastUsed)
                
                // Remove image from favorites
                try await JSONManager.shared.removeFromFavorites(imageWithID: imageData.pwgID)
                
                // Update cache and UI
                await MainActor.run {
                    // Image removed from favorites ► Remove it from the cached album
                    if let favAlbum = try? AlbumProvider().getOrCreateAlbum(withID: pwgSmartAlbum.favorites.rawValue,
                                                                            inContext: mainContext) {
                        // Remove image from favorites album
                        favAlbum.removeFromImages(imageData)
                        
                        // Removes image from album
                        favAlbum.nbImages = max(0, favAlbum.nbImages - 1)
                        favAlbum.totalNbImages = max(0, favAlbum.totalNbImages - 1)
                        
                        // Keep 'date_last' set as expected by the server
                        var dateLast = DateUtilities.unknownDateInterval    // i.e. unknown date
                        for keptImage in favAlbum.images ?? Set<Image>() {
                            if dateLast < keptImage.datePosted {
                                dateLast = keptImage.datePosted
                            }
                        }
                        favAlbum.dateLast = dateLast
                        
                        // Reset source album thumbnail if necessary
                        if favAlbum.nbImages == 0 {
                            favAlbum.thumbnailId = Int64.zero
                            favAlbum.thumbnailUrl = nil
                        }
                        
                        // Save changes
                        mainContext.saveIfNeeded()
                    }
                    
                    // Back to favorites album or set favorite button?
                    if self.categoryId == pwgSmartAlbum.favorites.rawValue {
                        // Return to favorites album
                        navigationController?.dismiss(animated: true)
                    }
                    else {
                        // Update favorite button
                        self.favoriteBarButton?.setFavoriteImage(for: false)
                        self.favoriteBarButton?.action = #selector(self.addToFavorites)
                        self.favoriteBarButton?.isEnabled = true
                    }

                    // Update thumbnails if needed
                    if let children = presentingViewController?.children {
                        let albumVCs = children.compactMap({$0 as? AlbumViewController}).filter({$0.categoryId != Int32.zero})
                        albumVCs.forEach { albumVC in
                            let visibleCells = albumVC.collectionView?.visibleCells ?? []
                            let imageCells = visibleCells.compactMap({$0 as? ImageCollectionViewCell})
                            if let cell = imageCells.first(where: { $0.imageData.pwgID == imageData.pwgID}) {
                                cell.isFavorite = false
                            }
                        }
                    }
                }
            }
            catch {
                self.removeFromFavoritesError(error)
            }
        }
    }
    
    @MainActor
    private func removeFromFavoritesError(_ error: PwgKitError) {
        // Session logout required?
        if error.requiresLogout {
            ClearCache.closeSessionWithPwgError(from: self, error: error)
            return
        }

        // Report error
        let title = String(localized: "imageFavorites_title", comment: "Favorites")
        let message = String(localized: "imageFavoritesRemoveError_message", comment: "Failed to remove this photo from your favorites.")
        self.dismissPiwigoError(withTitle: title, message: message, errorMessage: error.localizedDescription) { [self] in
            self.favoriteBarButton?.isEnabled = true
        }
    }
}
