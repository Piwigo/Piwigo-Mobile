//
//  ImageViewController+Favorites.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

extension ImageViewController
{
    // MARK: - Add/remove image from favorites
    func getFavoriteBarButton() -> UIBarButtonItem {
        let isFavorite = CategoriesData.sharedInstance()
            .category(withId: kPiwigoFavoritesCategoryId, containsImagesWithId: [NSNumber(value: imageData.imageId)])
        let button = UIBarButtonItem.favoriteImageButton(isFavorite, target: self)
        button.action = isFavorite ? #selector(removeFromFavorites) : #selector(addToFavorites)
        button.isEnabled = true
        return button
    }
    
    @objc func addToFavorites() {
        // Disable button during action
        favoriteBarButton?.isEnabled = false

        // Send request to Piwigo server
        ImageUtilities.addToFavorites(imageData) {
            DispatchQueue.main.async { [self] in
                favoriteBarButton?.setFavoriteImage(for: true)
                favoriteBarButton?.action = #selector(self.removeFromFavorites)
                favoriteBarButton?.isEnabled = true
            }
        } failure: { error in
            DispatchQueue.main.async { [self] in
                dismissPiwigoError(withTitle: NSLocalizedString("imageFavorites_title", comment: "Favorites"), message: NSLocalizedString("imageFavoritesAddError_message", comment: "Failed to add this photo to your favorites."), errorMessage: error.localizedDescription) { [self] in
                    favoriteBarButton?.isEnabled = true
                }
            }
        }
    }

    @objc func removeFromFavorites() {
        // Disable button during action
        favoriteBarButton?.isEnabled = false

        // Send request to Piwigo server
        ImageUtilities.removeFromFavorites(imageData) { [unowned self] in
            DispatchQueue.main.async {
                if self.categoryId == kPiwigoFavoritesCategoryId {
                    // Remove image from the album of favorites
                    self.didRemoveImage(withId: self.imageData.imageId)
                } else {
                    // Update favorite button
                    self.favoriteBarButton?.setFavoriteImage(for: false)
                    self.favoriteBarButton?.action = #selector(self.addToFavorites)
                    self.favoriteBarButton?.isEnabled = true
                }
            }
        } failure: { error in
            DispatchQueue.main.async {
                self.dismissPiwigoError(withTitle: NSLocalizedString("imageFavorites_title", comment: "Favorites"), message: NSLocalizedString("imageFavoritesRemoveError_message", comment: "Failed to remove this photo from your favorites."), errorMessage: error.localizedDescription) {
                    self.favoriteBarButton?.isEnabled = true
                }
            }
        }
    }
}
