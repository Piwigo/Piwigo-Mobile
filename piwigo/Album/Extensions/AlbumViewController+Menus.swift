//
//  AlbumViewController+Menus.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

@available(iOS 14.0, *)
extension AlbumViewController
{
    // MARK: Album Menu
    /// - for copying images to another album
    /// - for moving images to another album
    func albumMenu() -> UIMenu {
        let menuId = UIMenu.Identifier("org.piwigo.piwigoImage.album")
        let menu = UIMenu(title: "", image: nil, identifier: menuId,
                          options: UIMenu.Options.displayInline,
                          children: [imagesCopyAction(), imagesMoveAction()])
        return menu
    }
    
    private func imagesCopyAction() -> UIAction {
        let actionId = UIAction.Identifier("Copy")
        let action = UIAction(title: NSLocalizedString("copyImage_title", comment: "Copy to Album"),
                              image: UIImage(systemName: "rectangle.stack.badge.plus"),
                              identifier: actionId, handler: { [self] action in
            // Disable buttons during action
            setEnableStateOfButtons(false)
            // Present album selector for copying image
            copyImageToAlbum()
        })
        action.accessibilityIdentifier = "copy"
        return action
    }
    
    private func imagesMoveAction() -> UIAction {
        let actionId = UIAction.Identifier("Move")
        let action = UIAction(title: NSLocalizedString("moveImage_title", comment: "Move to Album"),
                              image: UIImage(systemName: "arrowshape.turn.up.right"),
                              identifier: actionId, handler: { [self] action in
            // Disable buttons during action
            setEnableStateOfButtons(false)
            // Present album selector for moving image
            moveImageToAlbum()
        })
        action.accessibilityIdentifier = "move"
        return action
    }
    
    
    // MARK: - Images Menu
    /// - for editing image parameters
    func imagesMenu() -> UIMenu {
        let menuId = UIMenu.Identifier("org.piwigo.piwigoImage.edit")
        let menu = UIMenu(title: "", image: nil, identifier: menuId,
                          options: UIMenu.Options.displayInline,
                          children: [editParamsAction()])
        return menu
    }

    private func editParamsAction() -> UIAction {
        let actionId = UIAction.Identifier("Edit Parameters")
        let action = UIAction(title: NSLocalizedString("imageOptions_properties", comment: "Modify Information"),
                              image: UIImage(systemName: "pencil"),
                              identifier: actionId, handler: { [self] action in
           // Edit image informations
           editSelection()
        })
        return action
    }
 
    
    // MARK: - Discover Menu
    /// - for presenting favorite images if logged in
    /// - for presenting the tag selector and then tagged images
    /// - for presenting most visited images
    /// - for presenting best rated images
    /// - for presenting recent images
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
            // Present favorite images
            let favoritesVC = AlbumViewController(albumId: kPiwigoFavoritesCategoryId)
            navigationController?.pushViewController(favoritesVC, animated: true)
        })
        return action
    }

    private func taggedAction() -> UIAction {
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
            discoverImages(inCategoryId: kPiwigoVisitsCategoryId)
        })
        return action
    }
    
    private func bestRatedAction() -> UIAction {
        let actionId = UIAction.Identifier("Best rated")
        let action = UIAction(title: NSLocalizedString("categoryDiscoverBest_title", comment: "Best rated"),
                              image: UIImage(systemName: "star.leadinghalf.fill"),
                              identifier: actionId, handler: { [self] action in
            // Present best rated images
            discoverImages(inCategoryId: kPiwigoBestCategoryId)
        })
        return action
    }
    
    private func recentAction() -> UIAction {
        let actionId = UIAction.Identifier("Recent")
        let action = UIAction(title: NSLocalizedString("categoryDiscoverRecent_title", comment: "Recent photos"),
                              image: UIImage(systemName: "clock"),
                              identifier: actionId, handler: { [self] action in
            // Present recent images
            discoverImages(inCategoryId: kPiwigoRecentCategoryId)
        })
        return action
    }
}
