//
//  AlbumViewController+Favorites.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

extension AlbumViewController
{
    // MARK: Favorites Utilities
    func getFavoriteBarButton() -> UIBarButtonItem {
        let selectedImages: [Image] = (images.fetchedObjects ?? []).filter({selectedImageIds.contains($0.pwgID)})
        let albumSetsOfImages: [Set<Album>] = selectedImages.map({$0.albums ?? Set<Album>()})
        let areFavorites = albumSetsOfImages.first(where: {$0.contains(where: {$0.pwgID == pwgSmartAlbum.favorites.rawValue}) == false}) == nil
        let button = UIBarButtonItem.favoriteImageButton(areFavorites, target: self)
        button.action = areFavorites ? #selector(removeFromFavorites) : #selector(addToFavorites)
        return button
    }


    // MARK: - Add Images to Favorites
    @objc func addToFavorites() {
        initSelection(beforeAction: .addToFavorites)
    }

    func addImageToFavorites() {
        if selectedImageIds.isEmpty {
            // Save changes
            try? bckgContext.save()
            // Close HUD with success
            updatePiwigoHUDwithSuccess() { [self] in
                hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { [self] in
                    // Deselect images
                    cancelSelect()
                }
            }
            return
        }

        // Get image data
        guard let imageId = selectedImageIds.first,
              let imageData = (images.fetchedObjects ?? []).first(where: {$0.pwgID == imageId}) else {
            // Forget this image
            selectedImageIds.removeFirst()

            // Update HUD
            updatePiwigoHUD(withProgress: 1.0 - Float(selectedImageIds.count) / Float(totalNumberOfImages))

            // Next image
            addImageToFavorites()
            return
        }

        // Add image to favorites
        LoginUtilities.checkSession(ofUser: user) { [self] in
            ImageUtilities.addToFavorites(imageData) { [self] in
                DispatchQueue.main.async { [self] in
                    // Update HUD
                    self.updatePiwigoHUD(withProgress: 1.0 - Float(self.selectedImageIds.count) / Float(self.totalNumberOfImages))
                    
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
                    selectedImageIds.removeFirst()
                    addImageToFavorites()
                }
            } failure: { [self] error in
                self.addImageToFavoritesError(error)
            }
        } failure: { [self] error in
            self.addImageToFavoritesError(error)
        }
    }
    
    private func addImageToFavoritesError(_ error: NSError) {
        DispatchQueue.main.async { [self] in
            let title = NSLocalizedString("imageFavorites_title", comment: "Favorites")
            let message = NSLocalizedString("imageFavoritesAddError_message", comment: "Failed to add this photo to your favorites.")
            dismissPiwigoError(withTitle: title, message: message,
                               errorMessage: error.localizedDescription) { [self] in
                hidePiwigoHUD() { [self] in
                    updateButtonsInSelectionMode()
                }
            }
        }
    }
    
    
    // MARK: - Remove Images from Favorites
    @objc func removeFromFavorites() {
        initSelection(beforeAction: .removeFromFavorites)
    }

    func removeImageFromFavorites() {
        if selectedImageIds.isEmpty {
            // Save changes
            try? bckgContext.save()
            // Close HUD with success
            updatePiwigoHUDwithSuccess() { [self] in
                hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { [self] in
                    // Deselect images
                    cancelSelect()
                }
            }
            return
        }

        // Get image data
        guard  let imageId = selectedImageIds.first,
               let imageData = (images.fetchedObjects ?? []).first(where: {$0.pwgID == imageId}) else {
            // Deselect this image
            selectedImageIds.removeFirst()

            // Update HUD
            updatePiwigoHUD(withProgress: 1.0 - Float(selectedImageIds.count) / Float(totalNumberOfImages))

            // Next image
            removeImageFromFavorites()
            return
        }

        // Remove image to favorites
        LoginUtilities.checkSession(ofUser: user) { [self] in
            ImageUtilities.removeFromFavorites(imageData) { [self] in
                DispatchQueue.main.async { [self] in
                    // Update HUD
                    self.updatePiwigoHUD(withProgress: 1.0 - Float(self.selectedImageIds.count) / Float(self.totalNumberOfImages))
                    
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
                    selectedImageIds.removeFirst()
                    removeImageFromFavorites()
                }
            } failure: { [unowned self] error in
                self.removeFromFavoritesError(error)
            }
        } failure: { [unowned self] error in
            self.removeFromFavoritesError(error)
        }
    }
    
    private func removeFromFavoritesError(_ error: NSError) {
        DispatchQueue.main.async { [self] in
            let title = NSLocalizedString("imageFavorites_title", comment: "Favorites")
            let message = NSLocalizedString("imageFavoritesRemoveError_message", comment: "Failed to remove this photo from your favorites.")
            dismissPiwigoError(withTitle: title, message: message,
                               errorMessage: error.localizedDescription) { [unowned self] in
                hidePiwigoHUD() { [unowned self] in
                    updateButtonsInSelectionMode()
                }
            }
        }
    }
}
