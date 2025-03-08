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
        if NetworkVars.shared.pwgVersion.compare("2.10.0", options: .numeric) == .orderedAscending {
            return nil
        }
        if NetworkVars.shared.userStatus == .guest {
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
        initSelection(ofImagesWithIDs: selectedImageIDs, beforeAction: .favorite, contextually: false)
    }

    func favorite(imagesWithID someIDs: Set<Int64>, total: Float, contextually: Bool) {
        var remainingIDs = someIDs
        guard let imageID = remainingIDs.first else {
            // Save changes
//            bckgContext.saveIfNeeded()
            // Close HUD with success
            navigationController?.updateHUDwithSuccess() { [self] in
                navigationController?.hideHUD(afterDelay: pwgDelayHUD) { [self] in
                    // Deselect images if needed
                    if contextually {
                        setEnableStateOfButtons(true)
                    } else {
                        cancelSelect()
                    }
                }
            }
            return
        }

        // Get image data
        guard let imageData = (images.fetchedObjects ?? []).first(where: {$0.pwgID == imageID}) else {
            // Forget this image
            remainingIDs.removeFirst()
            if contextually == false {
                deselectImages(withIDs: Set([imageID]))
            }

            // Update HUD
            navigationController?.updateHUD(withProgress: 1.0 - Float(remainingIDs.count) / total)

            // Next image
            favorite(imagesWithID: remainingIDs, total: total, contextually: contextually)
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
                        self.mainContext.saveIfNeeded()
                    }
                    
                    // pwg.users.favorites… methods available from Piwigo version 2.10
                    if self.hasFavorites {
                        let visibleCells = self.collectionView?.visibleCells ?? []
                        let imageCells = visibleCells.compactMap({$0 as? ImageCollectionViewCell})
                        if let cell = imageCells.first(where: { $0.imageData.pwgID == imageID}) {
                            cell.isFavorite = true
                        }
                    }
                    
                    // Next image
                    remainingIDs.remove(imageID)
                    if contextually == false {
                        deselectImages(withIDs: Set([imageID]))
                    }
                    favorite(imagesWithID: remainingIDs, total: total, contextually: contextually)
                }
            } failure: { [self] error in
                self.favoriteError(error, contextually: contextually)
            }
        } failure: { [self] error in
            self.favoriteError(error, contextually: contextually)
        }
    }
    
    private func favoriteError(_ error: Error, contextually: Bool) {
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
            navigationController?.dismissPiwigoError(withTitle: title, message: message, errorMessage: error.localizedDescription) { [self] in
                navigationController?.hideHUD() { [self] in
                    if contextually {
                        setEnableStateOfButtons(true)
                    } else {
                        updateBarsInSelectMode()
                    }
                }
            }
        }
    }
    
    
    // MARK: - Remove Images from Favorites
    @objc func unfavoriteSelection() {
        initSelection(ofImagesWithIDs: selectedImageIDs, beforeAction: .unfavorite, contextually: false)
    }

    func unfavorite(imagesWithID someIDs: Set<Int64>, total: Float, contextually: Bool) {
        var remainingIDs = someIDs
        guard let imageID = remainingIDs.first else {
            // Save changes
//            bckgContext.saveIfNeeded()
            // Close HUD with success
            navigationController?.updateHUDwithSuccess() { [self] in
                navigationController?.hideHUD(afterDelay: pwgDelayHUD) { [self] in
                    // Deselect images if needed
                    if contextually {
                        setEnableStateOfButtons(true)
                    } else {
                        cancelSelect()
                    }
                }
            }
            return
        }

        // Get image data
        guard let imageData = (images.fetchedObjects ?? []).first(where: {$0.pwgID == imageID}) else {
            // Deselect this image if needed
            remainingIDs.remove(imageID)
            if contextually == false {
                deselectImages(withIDs: Set([imageID]))
            }

            // Update HUD
            navigationController?.updateHUD(withProgress: 1.0 - Float(remainingIDs.count) / total)

            // Next image
            unfavorite(imagesWithID: remainingIDs, total: total, contextually: contextually)
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
                        self.mainContext.saveIfNeeded()
                    }
                    
                    // pwg.users.favorites… methods available from Piwigo version 2.10
                    if self.hasFavorites {
                        let visibleCells = self.collectionView?.visibleCells ?? []
                        let imageCells = visibleCells.compactMap({$0 as? ImageCollectionViewCell})
                        if let cell = imageCells.first(where: { $0.imageData.pwgID == imageID}) {
                            cell.isFavorite = false
                        }
                    }
                    
                    // Next image
                    remainingIDs.removeFirst()
                    if contextually == false {
                        deselectImages(withIDs: Set([imageID]))
                    }
                    unfavorite(imagesWithID: remainingIDs, total: total, contextually: contextually)
                }
            } failure: { [self] error in
                self.unfavoriteError(error, contextually: contextually)
            }
        } failure: { [self] error in
            self.unfavoriteError(error, contextually: contextually)
        }
    }
    
    private func unfavoriteError(_ error: Error, contextually: Bool) {
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
            navigationController?.dismissPiwigoError(withTitle: title, message: message, errorMessage: error.localizedDescription) { [self] in
                navigationController?.hideHUD() { [self] in
                    if contextually {
                        setEnableStateOfButtons(true)
                    } else {
                        updateBarsInSelectMode()
                    }
                }
            }
        }
    }
}
