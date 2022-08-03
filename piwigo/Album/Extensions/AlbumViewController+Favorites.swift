//
//  AlbumViewController+Favorites.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

extension AlbumViewController
{
    // MARK: Favorites Bar Button
    func getFavoriteBarButton() -> UIBarButtonItem? {
        let areFavorites = CategoriesData.sharedInstance()
            .category(withId: categoryId, containsImagesWithId: selectedImageIds)
        let button = UIBarButtonItem.favoriteImageButton(areFavorites, target: self)
        button.action = areFavorites ? #selector(removeFromFavorites) : #selector(addToFavorites)
        return button
    }

    
    // MARK: - Add images to favorites
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
        guard let imageId = selectedImageIds.last?.intValue,
              let imageData = CategoriesData.sharedInstance()
                .getImageForCategory(categoryId, andId: imageId) else {
            // Forget this image
            selectedImageIds.removeLast()

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
            selectedImageIds.removeLast()

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
    
    private func refreshFavorites() {
        // Loop over the visible cells
        let visibleCells = imagesCollection?.visibleCells ?? []
        visibleCells.forEach { cell in
            if let imageCell = cell as? ImageCollectionViewCell,
               let imageId = imageCell.imageData?.imageId {
                let Ids = [NSNumber(value: imageId)]
                let isFavorite = CategoriesData.sharedInstance()
                    .category(withId: kPiwigoFavoritesCategoryId, containsImagesWithId: Ids)
                imageCell.isFavorite = isFavorite
                imageCell.setNeedsLayout()
                imageCell.layoutIfNeeded()
            }
        }
    }

    
    // MARK: - Remove images from favorites
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
        guard  let imageId = selectedImageIds.last?.intValue,
               let imageData = CategoriesData.sharedInstance()
                .getImageForCategory(categoryId, andId: imageId) else {
            // Forget this image
            selectedImageIds.removeLast()

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
            selectedImageIds.removeLast()

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
