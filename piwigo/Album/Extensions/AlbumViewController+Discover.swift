//
//  AlbumViewController+Discover.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 04/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

// MARK: Discover Button
extension AlbumViewController
{
    func getDiscoverButton() -> UIBarButtonItem {
        let button = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: discoverMenu())
        button.accessibilityIdentifier = "discover"
        return button
    }
}


// MARK: - Discover Menu
/// - for presenting favorite images if logged in
/// - for presenting the tag selector and then tagged images
/// - for presenting most visited images
/// - for presenting best rated images
/// - for presenting recent images
extension AlbumViewController
{
    func discoverMenu() -> UIMenu {
        let menuId = UIMenu.Identifier("org.piwigo.discover")
        let children = [smartAlbums(), viewOptionsMenu()]
        let menu = UIMenu(title: "", image: nil, identifier: menuId,
                          options: UIMenu.Options.displayInline,
                          children: children)
        return menu
    }
    
    func smartAlbums() -> UIMenu {
        let menuId = UIMenu.Identifier("org.piwigo.discover.smart")
        var children = [taggedAction(), mostVisitedAction(), bestRatedAction(), recentAction()]
        if NetworkVars.shared.username.isEmpty == false,
           NetworkVars.shared.username.lowercased() != "guest" {
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
            guard let favoritesVC = storyboard?.instantiateViewController(withIdentifier: "AlbumViewController") as? AlbumViewController
            else { preconditionFailure("Could not load AlbumViewController") }
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
        action.accessibilityIdentifier = "Tagged"
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
    

// MARK: - Discover Images
extension AlbumViewController
{
    func discoverImages(inCategoryId categoryId: Int32) {
        // Check that a discover album exists in cache (create it if necessary)
        guard let _ = albumProvider.getAlbum(ofUser: user, withId: categoryId) else {
            return
        }
        
        // Create and push Discover view
        guard let discoverVC = storyboard?.instantiateViewController(withIdentifier: "AlbumViewController") as? AlbumViewController
        else { preconditionFailure("Could not load AlbumImageTableViewController") }
        discoverVC.categoryId = categoryId
        self.navigationController?.pushViewController(discoverVC, animated: true)
    }

    func discoverImagesByTag() {
        // Push tag select view
        let tagSelectorSB = UIStoryboard(name: "TagSelectorViewController", bundle: nil)
        guard let tagSelectorVC = tagSelectorSB.instantiateViewController(withIdentifier: "TagSelectorViewController") as? TagSelectorViewController
        else { preconditionFailure("Could not load TagSelectorViewController") }
        tagSelectorVC.user = user
        tagSelectorVC.tagSelectedDelegate = self
        pushView(tagSelectorVC)
    }
}


// MARK: - TagSelectorViewDelegate Methods
extension AlbumViewController: TagSelectorViewDelegate
{
    func pushTaggedImagesView(_ viewController: UIViewController) {
        // Push sub-album view
        navigationController?.pushViewController(viewController, animated: true)
    }
}
