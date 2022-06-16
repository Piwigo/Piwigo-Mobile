//
//  AlbumImagesViewController+Favorites.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

extension AlbumImagesViewController
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
                    
                    // Show favorite icons
                    for cell in imagesCollection?.visibleCells ?? [] {
                        if let imageCell = cell as? ImageCollectionViewCell {
                            imageCell.isFavorite = CategoriesData.sharedInstance().category(withId: kPiwigoFavoritesCategoryId, containsImagesWithId: [NSNumber(value: imageCell.imageData?.imageId ?? 0)])
                        }
                    }
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
            dismissRetryPiwigoError(withTitle: NSLocalizedString("imageFavorites_title", comment: "Favorites"), message: NSLocalizedString("imageFavoritesAddError_message", comment: "Failed to add this photo to your favorites."), errorMessage: error.localizedDescription, dismiss: { [self] in
                hidePiwigoHUD() { [self] in
                    updateButtonsInSelectionMode()
                }
            }, retry: { [self] in
                // Try relogin if unauthorized
                if error.code == 401 {
                    let appDelegate = UIApplication.shared.delegate as? AppDelegate
                    appDelegate?.reloginAndRetry(afterRestoringScene: false) { [self] in
                        addImageToFavorites()
                    }
                } else {
                    addImageToFavorites()
                }
            })
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
                    for cell in imagesCollection?.visibleCells ?? [] {
                        if let imageCell = cell as? ImageCollectionViewCell {
                            imageCell.isFavorite = CategoriesData.sharedInstance().category(withId: kPiwigoFavoritesCategoryId, containsImagesWithId: [NSNumber(value: imageCell.imageData?.imageId ?? 0)])
                        }
                    }
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

        } failure: { [self] error in
            // Failed — Ask user if he/she wishes to retry
            dismissRetryPiwigoError(withTitle: NSLocalizedString("imageFavorites_title", comment: "Favorites"), message: NSLocalizedString("imageFavoritesRemoveError_message", comment: "Failed to remove this photo from your favorites."), errorMessage: error.localizedDescription, dismiss: { [self] in
                hidePiwigoHUD() { [self] in
                    updateButtonsInSelectionMode()
                }
            }, retry: { [self] in
                // Try relogin if unauthorized
                if error.code == 401 {
                    let appDelegate = UIApplication.shared.delegate as? AppDelegate
                    appDelegate?.reloginAndRetry(afterRestoringScene: false) { [self] in
                        removeImageFromFavorites()
                    }
                } else {
                    removeImageFromFavorites()
                }
            })
        }
    }
}
