//
//  AlbumImagesViewController+MenusOld.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

@objc
extension AlbumImagesViewController
{
    // MARK: Discover Menu (iOS 9.3 to 13.x)
    @objc func discoverMenuOld() {
        /// - for presenting favorite images
        /// - for presenting the tag selector and then tagged images
        /// - for presenting most visited images
        /// - for presenting best rated images
        /// - for presenting recent images
        let alert = UIAlertController(title: nil,
            message: NSLocalizedString("categoryDiscover_title", comment: "Discover"),
            preferredStyle: .actionSheet)

        let cancelAction = UIAlertAction(
            title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
            style: .cancel, handler: { action in })

        let favoritesSelectorAction = UIAlertAction(
            title: NSLocalizedString("categoryDiscoverFavorites_title", comment: "My Favorites"),
            style: .default, handler: { [self] action in
                // Present favorite images
                let favoritesVC = AlbumImagesViewController(albumId: kPiwigoFavoritesCategoryId)
                navigationController?.pushViewController(favoritesVC, animated: true)
            })

        let tagSelectorAction = UIAlertAction(
            title: NSLocalizedString("tags", comment: "Tags"),
            style: .default, handler: { [self] action in
                discoverImagesByTag()
            })

        let mostVisitedAction = UIAlertAction(
            title: NSLocalizedString("categoryDiscoverVisits_title", comment: "Most visited"),
            style: .default, handler: { [self] action in
                discoverImages(inCategoryId: kPiwigoVisitsCategoryId)
            })

        let bestRatedAction = UIAlertAction(
            title: NSLocalizedString("categoryDiscoverBest_title", comment: "Best rated"),
            style: .default, handler: { [self] action in
                discoverImages(inCategoryId: kPiwigoBestCategoryId)
            })

        let recentAction = UIAlertAction(
            title: NSLocalizedString("categoryDiscoverRecent_title", comment: "Recent Photos"),
            style: .default, handler: { [self] action in
                discoverImages(inCategoryId: kPiwigoRecentCategoryId)
            })

        // Add actions
        alert.addAction(cancelAction)
        if "2.10.0".compare(NetworkVarsObjc.pwgVersion, options: .numeric, range: nil, locale: .current) != .orderedDescending {
            alert.addAction(favoritesSelectorAction)
        }
        alert.addAction(tagSelectorAction)
        alert.addAction(mostVisitedAction)
        alert.addAction(bestRatedAction)
        alert.addAction(recentAction)

        // Present list of Discover views
        alert.view.tintColor = UIColor.piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        alert.popoverPresentationController?.barButtonItem = discoverBarButton
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange()
        }
    }

    
    // MARK: - Discover Images
    func discoverImages(inCategoryId categoryId: Int) {
        // Create Discover view
        let discoverVC = AlbumImagesViewController(albumId: categoryId)
        navigationController?.pushViewController(discoverVC, animated: true)
    }

    func discoverImagesByTag() {
        // Push tag select view
        let tagSelectorSB = UIStoryboard(name: "TagSelectorViewController", bundle: nil)
        guard let tagSelectorVC = tagSelectorSB.instantiateViewController(withIdentifier: "TagSelectorViewController") as? TagSelectorViewController else {
            fatalError("No TagSelectorViewController!")
        }
        tagSelectorVC.tagSelectedDelegate = self
        pushView(tagSelectorVC)
    }
}
