//
//  AlbumViewController+Menu.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

extension AlbumViewController
{
    // MARK: - Action/Select Buttons
    func getActionBarButton() -> UIBarButtonItem {
        let button = UIBarButtonItem(image: UIImage(named: "action"), landscapeImagePhone: UIImage(named: "actionCompact"), style: .plain, target: self, action: #selector(didTapActionButton))
        button.accessibilityIdentifier = "Action"
        return button
    }
    
    func getSelectBarButton() -> UIBarButtonItem {
        let button = UIBarButtonItem(title: NSLocalizedString("categoryImageList_selectButton", comment: "Select"), style: .plain, target: self, action: #selector(didTapSelect))
        button.accessibilityIdentifier = "Select"
        return button
    }
    
    
    // MARK: - Sort Image
    /// - for selecting image sort options
    @objc func didTapActionButton() {
        let alert = UIAlertController(title: NSLocalizedString("categorySort_sort", comment: "Sort Images By…"),
                                      message: nil, preferredStyle: .actionSheet)
        
        // Cancel action
        let cancelAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
                                         style: .cancel, handler: { action in })
        alert.addAction(cancelAction)
        
        // Default sort option
        if sortOption != .albumDefault {
            let title = NSLocalizedString("categorySort_default", comment: "Default")
            let defaultSortAction = UIAlertAction(title: title, style: .default) { [self] _ in
                sortOption = .albumDefault
                images = data.images(sortedBy: .albumDefault, groupedBy: .none)
                updateImageCollection()
            }
            alert.addAction(defaultSortAction)
        }
        
        // Sorting by title
        var title = NSLocalizedString("categorySort_name", comment: "Photo Title")
        var handler: ((UIAlertAction) -> Void)? = nil
        switch sortOption {
        case .nameAscending:
            title += " ↑"
            handler = { [self] action in
                sortOption = .nameDescending
                images = data.images(sortedBy: .nameDescending, groupedBy: .none)
                updateImageCollection()
            }
        case .nameDescending:
            title += " ↓"
            handler = { [self] action in
                sortOption = .nameAscending
                images = data.images(sortedBy: .nameAscending, groupedBy: .none)
                updateImageCollection()
            }
        default:
            handler = { [self] action in
                sortOption = .nameAscending
                images = data.images(sortedBy: .nameAscending, groupedBy: .none)
                updateImageCollection()
            }
        }
        let titleSortAction = UIAlertAction(title: title, style: .default, handler: handler)
        alert.addAction(titleSortAction)
        
        // Sorting by date created
        title = NSLocalizedString("categorySort_dateCreated", comment: "Date Created")
        switch sortOption {
        case .dateCreatedAscending:
            title += " ↑"
            handler = { [self] action in
                sortOption = .dateCreatedDescending
                images = data.images(sortedBy: .dateCreatedDescending, groupedBy: AlbumVars.shared.defaultGroup)
                updateImageCollection()
            }
        case .dateCreatedDescending:
            title += " ↓"
            handler = { [self] action in
                sortOption = .dateCreatedAscending
                images = data.images(sortedBy: .dateCreatedAscending, groupedBy: AlbumVars.shared.defaultGroup)
                updateImageCollection()
            }
        default:
            handler = { [self] action in
                sortOption = .dateCreatedDescending
                images = data.images(sortedBy: .dateCreatedDescending, groupedBy: AlbumVars.shared.defaultGroup)
                updateImageCollection()
            }
        }
        let dateCreatedAction = UIAlertAction(title: title, style: .default, handler: handler)
        alert.addAction(dateCreatedAction)
        
        // Sorting by date posted
        title = NSLocalizedString("categorySort_datePosted", comment: "Date Posted")
        switch sortOption {
        case .datePostedAscending:
            title += " ↑"
            handler = { [self] action in
                sortOption = .datePostedDescending
                images = data.images(sortedBy: .datePostedDescending, groupedBy: AlbumVars.shared.defaultGroup)
                updateImageCollection()
            }
        case .datePostedDescending:
            title += " ↓"
            handler = { [self] action in
                sortOption = .datePostedAscending
                images = data.images(sortedBy: .datePostedAscending, groupedBy: AlbumVars.shared.defaultGroup)
                updateImageCollection()
            }
        default:
            handler = { [self] action in
                sortOption = .datePostedDescending
                images = data.images(sortedBy: .datePostedDescending, groupedBy: AlbumVars.shared.defaultGroup)
                updateImageCollection()
            }
        }
        let postedSortAction =  UIAlertAction(title: title, style: .default, handler: handler)
        alert.addAction(postedSortAction)
        
        // Sorting by rate
        title = NSLocalizedString("categorySort_ratingScore", comment: "Rating Score")
        switch sortOption {
        case .ratingScoreAscending:
            title += " ↑"
            handler = { [self] action in
                sortOption = .ratingScoreDescending
                images = data.images(sortedBy: .ratingScoreDescending, groupedBy: AlbumVars.shared.defaultGroup)
                updateImageCollection()
            }
        case .ratingScoreDescending:
            title += " ↓"
            handler = { [self] action in
                sortOption = .ratingScoreAscending
                images = data.images(sortedBy: .ratingScoreAscending, groupedBy: AlbumVars.shared.defaultGroup)
                updateImageCollection()
            }
        default:
            handler = { [self] action in
                sortOption = .ratingScoreDescending
                images = data.images(sortedBy: .ratingScoreDescending, groupedBy: AlbumVars.shared.defaultGroup)
                updateImageCollection()
            }
        }
        let ratingSortAction = UIAlertAction(title: title, style: .default, handler: handler)
        alert.addAction(ratingSortAction)

        // Sorted by number of visits
        title = NSLocalizedString("categorySort_visits", comment: "Visits")
        switch sortOption {
        case .visitsAscending:
            title += " ↑"
            handler = { [self] action in
                sortOption = .visitsDescending
                images = data.images(sortedBy: .visitsDescending, groupedBy: AlbumVars.shared.defaultGroup)
                updateImageCollection()
            }
        case .visitsDescending:
            title += " ↓"
            handler = { [self] action in
                sortOption = .visitsAscending
                images = data.images(sortedBy: .visitsAscending, groupedBy: AlbumVars.shared.defaultGroup)
                updateImageCollection()
            }
        default:
            handler = { [self] action in
                sortOption = .visitsDescending
                images = data.images(sortedBy: .visitsDescending, groupedBy: AlbumVars.shared.defaultGroup)
                updateImageCollection()
            }
        }
        let visitsSortAction = UIAlertAction(title: title, style: .default, handler: handler)
        alert.addAction(visitsSortAction)

        // Presents photos randomly
        if sortOption != .random {
            let randomAction = UIAlertAction(title: NSLocalizedString("categorySort_randomly", comment: "Randomly"),
                                             style: .default, handler: { [self] action in
                sortOption = .random
                images = data.images(sortedBy: .random, groupedBy: AlbumVars.shared.defaultGroup)
                updateImageCollection()
            })
            alert.addAction(randomAction)
        }

        // Present list of actions
        alert.view.tintColor = .piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        alert.popoverPresentationController?.barButtonItem = actionBarButton
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = .piwigoColorOrange()
        }
    }
    
    func updateImageCollection() {
        // Re-fetch image collection
        try? images.performFetch()
        collectionView?.reloadData()
    }
}

extension AlbumViewController: ImageHeaderDelegate
{
    func changeImageGrouping(for group: pwgImageGroup) {
        // User changed segmented control choice
        images = data.images(groupedBy: group)
        updateImageCollection()
    }
}


@available(iOS 14, *)
extension AlbumViewController
{
    // MARK: - Menu
    func actionMenu() -> UIMenu {
        return UIMenu(title: "", children: [selectMenu(), sortMenu(), viewOptionsMenu()].compactMap({$0}))
    }
    
    func updateCollectionAndMenu() {
        // Re-fetch image collection
        updateImageCollection()

        // Update menu
        let children = [selectMenu(), sortMenu(), viewOptionsMenu()].compactMap({$0})
        let updatedMenu = selectBarButton?.menu?.replacingChildren(children)
        selectBarButton?.menu = updatedMenu
    }
    
    
    // MARK: - Sort Image
    /// - for selecting image sort options
    func sortMenu() -> UIMenu? {
        // The menu is not available for all smart albums
        let validSmartAlbums: [Int32] = [pwgSmartAlbum.search.rawValue,
                                         pwgSmartAlbum.favorites.rawValue,
                                         pwgSmartAlbum.tagged.rawValue,
                                         pwgSmartAlbum.recent.rawValue]
        if categoryId <= 0, validSmartAlbums.contains(categoryId) == false {
            return nil
        }
        
        // Create a menu for selecting how to sort images
        let menuId = UIMenu.Identifier("org.piwigo.images.sort")
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
        let actionId = UIAction.Identifier("org.piwigo.images.sort.default")
        let isActive = sortOption == .albumDefault
        let action = UIAction(title: NSLocalizedString("categorySort_default", comment: "Default"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: actionId, handler: { [self] action in
            // Should sorting be changed?
            if isActive { return }
            
            // Change image sorting
            sortOption = .albumDefault
            images = data.images(sortedBy: .albumDefault, groupedBy: .none)
            updateCollectionAndMenu()
        })
        action.accessibilityIdentifier = "DefaultSort"
        return action
    }
    
    func titleSortAction() -> UIAction? {
        var action: UIAction?
        let actionId = UIAction.Identifier("org.piwigo.images.sort.title")
        let title = NSLocalizedString("categorySort_name", comment: "Photo Title")
        switch sortOption {
        case .nameAscending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.up"),
                              identifier: actionId, handler: { [self] action in
                sortOption = .nameDescending
                images = data.images(sortedBy: .nameDescending, groupedBy: .none)
                updateCollectionAndMenu()
            })
        case .nameDescending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.down"),
                              identifier: actionId, handler: { [self] action in
                sortOption = .nameAscending
                images = data.images(sortedBy: .nameAscending, groupedBy: .none)
                updateCollectionAndMenu()
            })
        default:
            action = UIAction(title: title, image: nil,
                              identifier: actionId, handler: { [self] action in
                sortOption = .nameAscending
                images = data.images(sortedBy: .nameAscending, groupedBy: .none)
                updateCollectionAndMenu()
            })
        }
        action?.accessibilityIdentifier = "TitleSort"
        return action
    }
    
    func createdSortAction() -> UIAction? {
        var action: UIAction?
        let actionId = UIAction.Identifier("org.piwigo.images.sort.created")
        let title = NSLocalizedString("categorySort_dateCreated", comment: "Date Created")
        switch sortOption {
        case .dateCreatedAscending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.up"),
                              identifier: actionId, handler: { [self] action in
                sortOption = .dateCreatedDescending
                images = data.images(sortedBy: .dateCreatedDescending, groupedBy: AlbumVars.shared.defaultGroup)
                updateCollectionAndMenu()
            })
        case .dateCreatedDescending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.down"),
                              identifier: actionId, handler: { [self] action in
                sortOption = .dateCreatedAscending
                images = data.images(sortedBy: .dateCreatedAscending, groupedBy: AlbumVars.shared.defaultGroup)
                updateCollectionAndMenu()
            })
        default:
            action = UIAction(title: title, image: nil,
                              identifier: actionId, handler: { [self] action in
                sortOption = .dateCreatedDescending
                images = data.images(sortedBy: .dateCreatedDescending, groupedBy: AlbumVars.shared.defaultGroup)
                updateCollectionAndMenu()
            })
        }
        action?.accessibilityIdentifier = "CreatedSort"
        return action
    }
    
    func postedSortAction() -> UIAction? {
        var action: UIAction?
        let actionId = UIAction.Identifier("org.piwigo.images.sort.posted")
        let title = NSLocalizedString("categorySort_datePosted", comment: "Date Posted")
        switch sortOption {
        case .datePostedAscending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.up"),
                              identifier: actionId, handler: { [self] action in
                sortOption = .datePostedDescending
                images = data.images(sortedBy: .datePostedDescending, groupedBy: AlbumVars.shared.defaultGroup)
                updateCollectionAndMenu()
            })
        case .datePostedDescending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.down"),
                              identifier: actionId, handler: { [self] action in
                sortOption = .datePostedAscending
                images = data.images(sortedBy: .datePostedAscending, groupedBy: AlbumVars.shared.defaultGroup)
                updateCollectionAndMenu()
            })
        default:
            action = UIAction(title: title, image: nil,
                              identifier: actionId, handler: { [self] action in
                sortOption = .datePostedDescending
                images = data.images(sortedBy: .datePostedDescending, groupedBy: AlbumVars.shared.defaultGroup)
                updateCollectionAndMenu()
            })
        }
        action?.accessibilityIdentifier = "PostedSort"
        return action
    }
    
    func ratingSortAction() -> UIAction? {
        var action: UIAction?
        let actionId = UIAction.Identifier("org.piwigo.images.sort.rate")
        let title = NSLocalizedString("categorySort_ratingScore", comment: "Rating Score")
        switch sortOption {
        case .ratingScoreAscending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.up"),
                              identifier: actionId, handler: { [self] action in
                sortOption = .ratingScoreDescending
                images = data.images(sortedBy: .ratingScoreDescending, groupedBy: AlbumVars.shared.defaultGroup)
                updateCollectionAndMenu()
            })
        case .ratingScoreDescending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.down"),
                              identifier: actionId, handler: { [self] action in
                sortOption = .ratingScoreAscending
                images = data.images(sortedBy: .ratingScoreAscending, groupedBy: AlbumVars.shared.defaultGroup)
                updateCollectionAndMenu()
            })
        default:
            action = UIAction(title: title, image: nil,
                              identifier: actionId, handler: { [self] action in
                sortOption = .ratingScoreDescending
                images = data.images(sortedBy: .ratingScoreDescending, groupedBy: AlbumVars.shared.defaultGroup)
                updateCollectionAndMenu()
            })
        }
        action?.accessibilityIdentifier = "RatingSort"
        return action
    }
    
    func visitsSortAction() -> UIAction? {
        var action: UIAction?
        let actionId = UIAction.Identifier("org.piwigo.images.sort.visits")
        let title = NSLocalizedString("categorySort_visits", comment: "Visits")
        switch sortOption {
        case .visitsAscending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.up"),
                              identifier: actionId, handler: { [self] action in
                sortOption = .visitsDescending
                images = data.images(sortedBy: .visitsDescending, groupedBy: AlbumVars.shared.defaultGroup)
                updateCollectionAndMenu()
            })
        case .visitsDescending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.down"),
                              identifier: actionId, handler: { [self] action in
                sortOption = .visitsAscending
                images = data.images(sortedBy: .visitsAscending, groupedBy: AlbumVars.shared.defaultGroup)
                updateCollectionAndMenu()
            })
        default:
            action = UIAction(title: title, image: nil,
                              identifier: actionId, handler: { [self] action in
                sortOption = .visitsDescending
                images = data.images(sortedBy: .visitsDescending, groupedBy: AlbumVars.shared.defaultGroup)
                updateCollectionAndMenu()
            })
        }
        action?.accessibilityIdentifier = "VisitsSort"
        return action
    }
    
    func randomSortAction() -> UIAction? {
        let actionId = UIAction.Identifier("org.piwigo.images.sort.random")
        let isActive = sortOption == .random
        let action = UIAction(title: NSLocalizedString("categorySort_randomly", comment: "Randomly"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: actionId, handler: { [self] action in
            // Should sorting be changed?
            if isActive { return }
            
            // Change image sorting
            sortOption = .random
            images = data.images(sortedBy: .random, groupedBy: AlbumVars.shared.defaultGroup)
            updateCollectionAndMenu()
        })
        action.accessibilityIdentifier = "RandomSort"
        return action
    }
        
    
    // MARK: - View Options
    /// - for choosing how to group images
    func viewOptionsMenu() -> UIMenu {
        return UIMenu(title: NSLocalizedString("categoryView_options", comment: "View Options"),
                      image: nil,
                      identifier: UIMenu.Identifier("org.piwigo.view.options"),
                      children: [groupMenu(), showHideTitlesAction()].compactMap({$0}))
    }
    
    func groupMenu() -> UIMenu? {
        // Only available when images are sorted by date
        let validSortTypes: [pwgImageSort] = [.datePostedAscending, .datePostedDescending,
                                              .dateCreatedAscending, .dateCreatedDescending]
        if validSortTypes.contains(sortOption) == false {
            return nil
        }

        // Create a menu for selecting how to group images
        let children = [byNoneAction(), byDayAction(), byWeekAction(), byMonthAction()].compactMap({$0})
        return UIMenu(title: NSLocalizedString("categoryGroup_group", comment: "Group Images By…"),
                      image: nil,
                      identifier: UIMenu.Identifier("org.piwigo.images.group.main"),
                      options: UIMenu.Options.displayInline,
                      children: children)
    }
    
    func byNoneAction() -> UIAction? {
        let isActive = AlbumVars.shared.defaultGroup == .none
        let action = UIAction(title: NSLocalizedString("None", comment: "None"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: UIAction.Identifier("org.piwigo.images.group.none"),
                              handler: { [self] action in
            // Should image grouping be changed?
            if isActive { return }
            
            // Change image grouping
            images = data.images(groupedBy: .none)
            updateCollectionAndMenu()
        })
        action.accessibilityIdentifier = "groupByNone"
        return action
    }
    
    func byDayAction() -> UIAction? {
        let isActive = AlbumVars.shared.defaultGroup == .day
        let action = UIAction(title: NSLocalizedString("Day", comment: "Day"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: UIAction.Identifier("org.piwigo.images.group.day"),
                              handler: { [self] action in
            // Should image grouping be changed?
            if isActive { return }
            
            // Change image grouping
            images = data.images(groupedBy: .day)
            updateCollectionAndMenu()
        })
        action.accessibilityIdentifier = "groupByDay"
        return action
    }
    
    func byWeekAction() -> UIAction? {
        let isActive = AlbumVars.shared.defaultGroup == .week
        let action = UIAction(title: NSLocalizedString("Week", comment: "Week"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: UIAction.Identifier("org.piwigo.images.group.week"),
                              handler: { [self] action in
            // Should image grouping be changed?
            if isActive { return }
            
            // Change image grouping
            images = data.images(groupedBy: .week)
            updateCollectionAndMenu()
        })
        action.accessibilityIdentifier = "groupByWeek"
        return action
    }
    
    func byMonthAction() -> UIAction? {
        let isActive = AlbumVars.shared.defaultGroup == .month
        let action = UIAction(title: NSLocalizedString("Month", comment: "Month"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: UIAction.Identifier("org.piwigo.images.group.month"),
                              handler: { [self] action in
            // Should sorting be changed?
            if isActive { return }
            
            // Should image grouping be changed?
            images = data.images(groupedBy: .month)
            updateCollectionAndMenu()
        })
        action.accessibilityIdentifier = "groupByMonth"
        return action
    }
    
    func showHideTitlesAction() -> UIAction {
        let isActive = AlbumVars.shared.displayImageTitles
        let action = UIAction(title: NSLocalizedString("settings_displayTitles", comment: "Titles on Thumbnails"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: UIAction.Identifier("org.piwigo.images.show.titles"),
                              handler: { [self] action in
            // Show or hide image titles?
            AlbumVars.shared.displayImageTitles = !isActive
            updateCollectionAndMenu()
        })
        action.accessibilityIdentifier = "showHideImageTitles"
        return action
    }
}
