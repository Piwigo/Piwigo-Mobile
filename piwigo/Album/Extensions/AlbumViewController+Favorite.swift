//
//  AlbumViewController+Favorite.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

extension AlbumViewController
{
    // MARK: Favorite Button
    func getFavoriteBarButton() -> UIBarButtonItem? {
        // pwg.users.favorites… methods available from Piwigo version 2.10 for registered users
        if NetworkVars.pwgVersion.compare("2.10.0", options: .numeric) == .orderedAscending {
            return nil
        }
        if NetworkVars.userStatus == .guest {
            return nil
        }
        
        // Are the selected images favorites?
        let areFavorites = selectedImageIDs == selectedFavoriteIDs
        let button = UIBarButtonItem.favoriteImageButton(areFavorites, target: self)
        button.action = areFavorites ? #selector(unfavoriteSelection) : #selector(favoriteSelection)
        return button
    }


    // MARK: - Add Images to Favorites
    @objc func favoriteSelection() {
        initSelection(ofImagesWithIDs: selectedImageIDs, beforeAction: .favorite)
    }

    func favorite(imagesWithID someIDs: Set<Int64>, total: Float) {
        var remainingIDs = someIDs
        guard let imageID = remainingIDs.first else {
            // Save changes
//            bckgContext.saveIfNeeded()
            // Close HUD with success
            navigationController?.updateHUDwithSuccess() { [self] in
                navigationController?.hideHUD(afterDelay: pwgDelayHUD) { [self] in
                    // Deselect images
                    cancelSelect()
                }
            }
            return
        }

        // Get image data
        guard let imageData = (images.fetchedObjects ?? []).first(where: {$0.pwgID == imageID}) else {
            // Forget this image
            remainingIDs.removeFirst()
            selectedImageIDs.remove(imageID)
            selectedFavoriteIDs.remove(imageID)
            selectedVideosIDs.remove(imageID)

            // Update HUD
            navigationController?.updateHUD(withProgress: 1.0 - Float(remainingIDs.count) / total)

            // Next image
            favorite(imagesWithID: remainingIDs, total: total)
            return
        }

        // Add image to favorites
        PwgSession.checkSession(ofUser: user) { [self] in
            ImageUtilities.addToFavorites(imageData) { [self] in
                DispatchQueue.main.async { [self] in
                    // Update HUD
                    navigationController?.updateHUD(withProgress: 1.0 - Float(remainingIDs.count) / total)
                    
                    // Image added to favorites ► Add it in the background
                    if let favAlbum = self.albumProvider.getAlbum(ofUser: self.user, withId: pwgSmartAlbum.favorites.rawValue) {
                        // Remove image from favorites album
                        favAlbum.addToImages(imageData)
                        // Update favorites album data
                        self.albumProvider.updateAlbums(addingImages: 1, toAlbum: favAlbum)
                        // Save changes
                        try? mainContext.save()
                    }
                    
                    // Next image
                    remainingIDs.removeFirst()
                    selectedImageIDs.remove(imageID)
                    selectedFavoriteIDs.remove(imageID)
                    selectedVideosIDs.remove(imageID)
                    favorite(imagesWithID: remainingIDs, total: total)
                }
            } failure: { [self] error in
                self.favoriteError(error)
            }
        } failure: { [self] error in
            self.favoriteError(error)
        }
    }
    
    private func favoriteError(_ error: NSError) {
        DispatchQueue.main.async { [self] in
            // Session logout required?
            if let pwgError = error as? PwgSessionError,
               [.invalidCredentials, .incompatiblePwgVersion, .invalidURL, .authenticationFailed]
                .contains(pwgError) {
                ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
                return
            }
            
            // Report error
            let title = NSLocalizedString("imageFavorites_title", comment: "Favorites")
            let message = NSLocalizedString("imageFavoritesAddError_message", comment: "Failed to add this photo to your favorites.")
            navigationController?.dismissPiwigoError(withTitle: title, message: message,
                               errorMessage: error.localizedDescription) { [self] in
                navigationController?.hideHUD() { [self] in
                    updateBarsInSelectMode()
                }
            }
        }
    }
    
    
    // MARK: - Remove Images from Favorites
    @objc func unfavoriteSelection() {
        initSelection(ofImagesWithIDs: selectedImageIDs, beforeAction: .unfavorite)
    }

    func unfavorite(imagesWithID someIDs: Set<Int64>, total: Float) {
        var remainingIDs = someIDs
        guard let imageID = remainingIDs.first else {
            // Save changes
//            bckgContext.saveIfNeeded()
            // Close HUD with success
            navigationController?.updateHUDwithSuccess() { [self] in
                navigationController?.hideHUD(afterDelay: pwgDelayHUD) { [self] in
                    // Deselect images
                    cancelSelect()
                }
            }
            return
        }

        // Get image data
        guard let imageData = (images.fetchedObjects ?? []).first(where: {$0.pwgID == imageID}) else {
            // Deselect this image
            remainingIDs.removeFirst()
            selectedImageIDs.remove(imageID)
            selectedFavoriteIDs.remove(imageID)
            selectedVideosIDs.remove(imageID)

            // Update HUD
            navigationController?.updateHUD(withProgress: 1.0 - Float(remainingIDs.count) / total)

            // Next image
            unfavorite(imagesWithID: remainingIDs, total: total)
            return
        }

        // Remove image to favorites
        PwgSession.checkSession(ofUser: user) { [self] in
            ImageUtilities.removeFromFavorites(imageData) { [self] in
                DispatchQueue.main.async { [self] in
                    // Update HUD
                    navigationController?.updateHUD(withProgress: 1.0 - Float(remainingIDs.count) / total)
                    
                    // Image removed from favorites ► Remove it in the foreground
                    if let favAlbum = self.albumProvider.getAlbum(ofUser: self.user, withId: pwgSmartAlbum.favorites.rawValue) {
                        // Remove image from favorites album
                        favAlbum.removeFromImages(imageData)
                        // Update favorites album data
                        self.albumProvider.updateAlbums(removingImages: 1, fromAlbum: favAlbum)
                        // Save changes
                        try? mainContext.save()
                    }
                    
                    // Next image
                    remainingIDs.removeFirst()
                    selectedImageIDs.remove(imageID)
                    selectedFavoriteIDs.remove(imageID)
                    selectedVideosIDs.remove(imageID)
                    unfavorite(imagesWithID: remainingIDs, total: total)
                }
            } failure: { [unowned self] error in
                self.unfavoriteError(error)
            }
        } failure: { [unowned self] error in
            self.unfavoriteError(error)
        }
    }
    
    private func unfavoriteError(_ error: NSError) {
        DispatchQueue.main.async { [self] in
            // Session logout required?
            if let pwgError = error as? PwgSessionError,
               [.invalidCredentials, .incompatiblePwgVersion, .invalidURL, .authenticationFailed]
                .contains(pwgError) {
                ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
                return
            }

            // Report error
            let title = NSLocalizedString("imageFavorites_title", comment: "Favorites")
            let message = NSLocalizedString("imageFavoritesRemoveError_message", comment: "Failed to remove this photo from your favorites.")
            navigationController?.dismissPiwigoError(withTitle: title, message: message,
                               errorMessage: error.localizedDescription) { [unowned self] in
                navigationController?.hideHUD() { [unowned self] in
                    updateBarsInSelectMode()
                }
            }
        }
    }
}
