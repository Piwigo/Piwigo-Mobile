//
//  ImageViewController+Favorites.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

extension ImageViewController
{
    // MARK: - Favorite Bar Button
    func getFavoriteBarButton() -> UIBarButtonItem? {
        // pwg.users.favorites… methods available from Piwigo version 2.10 for registered users
        let isGuest = NetworkVars.shared.userStatus == .guest
        let versionTooOld = NetworkVars.shared.pwgVersion.compare("2.10.0", options: .numeric) == .orderedAscending
        if isGuest || versionTooOld { return nil }
        
        // Is this image a favorite?
        let isFavorite = (imageData?.albums ?? Set<Album>())
            .contains(where: {$0.pwgID == pwgSmartAlbum.favorites.rawValue})
        let button = UIBarButtonItem.favoriteImageButton(isFavorite, target: self)
        button.action = isFavorite ? #selector(removeFromFavorites) : #selector(addToFavorites)
        return button
    }
    

    // MARK: - Add/Remove Image from Favorites
    @objc func addToFavorites() {
        guard let imageData = imageData else { return }
        // Disable button during action
        favoriteBarButton?.isEnabled = false

        // Send request to Piwigo server
        PwgSession.checkSession(ofUser: user) { [self] in
            ImageUtilities.addToFavorites(imageData) { [self] in
                DispatchQueue.main.async { [self] in
                    // Update Favorite smart album
                    if let favAlbum = albumProvider.getAlbum(ofUser: user, withId: pwgSmartAlbum.favorites.rawValue) {
                        // Add image to favorites album
                        favAlbum.addToImages(imageData)
                        // Update favorites album data
                        self.albumProvider.updateAlbums(addingImages: 1, toAlbum: favAlbum)
                        // Save changes
                        self.mainContext.saveIfNeeded()
                        // Set button
                        favoriteBarButton?.setFavoriteImage(for: true)
                        favoriteBarButton?.action = #selector(self.removeFromFavorites)
                        favoriteBarButton?.isEnabled = true
                    }
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
            } failure: { [self] error in
                self.addToFavoritesError(error)
            }
        } failure: { [self] error in
            self.addToFavoritesError(error)
        }
    }
    
    private func addToFavoritesError(_ error: Error) {
        DispatchQueue.main.async { [self] in
            // Session logout required?
            if let pwgError = error as? PwgSessionError,
               [.invalidCredentials, .incompatiblePwgVersion, .invalidURL, .authenticationFailed].contains(pwgError) {
                ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
                return
            }

            // Report error
            let title = NSLocalizedString("imageFavorites_title", comment: "Favorites")
            let message = NSLocalizedString("imageFavoritesAddError_message", comment: "Failed to add this photo to your favorites.")
            dismissPiwigoError(withTitle: title, message: message, errorMessage: error.localizedDescription) { [self] in
                favoriteBarButton?.isEnabled = true
            }
        }
    }

    @objc func removeFromFavorites() {
        guard let imageData = imageData else { return }
        // Disable button during action
        favoriteBarButton?.isEnabled = false

        // Send request to Piwigo server
        PwgSession.checkSession(ofUser: user) { [self] in
            ImageUtilities.removeFromFavorites(imageData) { [self] in
                DispatchQueue.main.async { [self] in
                    // Update Favorite smart album
                    if let favAlbum = albumProvider.getAlbum(ofUser: user, withId: pwgSmartAlbum.favorites.rawValue) {
                        // Remove image from favorites album
                        favAlbum.removeFromImages(imageData)
                        // Update favorites album data
                        self.albumProvider.updateAlbums(removingImages: 1, fromAlbum: favAlbum)
                        // Save changes
                        self.mainContext.saveIfNeeded()
                        // Back to favorites album or set favorite button?
                        if self.categoryId == pwgSmartAlbum.favorites.rawValue {
                            // Return to favorites album
                            navigationController?.dismiss(animated: true)
                        } else {
                            // Update favorite button
                            self.favoriteBarButton?.setFavoriteImage(for: false)
                            self.favoriteBarButton?.action = #selector(self.addToFavorites)
                            self.favoriteBarButton?.isEnabled = true
                        }
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
            } failure: { [self] error in
                self.removeFromFavoritesError(error)
            }
        } failure: { [self] error in
            self.removeFromFavoritesError(error)
        }
    }
    
    private func removeFromFavoritesError(_ error: Error) {
        DispatchQueue.main.async { [self] in
            // Session logout required?
            if let pwgError = error as? PwgSessionError,
               [.invalidCredentials, .incompatiblePwgVersion, .invalidURL, .authenticationFailed].contains(pwgError) {
                ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
                return
            }

            // Report error
            let title = NSLocalizedString("imageFavorites_title", comment: "Favorites")
            let message = NSLocalizedString("imageFavoritesRemoveError_message", comment: "Failed to remove this photo from your favorites.")
            self.dismissPiwigoError(withTitle: title, message: message, errorMessage: error.localizedDescription) { [self] in
                self.favoriteBarButton?.isEnabled = true
            }
        }
    }
}
