//
//  AlbumViewController+Sort.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

// MARK: - Sort Image
/// - for selecting image sort options
@available(iOS 14, *)
extension AlbumViewController
{
    func imageSortMenu() -> UIMenu {
        let menuId = UIMenu.Identifier("org.piwigo.piwigoImage.sort")
        let menu = UIMenu(title: NSLocalizedString("categorySort_sort", comment: "Sort Images By…"),
                          image: nil, identifier: menuId,
                          options: UIMenu.Options.displayInline,
                          children: [defaultSortAction(), titleSortAction(),
                                     createdSortAction(), postedSortAction(),
                                     ratingSortAction(), visitsSortAction(),
                                     randomSortAction()].compactMap({$0}))
        return menu
    }

    func defaultSortAction() -> UIAction {
        let actionId = UIAction.Identifier("defaultSort")
        let isActive = AlbumVars.shared.defaultSort == .albumDefault
        let action = UIAction(title: NSLocalizedString("categorySort_default", comment: "Default"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: actionId, handler: { [self] action in
            // Should sorting be changed?
            if isActive { return }
            
            // Change image sorting
            AlbumVars.shared.defaultSort = .albumDefault
            let imageSortDescriptors = sortDescriptors(for: albumData.imageSort)
            fetchImagesRequest.sortDescriptors = imageSortDescriptors
            updateCollectionAndMenu()
        })
        action.accessibilityIdentifier = "DefaultSort"
        return action
    }

    func titleSortAction() -> UIAction {
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
    
    func createdSortAction() -> UIAction {
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
    
    func postedSortAction() -> UIAction {
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
    
    func ratingSortAction() -> UIAction {
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
    
    func visitsSortAction() -> UIAction {
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
    
    func randomSortAction() -> UIAction {
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
    
    func updateCollectionAndMenu() {
        // Re-fetch image
        try? images.performFetch()
        collectionView?.reloadData()
        
        // Update menu
        let updatedMenu = selectBarButton?.menu?.replacingChildren([selectMenu(), imageSortMenu()])
        selectBarButton?.menu = updatedMenu
    }
}
