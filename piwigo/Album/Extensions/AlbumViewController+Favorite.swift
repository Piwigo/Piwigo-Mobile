//
//  AlbumViewController+Favorite.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import PwgKit
import PwgAPIKit
import PwgCacheKit

extension AlbumViewController
{
    // MARK: Favorite Button
    func getFavoriteBarButton() -> UIBarButtonItem? {
        // pwg.users.favorites… methods available from Piwigo version 2.10 for registered users
        guard userData.canManageFavorites()
        else { return nil }
        
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

    @MainActor
    func favorite(imagesWithID someIDs: Set<Int64>, total: Float, contextually: Bool) {
        var remainingIDs = someIDs
        guard let imageID = remainingIDs.first else {
            // Save changes
            mainContext.saveIfNeeded()
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

        // Send requests to Piwigo server
        Task {
            do throws(PwgKitError) {
                // Check session
                try await LoginUtilities().checkSessionOfCurrentUser()
                
                // Add image to favorites
                try await JSONManager.shared.addToFavorites(imageWithID: imageData.pwgID)
                                
                // Update cache and UI
                await MainActor.run {
                    // Update HUD
                    navigationController?.updateHUD(withProgress: 1.0 - Float(remainingIDs.count) / total)

                    // Image added to favorites ► Add it to the cached album
                    if let favAlbum = try? albumProvider.getOrCreateAlbum(withID: pwgSmartAlbum.favorites.rawValue,
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

                    // pwg.users.favorites… methods available from Piwigo version 2.10
                    if self.userData.canManageFavorites() {
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
            }
            catch {
                self.favoriteError(error, contextually: contextually)
            }
        }
    }
    
    @MainActor
    private func favoriteError(_ error: PwgKitError, contextually: Bool) {
        // Session logout required?
        if error.requiresLogout {
            ClearCache.closeSessionWithPwgError(from: self, error: error)
            return
        }
        
        // Report error
        let title = String(localized: "imageFavorites_title", comment: "Favorites")
        let message = String(localized: "imageFavoritesAddError_message", comment: "Failed to add this photo to your favorites.")
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
    
    
    // MARK: - Remove Images from Favorites
    @objc func unfavoriteSelection() {
        initSelection(ofImagesWithIDs: selectedImageIDs, beforeAction: .unfavorite, contextually: false)
    }

    @MainActor
    func unfavorite(imagesWithID someIDs: Set<Int64>, total: Float, contextually: Bool) {
        var remainingIDs = someIDs
        guard let imageID = remainingIDs.first else {
            // Save changes
            mainContext.saveIfNeeded()
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

        // Send requests to Piwigo server
        Task {
            do throws(PwgKitError) {
                // Check session
                try await LoginUtilities().checkSessionOfCurrentUser()
                
                // Remove image from favorites
                try await JSONManager.shared.removeFromFavorites(imageWithID: imageData.pwgID)
                
                // Update cache and UI
                await MainActor.run {
                    // Update HUD
                    navigationController?.updateHUD(withProgress: 1.0 - Float(remainingIDs.count) / total)

                    // Image removed from favorites ► Remove it from the cached album
                    if let favAlbum = try? albumProvider.getOrCreateAlbum(withID: pwgSmartAlbum.favorites.rawValue,
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

                    // pwg.users.favorites… methods available from Piwigo version 2.10
                    if self.userData.canManageFavorites() {
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
            }
            catch {
                self.unfavoriteError(error, contextually: contextually)
            }
        }
    }
    
    @MainActor
    private func unfavoriteError(_ error: PwgKitError, contextually: Bool) {
        // Session logout required?
        if error.requiresLogout {
            ClearCache.closeSessionWithPwgError(from: self, error: error)
            return
        }

        // Report error
        let title = String(localized: "imageFavorites_title", comment: "Favorites")
        let message = String(localized: "imageFavoritesRemoveError_message", comment: "Failed to remove this photo from your favorites.")
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
