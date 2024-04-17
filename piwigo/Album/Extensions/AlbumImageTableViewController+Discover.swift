//
//  AlbumImageTableViewController+Discover.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

// MARK: "Discover" menu/button
extension AlbumImageTableViewController
{
    func getDiscoverButton() -> UIBarButtonItem {
        var button: UIBarButtonItem!
        if #available(iOS 14.0, *) {
            // Menu
            button = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: discoverMenu())
        } else {
            // Fallback on earlier versions
            button = UIBarButtonItem(image: UIImage(named: "action"), landscapeImagePhone: UIImage(named: "actionCompact"), style: .plain, target: self, action: #selector(discoverMenuOld))
        }
        button.accessibilityIdentifier = "discover"
        return button
    }
}


// MARK: - Discover Menu (iOS 14+)
/// - for presenting favorite images if logged in
/// - for presenting the tag selector and then tagged images
/// - for presenting most visited images
/// - for presenting best rated images
/// - for presenting recent images
@available(iOS 14.0, *)
extension AlbumImageTableViewController
{
    func discoverMenu() -> UIMenu {
        let menuId = UIMenu.Identifier("org.piwigo.piwigoImage.discover")
        var children = [taggedAction(), mostVisitedAction(), bestRatedAction(), recentAction()]
        if NetworkVars.username.isEmpty == false,
           NetworkVars.username.lowercased() != "guest" {
            children.insert(favoritesAction(), at: 0)
        }
        let menu = UIMenu(title: "", image: nil, identifier: menuId,
                          options: UIMenu.Options.displayInline,
                          children: children)
        return menu
    }
    
    private func favoritesAction() -> UIAction {
        let actionId = UIAction.Identifier("Favorites")
        let action = UIAction(title: NSLocalizedString("categoryDiscoverFavorites_title", comment: "My Favorites"),
                              image: UIImage(systemName: "heart"),
                              identifier: actionId, handler: { [self] action in
            // Check that an album of favorites exists in cache (create it if necessary)
            guard let _ = albumProvider.getAlbum(ofUser: user, withId: pwgSmartAlbum.favorites.rawValue) else {
                return
            }
            
            // Present favorite images
            guard let favoritesVC = storyboard?.instantiateViewController(withIdentifier: "AlbumImageTableViewController") as? AlbumImageTableViewController else {
                fatalError("!!! No AlbumImageTableViewController !!!")
            }
            favoritesVC.categoryId = pwgSmartAlbum.favorites.rawValue
            navigationController?.pushViewController(favoritesVC, animated: true)
        })
        return action
    }
    
    private func taggedAction() -> UIAction {
        // Create action
        let actionId = UIAction.Identifier("Tagged")
        let action = UIAction(title: NSLocalizedString("categoryDiscoverTagged_title", comment: "Tagged"),
                              image: UIImage(systemName: "tag"),
                              identifier: actionId, handler: { [self] action in
            // Present tag selector
            discoverImagesByTag()
        })
        return action
    }
    
    private func mostVisitedAction() -> UIAction {
        let actionId = UIAction.Identifier("Most visited")
        let action = UIAction(title: NSLocalizedString("categoryDiscoverVisits_title", comment: "Most visited"),
                              image: UIImage(systemName: "person.3.fill"),
                              identifier: actionId, handler: { [self] action in
            // Present most visited images
            discoverImages(inCategoryId: pwgSmartAlbum.visits.rawValue)
        })
        return action
    }
    
    private func bestRatedAction() -> UIAction {
        let actionId = UIAction.Identifier("Best rated")
        let action = UIAction(title: NSLocalizedString("categoryDiscoverBest_title", comment: "Best rated"),
                              image: UIImage(systemName: "star.leadinghalf.fill"),
                              identifier: actionId, handler: { [self] action in
            // Present best rated images
            discoverImages(inCategoryId: pwgSmartAlbum.best.rawValue)
        })
        return action
    }
    
    private func recentAction() -> UIAction {
        let actionId = UIAction.Identifier("Recent")
        let action = UIAction(title: NSLocalizedString("categoryDiscoverRecent_title", comment: "Recent photos"),
                              image: UIImage(systemName: "clock"),
                              identifier: actionId, handler: { [self] action in
            // Present recent images
            discoverImages(inCategoryId: pwgSmartAlbum.recent.rawValue)
        })
        return action
    }
}


// MARK: - Discover Menu (iOS 9.3 to 13.x)
extension AlbumImageTableViewController
{
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
                guard let _ = albumProvider.getAlbum(ofUser: user, withId: pwgSmartAlbum.favorites.rawValue) else {
                    return
                }
                
                // Present favorite images
                guard let favoritesVC = storyboard?.instantiateViewController(withIdentifier: "AlbumImageTableViewController") as? AlbumImageTableViewController else {
                    fatalError("!!! No AlbumImageTableViewController !!!")
                }
                favoritesVC.categoryId = pwgSmartAlbum.favorites.rawValue
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
}
    

// MARK: - Discover Images
extension AlbumImageTableViewController
{
    func discoverImages(inCategoryId categoryId: Int32) {
        // Check that a discover album exists in cache (create it if necessary)
        guard let _ = albumProvider.getAlbum(ofUser: user, withId: categoryId) else {
            return
        }
        
        // Create and push Discover view
        guard let discoverVC = storyboard?.instantiateViewController(withIdentifier: "AlbumImageTableViewController") as? AlbumImageTableViewController else {
            fatalError("!!! No AlbumImageTableViewController !!!")
        }
        discoverVC.categoryId = categoryId
        self.navigationController?.pushViewController(discoverVC, animated: true)
    }

    func discoverImagesByTag() {
        // Push tag select view
        let tagSelectorSB = UIStoryboard(name: "TagSelectorViewController", bundle: nil)
        guard let tagSelectorVC = tagSelectorSB.instantiateViewController(withIdentifier: "TagSelectorViewController") as? TagSelectorViewController else {
            fatalError("No TagSelectorViewController!")
        }
        tagSelectorVC.user = user
        tagSelectorVC.tagSelectedDelegate = self
        pushView(tagSelectorVC)
    }
}


// MARK: - TagSelectorViewDelegate Methods
extension AlbumImageTableViewController: TagSelectorViewDelegate
{
    func pushTaggedImagesView(_ viewController: UIViewController) {
        // Push sub-album view
        navigationController?.pushViewController(viewController, animated: true)
    }
}
