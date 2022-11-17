//
//  AlbumViewController+MenusOld.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

@objc
extension AlbumViewController
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
                // Check that an album of favorites exists in cache (create it if necessary)
                guard let _ = albumProvider.getAlbum(inContext: mainContext,
                                                     withId: pwgSmartAlbum.favorites.rawValue) else {
                    return
                }
                
                // Present favorite images
                let favoritesVC = AlbumViewController(albumId: pwgSmartAlbum.favorites.rawValue)
                navigationController?.pushViewController(favoritesVC, animated: true)
            })

        let tagSelectorAction = UIAlertAction(
            title: NSLocalizedString("categoryDiscoverTagged_title", comment: "Tagged"),
            style: .default, handler: { [self] action in
                discoverImagesByTag()
            })

        let mostVisitedAction = UIAlertAction(
            title: NSLocalizedString("categoryDiscoverVisits_title", comment: "Most visited"),
            style: .default, handler: { [self] action in
                discoverImages(inCategoryId: pwgSmartAlbum.visits.rawValue)
            })

        let bestRatedAction = UIAlertAction(
            title: NSLocalizedString("categoryDiscoverBest_title", comment: "Best rated"),
            style: .default, handler: { [self] action in
                discoverImages(inCategoryId: pwgSmartAlbum.best.rawValue)
            })

        let recentAction = UIAlertAction(
            title: NSLocalizedString("categoryDiscoverRecent_title", comment: "Recent Photos"),
            style: .default, handler: { [self] action in
                discoverImages(inCategoryId: pwgSmartAlbum.recent.rawValue)
            })

        // Add actions
        alert.addAction(cancelAction)
        if "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending {
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
    func discoverImages(inCategoryId categoryId: Int32) {
        // Check that a discover album exists in cache (create it if necessary)
        guard let _ = albumProvider.getAlbum(inContext: mainContext, withId: categoryId) else {
            return
        }
        
        // Create and push Discover view
        let discoverVC = AlbumViewController(albumId: categoryId)
        self.navigationController?.pushViewController(discoverVC, animated: true)
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
