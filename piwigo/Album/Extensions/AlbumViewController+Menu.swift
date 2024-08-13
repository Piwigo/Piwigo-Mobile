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
    // MARK: - Sort/Select Buttons
    func getSortBarButton() -> UIBarButtonItem {
        let button = UIBarButtonItem(image: UIImage(named: "action"), landscapeImagePhone: UIImage(named: "actionCompact"), style: .plain, target: self, action: #selector(didTapSortButton))
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
    @objc func didTapSortButton() {
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
                images.delegate = nil
                images = data.images(sortedBy: .albumDefault)
                images.delegate = self
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
                images.delegate = nil
                images = data.images(sortedBy: .nameDescending)
                images.delegate = self
                updateImageCollection()
            }
        case .nameDescending:
            title += " ↓"
            handler = { [self] action in
                sortOption = .nameAscending
                images.delegate = nil
                images = data.images(sortedBy: .nameAscending)
                images.delegate = self
                updateImageCollection()
            }
        default:
            handler = { [self] action in
                sortOption = .nameAscending
                images.delegate = nil
                images = data.images(sortedBy: .nameAscending)
                images.delegate = self
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
                images.delegate = nil
                images = data.images(sortedBy: .dateCreatedDescending)
                images.delegate = self
                updateImageCollection()
            }
        case .dateCreatedDescending:
            title += " ↓"
            handler = { [self] action in
                sortOption = .dateCreatedAscending
                images.delegate = nil
                images = data.images(sortedBy: .dateCreatedAscending)
                images.delegate = self
                updateImageCollection()
            }
        default:
            handler = { [self] action in
                sortOption = .dateCreatedDescending
                images.delegate = nil
                images = data.images(sortedBy: .dateCreatedDescending)
                images.delegate = self
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
                images.delegate = nil
                images = data.images(sortedBy: .datePostedDescending)
                images.delegate = self
                updateImageCollection()
            }
        case .datePostedDescending:
            title += " ↓"
            handler = { [self] action in
                sortOption = .datePostedAscending
                images.delegate = nil
                images = data.images(sortedBy: .datePostedAscending)
                images.delegate = self
                updateImageCollection()
            }
        default:
            handler = { [self] action in
                sortOption = .datePostedDescending
                images.delegate = nil
                images = data.images(sortedBy: .datePostedDescending)
                images.delegate = self
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
                images.delegate = nil
                images = data.images(sortedBy: .ratingScoreDescending)
                images.delegate = self
                updateImageCollection()
            }
        case .ratingScoreDescending:
            title += " ↓"
            handler = { [self] action in
                sortOption = .ratingScoreAscending
                images.delegate = nil
                images = data.images(sortedBy: .ratingScoreAscending)
                images.delegate = self
                updateImageCollection()
            }
        default:
            handler = { [self] action in
                sortOption = .ratingScoreDescending
                images.delegate = nil
                images = data.images(sortedBy: .ratingScoreDescending)
                images.delegate = self
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
                images.delegate = nil
                images = data.images(sortedBy: .visitsDescending)
                images.delegate = self
                updateImageCollection()
            }
        case .visitsDescending:
            title += " ↓"
            handler = { [self] action in
                sortOption = .visitsAscending
                images.delegate = nil
                images = data.images(sortedBy: .visitsAscending)
                images.delegate = self
                updateImageCollection()
            }
        default:
            handler = { [self] action in
                sortOption = .visitsDescending
                images.delegate = nil
                images = data.images(sortedBy: .visitsDescending)
                images.delegate = self
                updateImageCollection()
            }
        }
        let visitsSortAction = UIAlertAction(title: title, style: .default, handler: handler)
        alert.addAction(visitsSortAction)

        // Sorted manually
        if sortOption != .rankAscending {
            let randomAction = UIAlertAction(title: NSLocalizedString("categorySort_manual", comment: "Manual Order"),
                                             style: .default, handler: { [self] action in
                if let allImages = images.fetchedObjects {
                    allImages.forEach { image in
                        debugPrint("Manual Sort: \(image.pwgID) -> \(image.rankManual == Int64.min ? "Unknown" : "Known")")
                    }
                }
                sortOption = .rankAscending
                images.delegate = nil
                images = data.images(sortedBy: .rankAscending)
                images.delegate = self
                let shouldFetch = images.fetchedObjects?.first(where: {$0.rankManual == Int64.min}) != nil
                updateImageCollection(afterFetchingRanks: shouldFetch)
            })
            alert.addAction(randomAction)
        }

        // Presents photos randomly
        if sortOption != .random {
            let randomAction = UIAlertAction(title: NSLocalizedString("categorySort_randomly", comment: "Randomly"),
                                             style: .default, handler: { [self] action in
                sortOption = .random
                images.delegate = nil
                images = data.images(sortedBy: .random)
                images.delegate = self
                let shouldFetch = images.fetchedObjects?.first(where: {$0.rankRandom == Int64.min}) != nil
                updateImageCollection(afterFetchingRanks: shouldFetch)
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
    
    func updateImageCollection(afterFetchingRanks shouldFetch: Bool = false) {
        if shouldFetch {
            // Some image ranks are unknown and must be retrieved
            startFetchingAlbumAndImages(withHUD: true)
        } else {
            // Re-fetch image collection
            try? images.performFetch()
            collectionView?.reloadData()
        }
    }
}

extension AlbumViewController: ImageHeaderDelegate
{
    func changeImageGrouping(for group: pwgImageGroup) {
        // User changed segmented control choice
        images.delegate = nil
        images = data.images(groupedBy: group)
        images.delegate = self
        updateImageCollection()
    }
    
    func didSelectImagesOfSection(_ section: Int) {
        // Is the selection mode active?
        if isSelect == false {
            // Hide buttons
            hideButtons()
            
            // Activate Images Selection mode
            isSelect = true
            
            // Disable interaction with album cells
            for cell in collectionView?.visibleCells ?? []
            {
                // Disable user interaction with album cell
                if let albumCell = cell as? AlbumCollectionViewCell {
                    albumCell.contentView.alpha = 0.5
                    albumCell.isUserInteractionEnabled = false
                }
                else if let albumCell = cell as? AlbumCollectionViewCellOld {
                    albumCell.contentView.alpha = 0.5
                    albumCell.isUserInteractionEnabled = false
                }
            }
            
            // Initialisae navigation bar and toolbar
            initBarsInSelectMode()
        }
        
        let nberOfImagesInSection = collectionView?.numberOfItems(inSection: section) ?? 0
//        let start = CFAbsoluteTimeGetCurrent()
        if selectedSections[section] == .select {
            // Loop over all images in section to select them
            for item in 0..<nberOfImagesInSection {
                // Retrieve image data
                let imageIndexPath = IndexPath(item: item, section: section - 1)
                let image = images.object(at: imageIndexPath)

                // Is this image already selected?
                if selectedImageIds.contains(image.pwgID) { continue }
                
                // Select this image
                selectedImageIds.insert(image.pwgID)
                let indexPath = IndexPath(item: item, section: section)
                if let cell = collectionView?.cellForItem(at: indexPath) as? ImageCollectionViewCell {
                    cell.isSelection = true
                }
            }
            // Change section button state
            selectedSections[section] = .deselect
        } 
        else {
            // Loop over all images in section to deselect them
            for item in 0..<nberOfImagesInSection {
                // Retrieve image data
                let imageIndexPath = IndexPath(item: item, section: section - 1)
                let image = images.object(at: imageIndexPath)

                // Is this image already deselected?
                if selectedImageIds.contains(image.pwgID) == false { continue }
                
                // Deselect this image
                selectedImageIds.remove(image.pwgID)
                let indexPath = IndexPath(item: item, section: section)
                if let cell = collectionView?.cellForItem(at: indexPath) as? ImageCollectionViewCell {
                    cell.isSelection = false
                }
            }
            
            // Change section button state
            selectedSections[section] = .select
        }
//        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//        print("=> Select/Deselect \(localImagesCollection.numberOfItems(inSection: section)) images of section \(section) took \(diff) ms")
        
        // Update navigation bar and toolbar
        updateBarsInSelectMode()

        // Update button
        collectionView?.indexPathsForVisibleSupplementaryElements(ofKind: UICollectionView.elementKindSectionHeader).forEach { indexPath in
            guard indexPath.section == section ,
                  let sectionState = selectedSections[section]
            else { return }
            if let header = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPath) as? ImageHeaderReusableView {
                header.selectButton.setTitle(forState: sectionState)
            }
            else if let header = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPath) as? ImageOldHeaderReusableView {
                header.selectButton.setTitle(forState: sectionState)
            }
        }
    }
}


@available(iOS 14, *)
extension AlbumViewController
{
    // MARK: - Menu
    func updateCollectionAndMenu(afterFetchingRanks shouldFetch: Bool = false) {
        // Re-fetch image collection
        updateImageCollection(afterFetchingRanks: shouldFetch)
        
        // Update menu
        var children = [UIMenu?]()
        if NetworkVars.userStatus == .guest {
            children = [sortMenu(), viewOptionsMenu()]
        } else {
            children = [selectMenu(), sortMenu(), viewOptionsMenu()]
        }
        let updatedMenu = selectBarButton?.menu?.replacingChildren(children.compactMap({$0}))
        selectBarButton?.menu = updatedMenu
    }
    
    
    // MARK: - Sort Image
    /// - for selecting image sort options
    func sortMenu() -> UIMenu? {
        let menuId = UIMenu.Identifier("org.piwigo.images.sort")
        return UIMenu(title: NSLocalizedString("categorySort_sort", comment: "Sort Images By…"),
                      image: nil, identifier: menuId,
                      options: UIMenu.Options.displayInline,
                      children: [defaultSortAction(), titleSortAction(),
                                 createdSortAction(), postedSortAction(),
                                 ratingSortAction(), visitsSortAction(),
                                 manualSortAction(), randomSortAction()].compactMap({$0}))
    }
    
    func defaultSortAction() -> UIAction? {
        // Unavailable when presenting some smart albums
        let unwantedAlbums = [pwgSmartAlbum.visits.rawValue, pwgSmartAlbum.best.rawValue]
        if unwantedAlbums.contains(categoryId) {
            return nil
        }
        
        let actionId = UIAction.Identifier("org.piwigo.images.sort.default")
        let isActive = sortOption == .albumDefault
        let action = UIAction(title: NSLocalizedString("categorySort_default", comment: "Default"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: actionId, handler: { [self] action in
            // Should sorting be changed?
            if isActive { return }
            
            // Change image sorting
            sortOption = .albumDefault
            images.delegate = nil
            images = data.images(sortedBy: .albumDefault)
            images.delegate = self
            updateCollectionAndMenu()
        })
        action.accessibilityIdentifier = "DefaultSort"
        return action
    }
    
    func titleSortAction() -> UIAction? {
        // Unavailable when presenting some smart albums
        let unwantedAlbums = [pwgSmartAlbum.visits.rawValue, pwgSmartAlbum.best.rawValue]
        if unwantedAlbums.contains(categoryId) {
            return nil
        }
        var action: UIAction?
        let actionId = UIAction.Identifier("org.piwigo.images.sort.title")
        let title = NSLocalizedString("categorySort_name", comment: "Photo Title")
        switch sortOption {
        case .nameAscending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.up"),
                              identifier: actionId, handler: { [self] action in
                sortOption = .nameDescending
                images.delegate = nil
                images = data.images(sortedBy: .nameDescending)
                images.delegate = self
                updateCollectionAndMenu()
            })
        case .nameDescending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.down"),
                              identifier: actionId, handler: { [self] action in
                sortOption = .nameAscending
                images.delegate = nil
                images = data.images(sortedBy: .nameAscending)
                images.delegate = self
                updateCollectionAndMenu()
            })
        default:
            action = UIAction(title: title, image: nil,
                              identifier: actionId, handler: { [self] action in
                sortOption = .nameAscending
                images.delegate = nil
                images = data.images(sortedBy: .nameAscending)
                images.delegate = self
                updateCollectionAndMenu()
            })
        }
        action?.accessibilityIdentifier = "TitleSort"
        return action
    }
    
    func createdSortAction() -> UIAction? {
        // Unavailable when presenting some smart albums
        let unwantedAlbums = [pwgSmartAlbum.visits.rawValue, pwgSmartAlbum.best.rawValue]
        if unwantedAlbums.contains(categoryId) {
            return nil
        }
        
        var action: UIAction?
        let actionId = UIAction.Identifier("org.piwigo.images.sort.created")
        let title = NSLocalizedString("categorySort_dateCreated", comment: "Date Created")
        switch sortOption {
        case .dateCreatedAscending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.up"),
                              identifier: actionId, handler: { [self] action in
                sortOption = .dateCreatedDescending
                images.delegate = nil
                images = data.images(sortedBy: .dateCreatedDescending)
                images.delegate = self
                updateCollectionAndMenu()
            })
        case .dateCreatedDescending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.down"),
                              identifier: actionId, handler: { [self] action in
                sortOption = .dateCreatedAscending
                images.delegate = nil
                images = data.images(sortedBy: .dateCreatedAscending)
                images.delegate = self
                updateCollectionAndMenu()
            })
        default:
            action = UIAction(title: title, image: nil,
                              identifier: actionId, handler: { [self] action in
                sortOption = .dateCreatedDescending
                images.delegate = nil
                images = data.images(sortedBy: .dateCreatedDescending)
                images.delegate = self
                updateCollectionAndMenu()
            })
        }
        action?.accessibilityIdentifier = "CreatedSort"
        return action
    }
    
    func postedSortAction() -> UIAction? {
        // Unavailable when presenting some smart albums
        let unwantedAlbums = [pwgSmartAlbum.visits.rawValue, pwgSmartAlbum.best.rawValue]
        if unwantedAlbums.contains(categoryId) {
            return nil
        }
        
        var action: UIAction?
        let actionId = UIAction.Identifier("org.piwigo.images.sort.posted")
        let title = NSLocalizedString("categorySort_datePosted", comment: "Date Posted")
        switch sortOption {
        case .datePostedAscending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.up"),
                              identifier: actionId, handler: { [self] action in
                sortOption = .datePostedDescending
                images.delegate = nil
                images = data.images(sortedBy: .datePostedDescending)
                images.delegate = self
                updateCollectionAndMenu()
            })
        case .datePostedDescending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.down"),
                              identifier: actionId, handler: { [self] action in
                sortOption = .datePostedAscending
                images.delegate = nil
                images = data.images(sortedBy: .datePostedAscending)
                images.delegate = self
                updateCollectionAndMenu()
            })
        default:
            action = UIAction(title: title, image: nil,
                              identifier: actionId, handler: { [self] action in
                sortOption = .datePostedDescending
                images.delegate = nil
                images = data.images(sortedBy: .datePostedDescending)
                images.delegate = self
                updateCollectionAndMenu()
            })
        }
        action?.accessibilityIdentifier = "PostedSort"
        return action
    }
    
    func ratingSortAction() -> UIAction? {
        // Unavailable when presenting some smart albums
        let unwantedAlbums = [pwgSmartAlbum.visits.rawValue]
        if unwantedAlbums.contains(categoryId) {
            return nil
        }
        
        var action: UIAction?
        let actionId = UIAction.Identifier("org.piwigo.images.sort.rate")
        let title = NSLocalizedString("categorySort_ratingScore", comment: "Rating Score")
        switch sortOption {
        case .ratingScoreAscending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.up"),
                              identifier: actionId, handler: { [self] action in
                sortOption = .ratingScoreDescending
                images.delegate = nil
                images = data.images(sortedBy: .ratingScoreDescending)
                images.delegate = self
                updateCollectionAndMenu()
            })
        case .ratingScoreDescending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.down"),
                              identifier: actionId, handler: { [self] action in
                sortOption = .ratingScoreAscending
                images.delegate = nil
                images = data.images(sortedBy: .ratingScoreAscending)
                images.delegate = self
                updateCollectionAndMenu()
            })
        default:
            action = UIAction(title: title, image: nil,
                              identifier: actionId, handler: { [self] action in
                sortOption = .ratingScoreDescending
                images.delegate = nil
                images = data.images(sortedBy: .ratingScoreDescending)
                images.delegate = self
                updateCollectionAndMenu()
            })
        }
        action?.accessibilityIdentifier = "RatingSort"
        return action
    }
    
    func visitsSortAction() -> UIAction? {
        // Unavailable when presenting some smart albums
        let unwantedAlbums = [pwgSmartAlbum.best.rawValue]
        if unwantedAlbums.contains(categoryId) {
            return nil
        }
        
        var action: UIAction?
        let actionId = UIAction.Identifier("org.piwigo.images.sort.visits")
        let title = NSLocalizedString("categorySort_visits", comment: "Visits")
        switch sortOption {
        case .visitsAscending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.up"),
                              identifier: actionId, handler: { [self] action in
                sortOption = .visitsDescending
                images.delegate = nil
                images = data.images(sortedBy: .visitsDescending)
                images.delegate = self
                updateCollectionAndMenu()
            })
        case .visitsDescending:
            action = UIAction(title: title, image: UIImage(systemName: "arrow.down"),
                              identifier: actionId, handler: { [self] action in
                sortOption = .visitsAscending
                images.delegate = nil
                images = data.images(sortedBy: .visitsAscending)
                images.delegate = self
                updateCollectionAndMenu()
            })
        default:
            action = UIAction(title: title, image: nil,
                              identifier: actionId, handler: { [self] action in
                sortOption = .visitsDescending
                images.delegate = nil
                images = data.images(sortedBy: .visitsDescending)
                images.delegate = self
                updateCollectionAndMenu()
            })
        }
        action?.accessibilityIdentifier = "VisitsSort"
        return action
    }
    
    func manualSortAction() -> UIAction? {
        // Unavailable when presenting some smart albums
        let unwantedAlbums = [pwgSmartAlbum.visits.rawValue, pwgSmartAlbum.best.rawValue]
        if unwantedAlbums.contains(categoryId) {
            return nil
        }
        
        let actionId = UIAction.Identifier("org.piwigo.images.sort.manual")
        let isActive = sortOption == .rankAscending
        let action = UIAction(title: NSLocalizedString("categorySort_manual", comment: "Manual Order"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: actionId, handler: { [self] action in
            // Should sorting be changed?
            if isActive { return }
            
            // Change image sorting
            sortOption = .rankAscending
            images.delegate = nil
            images = data.images(sortedBy: .rankAscending)
            images.delegate = self
            let shouldFetch = images.fetchedObjects?.first(where: {$0.rankManual == Int64.min}) != nil
            updateCollectionAndMenu(afterFetchingRanks: shouldFetch)
        })
        action.accessibilityIdentifier = "ManualSort"
        return action
    }

    func randomSortAction() -> UIAction? {
        // Unavailable when presenting some smart albums
        let unwantedAlbums = [pwgSmartAlbum.visits.rawValue, pwgSmartAlbum.best.rawValue]
        if unwantedAlbums.contains(categoryId) {
            return nil
        }
        
        let actionId = UIAction.Identifier("org.piwigo.images.sort.random")
        let isActive = sortOption == .random
        let action = UIAction(title: NSLocalizedString("categorySort_randomly", comment: "Randomly"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: actionId, handler: { [self] action in
            // Should sorting be changed?
            if isActive { return }
            
            // Change image sorting
            sortOption = .random
            images.delegate = nil
            images = data.images(sortedBy: .random)
            images.delegate = self
            let shouldFetch = images.fetchedObjects?.first(where: {$0.rankRandom == Int64.min}) != nil
            updateCollectionAndMenu(afterFetchingRanks: shouldFetch)
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
                      children: [groupMenu(), showMenu()].compactMap({$0}))
    }
    
    func groupMenu() -> UIMenu? {
        // Only available when images are sorted by date
        guard categoryId != Int32.zero,
              let sortKey = images.fetchRequest.sortDescriptors?.first?.key,
              [#keyPath(Image.dateCreated), #keyPath(Image.datePosted)].contains(sortKey)
        else { return nil }
        
        // Create a menu for selecting how to group images
        let children = [byDayAction(), byWeekAction(), byMonthAction(), byNoneAction()].compactMap({$0})
        return UIMenu(title: NSLocalizedString("categoryView_group", comment: "Group Images By…"),
                      image: nil,
                      identifier: UIMenu.Identifier("org.piwigo.images.group.main"),
                      options: UIMenu.Options.displayInline,
                      children: children)
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
            images.delegate = nil
            images = data.images(groupedBy: .day)
            images.delegate = self
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
            images.delegate = nil
            images = data.images(groupedBy: .week)
            images.delegate = self
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
            images.delegate = nil
            images = data.images(groupedBy: .month)
            images.delegate = self
            updateCollectionAndMenu()
        })
        action.accessibilityIdentifier = "groupByMonth"
        return action
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
            images.delegate = nil
            images = data.images(groupedBy: .none)
            images.delegate = self
            updateCollectionAndMenu()
        })
        action.accessibilityIdentifier = "groupByNone"
        return action
    }
    
    func showMenu() -> UIMenu? {
        // Create a menu for selecting what to show
        let children = [showHideDescriptionsAction(), showHideTitlesAction()].compactMap({$0})
        return UIMenu(title: NSLocalizedString("categoryView_show", comment: "Show…"),
                      image: nil,
                      identifier: UIMenu.Identifier("org.piwigo.images.show.main"),
                      options: UIMenu.Options.displayInline,
                      children: children)
    }
    
    func showHideDescriptionsAction() -> UIAction? {
        let isActive = AlbumVars.shared.displayAlbumDescriptions
        let action = UIAction(title: NSLocalizedString("settings_displayDescriptions", comment: "Album Descriptions"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: UIAction.Identifier("org.piwigo.images.show.descriptions"),
                              handler: { [self] action in
            // Show or hide album descriptions
            AlbumVars.shared.displayAlbumDescriptions = !isActive
            let cellSize = getAlbumCellSize()
            (navigationController?.viewControllers ?? []).forEach({ viewController in
                if let albumVC = viewController as? AlbumViewController {
                    albumVC.albumCellSize = cellSize
                    albumVC.collectionView?.reloadData()
                }
            })
            if categoryId == Int32.zero {
                let children = [smartAlbums(), viewOptionsMenu()].compactMap({$0})
                let updatedMenu = discoverBarButton.menu?.replacingChildren(children)
                discoverBarButton.menu = updatedMenu
            } else {
                updateCollectionAndMenu()
            }
        })
        action.accessibilityIdentifier = "showHideAlbumDescriptions"
        return action
    }

    func showHideTitlesAction() -> UIAction? {
        // Don't present this option in root album
        if categoryId == Int32.zero {
            return nil
        }
        
        let isActive = AlbumVars.shared.displayImageTitles
        let action = UIAction(title: NSLocalizedString("settings_displayTitles", comment: "Image Titles"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: UIAction.Identifier("org.piwigo.images.show.titles"),
                              handler: { [self] action in
            // Show or hide image titles
            AlbumVars.shared.displayImageTitles = !isActive
            updateCollectionAndMenu()
        })
        action.accessibilityIdentifier = "showHideImageTitles"
        return action
    }
}
