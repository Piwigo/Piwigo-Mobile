//
//  AlbumViewController+Menus.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

@available(iOS 14.0, *)
extension AlbumViewController
{
    // MARK: Discover Menu
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
            // Check that an album of favorites exists in cache (create it if necessary)
            guard let _ = albumProvider.getAlbum(ofUser: user, withId: pwgSmartAlbum.favorites.rawValue) else {
                return
            }

            // Present favorite images
            let favoritesVC = AlbumViewController(albumId: pwgSmartAlbum.favorites.rawValue)
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


    // MARK: - Select Menu
    /// - for switching to the selection mode
    func selectMenu() -> UIMenu {
        let menuId = UIMenu.Identifier("org.piwigo.piwigoImage.select")
        let menu = UIMenu(title: "", image: nil, identifier: menuId,
                          options: UIMenu.Options.displayInline,
                          children: [selectAction()])
        return menu
    }

    private func selectAction() -> UIAction {
        let actionId = UIAction.Identifier("Select")
        let action = UIAction(title: NSLocalizedString("categoryImageList_selectButton", comment: "Select"),
                              image: UIImage(systemName: "checkmark.circle"),
                              identifier: actionId, handler: { [self] action in
            self.didTapSelect()
        })
        action.accessibilityIdentifier = "Select"
        return action
    }
    

    // MARK: - Image Sorting
    /// - for selecting image sort options
    func imageSortMenu() -> UIMenu {
        let menuId = UIMenu.Identifier("org.piwigo.piwigoImage.sort")
        let menu = UIMenu(title: NSLocalizedString("categorySort_sort", comment: "Sort Images By…"), 
                          image: nil, identifier: menuId,
                          options: UIMenu.Options.displayInline,
                          children: [defaultSortAction(), titleSortAction(),createdSortAction(),
                                     postedSortAction(), ratingSortAction(), visitsSortAction(),
                                     randomSortAction()])
        return menu
    }

    private func defaultSortAction() -> UIAction {
        let actionId = UIAction.Identifier("defaultSort")
        let isActive = AlbumVars.shared.defaultSort == .albumDefault
        let action = UIAction(title: NSLocalizedString("categorySort_default", comment: "Default"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: actionId, handler: { [self] action in
            // Should sorting be changed?
            if isActive { return }
            
            // Change image sorting
            AlbumVars.shared.defaultSort = .albumDefault
            fetchImagesRequest.sortDescriptors = sortDescriptors(for: albumData.imageSort)
            updateCollectionAndMenu()
        })
        action.accessibilityIdentifier = "DefaultSort"
        return action
    }

    private func titleSortAction() -> UIAction {
        var action: UIAction?
        let title = NSLocalizedString("categorySort_name", comment: "Photo Title")
        let actionId = UIAction.Identifier("titleSort")
        switch AlbumVars.shared.defaultSort {
        case .nameAscending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.up"),
                              identifier: actionId, handler: { [self] action in
                AlbumVars.shared.defaultSort = .nameDescending
                fetchImagesRequest.sortDescriptors = sortDescriptors(for: pwgImageSort.nameDescending.param)
                updateCollectionAndMenu()
            })
        case .nameDescending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.down"),
                              identifier: actionId, handler: { [self] action in
                AlbumVars.shared.defaultSort = .nameAscending
                fetchImagesRequest.sortDescriptors = sortDescriptors(for: pwgImageSort.nameAscending.param)
                updateCollectionAndMenu()
            })
        default:
            action = UIAction(title: title, image: nil,
                              identifier: actionId, handler: { [self] action in
                AlbumVars.shared.defaultSort = .nameAscending
                fetchImagesRequest.sortDescriptors = sortDescriptors(for: pwgImageSort.nameAscending.param)
                updateCollectionAndMenu()
            })
        }
        action?.accessibilityIdentifier = "TitleSort"
        return action!
    }

    private func createdSortAction() -> UIAction {
        var action: UIAction?
        let actionId = UIAction.Identifier("createdSort")
        let title = NSLocalizedString("categorySort_dateCreated", comment: "Date Created")
        switch AlbumVars.shared.defaultSort {
        case .dateCreatedAscending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.up"),
                              identifier: actionId, handler: { [self] action in
                AlbumVars.shared.defaultSort = .dateCreatedDescending
                fetchImagesRequest.sortDescriptors = sortDescriptors(for: pwgImageSort.dateCreatedDescending.param)
                updateCollectionAndMenu()
            })
        case .dateCreatedDescending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.down"),
                              identifier: actionId, handler: { [self] action in
                AlbumVars.shared.defaultSort = .dateCreatedAscending
                fetchImagesRequest.sortDescriptors = sortDescriptors(for: pwgImageSort.dateCreatedAscending.param)
                updateCollectionAndMenu()
            })
        default:
            action = UIAction(title: title, image: nil,
                              identifier: actionId, handler: { [self] action in
                AlbumVars.shared.defaultSort = .dateCreatedDescending
                fetchImagesRequest.sortDescriptors = sortDescriptors(for: pwgImageSort.dateCreatedDescending.param)
                updateCollectionAndMenu()
            })
        }
        action?.accessibilityIdentifier = "CreatedSort"
        return action!
    }

    private func postedSortAction() -> UIAction {
        var action: UIAction?
        let actionId = UIAction.Identifier("postedSort")
        let title = NSLocalizedString("categorySort_datePosted", comment: "Date Posted")
        switch AlbumVars.shared.defaultSort {
        case .datePostedAscending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.up"),
                              identifier: actionId, handler: { [self] action in
                AlbumVars.shared.defaultSort = .datePostedDescending
                fetchImagesRequest.sortDescriptors = sortDescriptors(for: pwgImageSort.datePostedDescending.param)
                updateCollectionAndMenu()
            })
        case .datePostedDescending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.down"),
                              identifier: actionId, handler: { [self] action in
                AlbumVars.shared.defaultSort = .datePostedAscending
                fetchImagesRequest.sortDescriptors = sortDescriptors(for: pwgImageSort.datePostedAscending.param)
                updateCollectionAndMenu()
            })
        default:
            action = UIAction(title: title, image: nil,
                              identifier: actionId, handler: { [self] action in
                AlbumVars.shared.defaultSort = .datePostedDescending
                fetchImagesRequest.sortDescriptors = sortDescriptors(for: pwgImageSort.datePostedDescending.param)
                updateCollectionAndMenu()
            })
        }
        action?.accessibilityIdentifier = "PostedSort"
        return action!
    }

    private func ratingSortAction() -> UIAction {
        var action: UIAction?
        let actionId = UIAction.Identifier("ratingSort")
        let title = NSLocalizedString("categorySort_ratingScore", comment: "Rating Score")
        switch AlbumVars.shared.defaultSort {
        case .ratingScoreAscending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.up"),
                              identifier: actionId, handler: { [self] action in
                AlbumVars.shared.defaultSort = .ratingScoreDescending
                fetchImagesRequest.sortDescriptors = sortDescriptors(for: pwgImageSort.ratingScoreDescending.param)
                updateCollectionAndMenu()
            })
        case .ratingScoreDescending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.down"),
                              identifier: actionId, handler: { [self] action in
                AlbumVars.shared.defaultSort = .ratingScoreAscending
                fetchImagesRequest.sortDescriptors = sortDescriptors(for: pwgImageSort.ratingScoreAscending.param)
                updateCollectionAndMenu()
            })
        default:
            action = UIAction(title: title, image: nil,
                              identifier: actionId, handler: { [self] action in
                AlbumVars.shared.defaultSort = .ratingScoreDescending
                fetchImagesRequest.sortDescriptors = sortDescriptors(for: pwgImageSort.ratingScoreDescending.param)
                updateCollectionAndMenu()
            })
        }
        action?.accessibilityIdentifier = "RatingSort"
        return action!
    }

    private func visitsSortAction() -> UIAction {
        var action: UIAction?
        let actionId = UIAction.Identifier("visitsSort")
        let title = NSLocalizedString("categorySort_visits", comment: "Visits")
        switch AlbumVars.shared.defaultSort {
        case .visitsAscending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.up"),
                              identifier: actionId, handler: { [self] action in
                AlbumVars.shared.defaultSort = .visitsDescending
                fetchImagesRequest.sortDescriptors = sortDescriptors(for: pwgImageSort.visitsDescending.param)
                updateCollectionAndMenu()
            })
        case .visitsDescending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.down"),
                              identifier: actionId, handler: { [self] action in
                AlbumVars.shared.defaultSort = .visitsAscending
                fetchImagesRequest.sortDescriptors = sortDescriptors(for: pwgImageSort.visitsAscending.param)
                updateCollectionAndMenu()
            })
        default:
            action = UIAction(title: title, image: nil,
                              identifier: actionId, handler: { [self] action in
                AlbumVars.shared.defaultSort = .visitsDescending
                fetchImagesRequest.sortDescriptors = sortDescriptors(for: pwgImageSort.visitsDescending.param)
                updateCollectionAndMenu()
            })
        }
        action?.accessibilityIdentifier = "VisitsSort"
        return action!
    }

    private func randomSortAction() -> UIAction {
        let actionId = UIAction.Identifier("randomSort")
        let isActive = AlbumVars.shared.defaultSort == .random
        let action = UIAction(title: NSLocalizedString("categorySort_randomly", comment: "Randomly"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: actionId, handler: { [self] action in
            // Change image sorting
            // Should sorting be changed?
            if isActive { return }
            
            // Change image sorting
            AlbumVars.shared.defaultSort = .random
            fetchImagesRequest.sortDescriptors = sortDescriptors(for: pwgImageSort.random.param)
            updateCollectionAndMenu()
        })
        action.accessibilityIdentifier = "RandomSort"
        return action
    }
    
    private func updateCollectionAndMenu() {
        // Re-fetch image
        try? images.performFetch()
        imagesCollection?.reloadData()
        
        // Update menu
        let updatedMenu = selectBarButton?.menu?.replacingChildren([selectMenu(), imageSortMenu()])
        selectBarButton?.menu = updatedMenu
    }
    
    
    // MARK: - Album Menu
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
            // Retrieve complete image data before copying images
            initSelection(beforeAction: .copyImages)
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
            // Retrieve complete image data before moving images
            initSelection(beforeAction: .moveImages)
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
}
