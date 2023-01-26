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
    func getFavoriteBarButton() -> UIBarButtonItem? {
        let selectedImages: [Image] = images.fetchedObjects?.filter({selectedImageIds.contains($0.pwgID)}) ?? []
        let albumSetsOfImages: [Set<Album>] = selectedImages.map({$0.albums ?? Set<Album>()})
        let areFavorites = albumSetsOfImages.first(where: {$0.contains(where: {$0.pwgID == pwgSmartAlbum.favorites.rawValue}) == false}) == nil
        let button = UIBarButtonItem.favoriteImageButton(areFavorites, target: self)
        button.action = areFavorites ? #selector(removeFromFavorites) : #selector(addToFavorites)
        return button
    }

    private func refreshFavorites() {
        // Loop over the visible cells
        let visibleCells = imagesCollection?.visibleCells ?? []
        visibleCells.forEach { cell in
            if let imageCell = cell as? ImageCollectionViewCell {
                let isFavorite = (imageCell.imageData?.albums ?? Set<Album>())
                    .contains(where: {$0.pwgID == pwgSmartAlbum.favorites.rawValue})
                imageCell.isFavorite = isFavorite
                imageCell.setNeedsLayout()
                imageCell.layoutIfNeeded()
            }
        }
    }


    // MARK: - Add Images to Favorites
    @objc func addToFavorites() {
        initSelection(beforeAction: .addToFavorites)
    }

    func addImageToFavorites() {
        if selectedImageIds.isEmpty {
            // Close HUD with success
            updatePiwigoHUDwithSuccess() { [self] in
                hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { [self] in
                    // Update button
                    favoriteBarButton?.setFavoriteImage(for: true)
                    favoriteBarButton?.action = #selector(removeFromFavorites)
                    
                    // Deselect images
                    cancelSelect()
                    
                    // Update favorite icons
                    refreshFavorites()
                }
            }
            return
        }

        // Get image data
        guard let imageId = selectedImageIds.first,
              let imageData = images.fetchedObjects?.first(where: {$0.pwgID == imageId}) else {
            // Forget this image
            selectedImageIds.removeFirst()

            // Update HUD
            updatePiwigoHUD(withProgress: 1.0 - Float(selectedImageIds.count) / Float(totalNumberOfImages))

            // Next image
            addImageToFavorites()
            return
        }

        // Add image to favorites
        ImageUtilities.addToFavorites(imageData) { [self] in
            // Update HUD
            updatePiwigoHUD(withProgress: 1.0 - Float(selectedImageIds.count) / Float(totalNumberOfImages))

            // Image added to favorites
            selectedImageIds.removeFirst()

            // Next image
            addImageToFavorites()

        } failure: { [self] error in
            // Failed — Ask user if he/she wishes to retry
            let title = NSLocalizedString("imageFavorites_title", comment: "Favorites")
            var message = NSLocalizedString("imageFavoritesAddError_message", comment: "Failed to add this photo to your favorites.")
            dismissRetryPiwigoError(withTitle: title, message: message,
                                    errorMessage: error.localizedDescription, dismiss: { [self] in
                hidePiwigoHUD() { [self] in
                    updateButtonsInSelectionMode()
                }
            }, retry: { [self] in
                // Relogin and retry
                LoginUtilities.reloginAndRetry() { [unowned self] in
                    addImageToFavorites()
                } failure: { [self] error in
                    message = NSLocalizedString("internetErrorGeneral_broken", comment: "Sorry…")
                    dismissPiwigoError(withTitle: title, message: message,
                                       errorMessage: error?.localizedDescription ?? "") { [self] in
                        hidePiwigoHUD() { [self] in
                            updateButtonsInSelectionMode()
                        }
                    }
                }
            })
        }
    }
    
    
    // MARK: - Remove Images from Favorites
    @objc func removeFromFavorites() {
        initSelection(beforeAction: .removeFromFavorites)
    }

    func removeImageFromFavorites() {
        if selectedImageIds.isEmpty {
            // Close HUD with success
            updatePiwigoHUDwithSuccess() { [self] in
                hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { [self] in
                    // Update button
                    favoriteBarButton?.setFavoriteImage(for: false)
                    favoriteBarButton?.action = #selector(addToFavorites)
                    
                    // Deselect images
                    cancelSelect()
                    
                    // Hide favorite icons
                    refreshFavorites()
                }
            }
            return
        }

        // Get image data
        guard  let imageId = selectedImageIds.first,
               let imageData = images.fetchedObjects?.first(where: {$0.pwgID == imageId}) else {
            // Deselect this image
            selectedImageIds.removeFirst()

            // Update HUD
            updatePiwigoHUD(withProgress: 1.0 - Float(selectedImageIds.count) / Float(totalNumberOfImages))

            // Next image
            removeImageFromFavorites()
            return
        }

        // Remove image to favorites
        ImageUtilities.removeFromFavorites(imageData) { [self] in
            // Update HUD
            updatePiwigoHUD(withProgress: 1.0 - Float(selectedImageIds.count) / Float(totalNumberOfImages))

            // Image removed from the favorites
            selectedImageIds.removeFirst()

            // Next image
            removeImageFromFavorites()

        } failure: { [unowned self] error in
            // Failed — Ask user if he/she wishes to retry
            let title = NSLocalizedString("imageFavorites_title", comment: "Favorites")
            var message = NSLocalizedString("imageFavoritesRemoveError_message", comment: "Failed to remove this photo from your favorites.")
            dismissRetryPiwigoError(withTitle: title, message: message,
                                    errorMessage: error.localizedDescription, dismiss: { [unowned self] in
                hidePiwigoHUD() { [unowned self] in
                    updateButtonsInSelectionMode()
                }
            }, retry: { [unowned self] in
                // Relogin and retry
                LoginUtilities.reloginAndRetry() { [unowned self] in
                    removeImageFromFavorites()
                } failure: { [self] error in
                    message = NSLocalizedString("internetErrorGeneral_broken", comment: "Sorry…")
                    dismissPiwigoError(withTitle: title, message: message,
                                       errorMessage: error?.localizedDescription ?? "") { [unowned self] in
                        hidePiwigoHUD() { [unowned self] in
                            updateButtonsInSelectionMode()
                        }
                    }
                }
            })
        }
    }
}
