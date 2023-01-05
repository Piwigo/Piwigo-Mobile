//
//  ImageViewController+Favorites.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

extension ImageViewController
{
    // MARK: - Add/remove image from favorites
    func getFavoriteBarButton() -> UIBarButtonItem {
        let isFavorite = (imageData?.albums ?? Set<Album>())
            .contains(where: {$0.pwgID == pwgSmartAlbum.favorites.rawValue})
        let button = UIBarButtonItem.favoriteImageButton(isFavorite, target: self)
        button.action = isFavorite ? #selector(removeFromFavorites) : #selector(addToFavorites)
        button.isEnabled = true
        return button
    }
    
    @objc func addToFavorites() {
        guard let imageData = imageData else { return }
        // Disable button during action
        favoriteBarButton?.isEnabled = false

        // Send request to Piwigo server
        ImageUtilities.addToFavorites(imageData) {
            DispatchQueue.main.async { [self] in
                if let favAlbum = albumProvider.getAlbum(inContext: savingContext,
                                                         withId: pwgSmartAlbum.favorites.rawValue) {
                    favAlbum.addToImages(imageData)
                }
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
        guard let imageData = imageData else { return }
        // Disable button during action
        favoriteBarButton?.isEnabled = false

        // Send request to Piwigo server
        ImageUtilities.removeFromFavorites(imageData) { [unowned self] in
            DispatchQueue.main.async { [self] in
                if let favAlbum = albumProvider.getAlbum(inContext: savingContext,
                                                         withId: pwgSmartAlbum.favorites.rawValue) {
                    favAlbum.removeFromImages(imageData)
                }
                if self.categoryId != pwgSmartAlbum.favorites.rawValue {
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
