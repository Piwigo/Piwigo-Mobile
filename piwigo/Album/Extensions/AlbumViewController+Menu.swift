//
//  AlbumViewController+Menu.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import PwgKit
import PwgAPIKit
import PwgCacheKit
import PwgUIKit

// MARK: - Contextual Menu
extension AlbumViewController {
    
    // MARK: - Update Collection & Menu
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

    func updateCollectionAndMenu(afterFetchingRanks shouldFetch: Bool = false) {
        // Re-fetch image collection
        updateImageCollection(afterFetchingRanks: shouldFetch)
        
        // Update menu
        // Not all users can select/deselect images
        var children = [UIMenuElement?]()
        if userData.canDownloadImages() || userData.canManageFavorites() || userData.hasUploadRights(forCatID: categoryId) {
            children = [selectMenu(enabled: albumData.nbImages != 0),
                        shareAlbumMenu(forAlbumWithID: categoryId), viewOptionsMenu()]
        } else {
            children = [shareAlbumMenu(forAlbumWithID: categoryId), viewOptionsMenu()]
        }
        let updatedMenu = selectBarButton?.menu?.replacingChildren(children.compactMap({$0}))
        selectBarButton?.menu = updatedMenu
    }
    
    
    // MARK: - Sort Image
    /// - for selecting image sort options
    func sortMenu() -> UIMenu? {
        let options: UIMenu.Options = [.singleSelection]
        let menuId = UIMenu.Identifier("org.piwigo.images.sort")
        return UIMenu(title: String(localized: "categorySort_sort", comment: "Sort Images By…"),
                      image: nil, identifier: menuId,
                      options: options,
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
        let action = UIAction(title: pwgImageSort.albumDefault.name,
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: actionId, handler: { [weak self] action in
            guard let self else { return }
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
        let title = String(localized: "categorySort_name", comment: "Photo Title")
        switch sortOption {
        case .nameAscending:
            action = UIAction(title: title, subtitle: sortOption.shortName,
                              image: UIImage(systemName: "checkmark"),
                              identifier: actionId, handler: { [weak self] action in
                guard let self else { return }
                sortOption = .nameDescending
                images.delegate = nil
                images = data.images(sortedBy: .nameDescending)
                images.delegate = self
                updateCollectionAndMenu()
            })
        case .nameDescending:
            action = UIAction(title: title, subtitle: sortOption.shortName,
                              image: UIImage(systemName: "checkmark"),
                              identifier: actionId, handler: { [weak self] action in
                guard let self else { return }
                sortOption = .nameAscending
                images.delegate = nil
                images = data.images(sortedBy: .nameAscending)
                images.delegate = self
                updateCollectionAndMenu()
            })
        default:
            action = UIAction(title: title, subtitle: nil, image: nil,
                              identifier: actionId, handler: { [weak self] action in
                guard let self else { return }
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
        let title = String(localized: "categorySort_dateCreated", comment: "Date Created")
        switch sortOption {
        case .dateCreatedAscending:
            action = UIAction(title: title, subtitle: sortOption.shortName,
                              image: UIImage(systemName: "checkmark"),
                              identifier: actionId, handler: { [weak self] action in
                guard let self else { return }
                sortOption = .dateCreatedDescending
                images.delegate = nil
                images = data.images(sortedBy: .dateCreatedDescending)
                images.delegate = self
                updateCollectionAndMenu()
            })
        case .dateCreatedDescending:
            action = UIAction(title: title, subtitle: sortOption.shortName,
                              image: UIImage(systemName: "checkmark"),
                              identifier: actionId, handler: { [weak self] action in
                guard let self else { return }
                sortOption = .dateCreatedAscending
                images.delegate = nil
                images = data.images(sortedBy: .dateCreatedAscending)
                images.delegate = self
                updateCollectionAndMenu()
            })
        default:
            action = UIAction(title: title, subtitle: nil, image: nil,
                              identifier: actionId, handler: { [weak self] action in
                guard let self else { return }
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
        let title = String(localized: "categorySort_datePosted", comment: "Date Posted")
        switch sortOption {
        case .datePostedAscending:
            action = UIAction(title: title, subtitle: sortOption.shortName,
                              image: UIImage(systemName: "checkmark"),
                              identifier: actionId, handler: { [weak self] action in
                guard let self else { return }
                sortOption = .datePostedDescending
                images.delegate = nil
                images = data.images(sortedBy: .datePostedDescending)
                images.delegate = self
                updateCollectionAndMenu()
            })
        case .datePostedDescending:
            action = UIAction(title: title, subtitle: sortOption.shortName,
                              image: UIImage(systemName: "checkmark"),
                              identifier: actionId, handler: { [weak self] action in
                guard let self else { return }
                sortOption = .datePostedAscending
                images.delegate = nil
                images = data.images(sortedBy: .datePostedAscending)
                images.delegate = self
                updateCollectionAndMenu()
            })
        default:
            action = UIAction(title: title, subtitle: nil, image: nil,
                              identifier: actionId, handler: { [weak self] action in
                guard let self else { return }
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
        let title = String(localized: "categorySort_ratingScore", comment: "Rating Score")
        switch sortOption {
        case .ratingScoreAscending:
            action = UIAction(title: title, subtitle: sortOption.shortName,
                              image: UIImage(systemName: "checkmark"),
                              identifier: actionId, handler: { [weak self] action in
                guard let self else { return }
                sortOption = .ratingScoreDescending
                images.delegate = nil
                images = data.images(sortedBy: .ratingScoreDescending)
                images.delegate = self
                updateCollectionAndMenu()
            })
        case .ratingScoreDescending:
            action = UIAction(title: title, subtitle: sortOption.shortName,
                              image: UIImage(systemName: "checkmark"),
                              identifier: actionId, handler: { [weak self] action in
                guard let self else { return }
                sortOption = .ratingScoreAscending
                images.delegate = nil
                images = data.images(sortedBy: .ratingScoreAscending)
                images.delegate = self
                updateCollectionAndMenu()
            })
        default:
            action = UIAction(title: title, subtitle: nil, image: nil,
                              identifier: actionId, handler: { [weak self] action in
                guard let self else { return }
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
        let title = String(localized: "categorySort_visits", comment: "Visits")
        switch sortOption {
        case .visitsAscending:
            action = UIAction(title: title, subtitle: sortOption.shortName,
                              image: UIImage(systemName: "checkmark"),
                              identifier: actionId, handler: { [weak self] action in
                guard let self else { return }
                sortOption = .visitsDescending
                images.delegate = nil
                images = data.images(sortedBy: .visitsDescending)
                images.delegate = self
                updateCollectionAndMenu()
            })
        case .visitsDescending:
            action = UIAction(title: title, subtitle: sortOption.shortName,
                              image: UIImage(systemName: "checkmark"),
                              identifier: actionId, handler: { [weak self] action in
                guard let self else { return }
                sortOption = .visitsAscending
                images.delegate = nil
                images = data.images(sortedBy: .visitsAscending)
                images.delegate = self
                updateCollectionAndMenu()
            })
        default:
            action = UIAction(title: title, subtitle: nil, image: nil,
                              identifier: actionId, handler: { [weak self] action in
                guard let self else { return }
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
        let action = UIAction(title: pwgImageSort.rankAscending.name,
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: actionId, handler: { [weak self] action in
            guard let self else { return }
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
        let action = UIAction(title: String(localized: "categorySort_randomly", comment: "Randomly"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: actionId, handler: { [weak self] action in
            guard let self else { return }
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
        return UIMenu(title: String(localized: "categoryView_options", comment: "View Options"),
                      image: nil,
                      identifier: UIMenu.Identifier("org.piwigo.view.options"),
                      children: [sortMenu(), groupMenu(), showMenu()].compactMap({$0}))
    }
    
    func groupMenu() -> UIMenu? {
        // Only available when images are sorted by date
        guard let sortKey = images.fetchRequest.sortDescriptors?.first?.key,
              [#keyPath(Image.dateCreated), #keyPath(Image.datePosted)].contains(sortKey)
        else { return nil }
        
        // Create a menu for selecting how to group images
        let options: UIMenu.Options = [.singleSelection]
        let children = [byDayAction(), byWeekAction(), byMonthAction(), byNoneAction()].compactMap({$0})
        return UIMenu(title: String(localized: "categoryView_group", comment: "Group Images By…"),
                      image: nil,
                      identifier: UIMenu.Identifier("org.piwigo.images.group.main"),
                      options: options,
                      children: children)
    }
    
    func byDayAction() -> UIAction? {
        let isActive = AlbumVars.shared.defaultGroup == .day
        let action = UIAction(title: String(localized: "Day", comment: "Day"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: UIAction.Identifier("org.piwigo.images.group.day"),
                              handler: { [weak self] action in
            guard let self else { return }
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
        let action = UIAction(title: String(localized: "Week", comment: "Week"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: UIAction.Identifier("org.piwigo.images.group.week"),
                              handler: { [weak self] action in
            guard let self else { return }
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
        let action = UIAction(title: String(localized: "Month", comment: "Month"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: UIAction.Identifier("org.piwigo.images.group.month"),
                              handler: { [weak self] action in
            guard let self else { return }
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
        let action = UIAction(title: String(localized: "None", comment: "None"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: UIAction.Identifier("org.piwigo.images.group.none"),
                              handler: { [weak self] action in
            guard let self else { return }
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
        let children = [showHideTitlesAction(), showHideDescriptionsAction()].compactMap({$0})
        return UIMenu(title: String(localized: "categoryView_show", comment: "Show…"),
                      image: nil,
                      identifier: UIMenu.Identifier("org.piwigo.images.show.main"),
                      options: [],
                      children: children)
    }
    
    func showHideDescriptionsAction() -> UIAction? {
        let isActive = AlbumVars.shared.displayAlbumDescriptions
        let action = UIAction(title: String(localized: "settings_displayDescriptions", comment: "Album Descriptions"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: UIAction.Identifier("org.piwigo.images.show.descriptions"),
                              handler: { [weak self] action in
            guard let self else { return }
            // Show or hide album descriptions of visible views
            AlbumVars.shared.displayAlbumDescriptions = !isActive
            (navigationController?.viewControllers ?? []).forEach({ viewController in
                if let albumVC = viewController as? AlbumViewController {
                    albumVC.collectionView?.reloadData()
                }
            })
            // Update menu
            if categoryId == Int32.zero {
                let children = [smartAlbumsMenu(), viewOptionsMenu(), settingsMenu()].compactMap({$0})
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
        let isActive = AlbumVars.shared.displayImageTitles
        let action = UIAction(title: String(localized: "settings_displayTitles", comment: "Image Titles"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: UIAction.Identifier("org.piwigo.images.show.titles"),
                              handler: { [weak self] action in
            guard let self else { return }
            // Show or hide image titles
            AlbumVars.shared.displayImageTitles = !isActive
            // Update menu
            if categoryId == Int32.zero {
                let children = [smartAlbumsMenu(), viewOptionsMenu(), settingsMenu()].compactMap({$0})
                let updatedMenu = discoverBarButton.menu?.replacingChildren(children)
                discoverBarButton.menu = updatedMenu
            } else {
                updateCollectionAndMenu()
            }
            updateCollectionAndMenu()
        })
        action.accessibilityIdentifier = "showHideImageTitles"
        return action
    }
}


// MARK: - ImageHeaderDelegate Methods
extension AlbumViewController: @MainActor ImageHeaderDelegate
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
        if inSelectionMode == false {
            // Hide buttons
            hideButtons()
            
            // Activate Images Selection mode
            inSelectionMode = true
            
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
        
//        let start = CFAbsoluteTimeGetCurrent()
        if selectedSections[section] == .select {
            // Loop over all images in section to select them
            let snapshot = self.currentSnapshot
            let sectionID = snapshot.sectionIdentifiers[section]
            let sectionItems = snapshot.itemIdentifiers(inSection: sectionID)
            sectionItems.forEach { objectID in
                // Retrieve image data
                guard let image = try? self.mainContext.existingObject(with: objectID) as? Image,
                      selectedImages.keys.contains(image.pwgID) == false
                else { return }
                
                // Select this image
                if let indexPath = diffableDataSource.indexPath(for: objectID),
                   let cell = collectionView?.cellForItem(at: indexPath) as? ImageCollectionViewCell {
                    selectImage(image, isFavorite: cell.isFavorite)
                    cell.isSelection = true
                } else {
                    // pwg.users.favorites… methods available from Piwigo version 2.10
                    selectImage(image, isFavorite: favAlbum?.images.contains(image.pwgID) ?? false)
                }
            }
            // Change section button state
            selectedSections[section] = .deselect
        } 
        else {
            // Loop over all images in section to deselect them
            let snapshot = self.currentSnapshot
            let sectionID = snapshot.sectionIdentifiers[section]
            let sectionItems = snapshot.itemIdentifiers(inSection: sectionID)
            sectionItems.forEach { objectID in
                // Retrieve image data
                guard let image = try? self.mainContext.existingObject(with: objectID) as? Image,
                      selectedImages.keys.contains(image.pwgID)
                else { return }

                // Deselect this image
                deselectImages(withIDs: Set([image.pwgID]))
                if let indexPath = diffableDataSource.indexPath(for: objectID),
                   let cell = collectionView?.cellForItem(at: indexPath) as? ImageCollectionViewCell {
                    cell.isSelection = false
                }
            }
            
            // Change section button state
            selectedSections[section] = .select
        }
//        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//        debugPrint("=> Select/Deselect \(localImagesCollection.numberOfItems(inSection: section)) images of section \(section) took \(diff) ms")
        
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
        }
    }
}


// MARK: - Share Album Menu
extension AlbumViewController {
    
    /// Returns the menu proposing to share an album, or nil when it cannot be shared, i.e. when:
    /// — the album is the root album or a smart album, which have no page on the server;
    /// — the album is not in cache, or its status is unknown;
    /// — the album is public but the URL of its page is unknown;
    /// — the album is private and the ShareAlbum plugin is not installed,
    ///   or rejected this user during this session.
    ///
    /// A public album can be browsed by anyone, so the URL of its page is simply sent as is.
    /// A private album requires the ShareAlbum plugin, which creates a URL giving access to
    /// that album only, to people having no Piwigo account.
    func shareAlbumMenu(forAlbumWithID pwgID: Int32) -> UIMenuElement? {
        // Don't share smart albums and the root album
        guard pwgID > 0,
              let album = albumProvider.getAlbum(withID: pwgID, inContext: mainContext)
        else { return nil }
        
        let menuId = UIMenu.Identifier("org.piwigo.album.share")
        let children: [UIMenuElement]
        switch pwgAlbumStatus(rawValue: album.status) {
        case .publicStatus:
            // Anyone can browse a public album ► propose to send the URL of its page
            guard let pageUrl = album.pageUrl as? URL else { return nil }
            children = [shareAlbumLinkAction(pageUrl)]
            
        case .privateStatus:
            // Only the ShareAlbum plugin can share a private album.
            /// canShareAlbums remains nil until a sharealbum method of this session succeeded,
            /// i.e. until fetchSharedAlbums() or fetchShareOfAlbum() has run.
            guard ServerVars.shared.usesShareAlbum,
                  AlbumVars.shared.canShareAlbums == true
            else { return nil }
            
            // The share data is the one refreshed when the album appeared (see fetchShareOfAlbum)
            children = shareAlbumCommands(forAlbumWithID: pwgID)
            guard children.isEmpty == false else { return nil }
            
        default:
            // The status of this album is unknown
            return nil
        }
        return UIMenu(title: "", image: nil, identifier: menuId,
                      options: UIMenu.Options.displayInline,
                      children: children)
    }
    
    /// Variant used by the contextual menu of an album cell.
    func shareAlbumMenu(forAlbumAt indexPath: IndexPath) -> UIMenuElement? {
        guard let objectID = diffableDataSource.itemIdentifier(for: indexPath),
              let album = try? mainContext.existingObject(with: objectID) as? Album
        else { return nil }
        return shareAlbumMenu(forAlbumWithID: album.pwgID)
    }
    
    
    /// Returns the commands proposed for a private album, according to the share data in cache.
    private func shareAlbumCommands(forAlbumWithID pwgID: Int32) -> [UIMenuElement] {
        guard let album = albumProvider.getAlbum(withID: pwgID, inContext: mainContext)
        else { return [] }
        
        // The album is not shared yet ► propose to share it
        guard let shareUrl = album.shareUrl as? URL
        else { return [shareAlbumAction(forAlbumWithID: pwgID)] }
        
        // The album is already shared ► propose to send, renew or cancel its link
        let menuId = UIMenu.Identifier("org.piwigo.album.share.private")
        return [UIMenu(title: String(localized: "shareAlbum_private", comment: "Share Private Album"),
                       image: UIImage(systemName: "link"), identifier: menuId,
                       children: [shareLinkAction(shareUrl),
                                  renewLinkAction(forAlbumWithID: pwgID),
                                  stopSharingAction(forAlbumWithID: pwgID)])]
    }
    
    
    // MARK: - Share Album Actions
    private func shareAlbumLinkAction(_ pageUrl: URL) -> UIAction {
        return UIAction(title: String(localized: "shareAlbum_public", comment: "Share Public Album"),
                        image: UIImage(systemName: "link")) { [self] _ in
            // Anyone can browse a public album: send the URL of its page as is
            presentActivityView(with: pageUrl)
        }
    }
    
    private func shareAlbumAction(forAlbumWithID pwgID: Int32) -> UIAction {
        return UIAction(title: String(localized: "shareAlbum_private", comment: "Share Private Album"),
                        image: UIImage(systemName: "link")) { [self] _ in
            // Share the album, then propose to send the link
            updateShare(ofAlbumWithID: pwgID) { catID in
                try await JSONManager.shared.createShare(ofAlbumWithID: catID)
            } completion: { [self] shareUrl in
                if let shareUrl {
                    presentActivityView(with: shareUrl)
                }
            }
        }
    }
    
    private func shareLinkAction(_ shareUrl: URL) -> UIAction {
        return UIAction(title: String(localized: "shareAlbum_shareLink", comment: "Share Link…"),
                        image: UIImage(systemName: "square.and.arrow.up")) { [self] _ in
            presentActivityView(with: shareUrl)
        }
    }
    
    private func renewLinkAction(forAlbumWithID pwgID: Int32) -> UIAction {
        let title = String(localized: "shareAlbum_renewLink", comment: "Renew Link")
        return UIAction(title: title,
                        image: UIImage(systemName: "arrow.triangle.2.circlepath")) { [self] _ in
            // Renewing the code invalidates the link which was already sent to people
            confirmShareChange(title: title,
                               message: String(localized: "shareAlbum_renewLink_message",
                                               comment: "The current link will stop working…")) { [self] in
                // Renew the share code, then propose to send the new link
                updateShare(ofAlbumWithID: pwgID) { catID in
                    try await JSONManager.shared.renewShare(ofAlbumWithID: catID)
                } completion: { [self] shareUrl in
                    if let shareUrl {
                        presentActivityView(with: shareUrl)
                    }
                }
            }
        }
    }
    
    private func stopSharingAction(forAlbumWithID pwgID: Int32) -> UIAction {
        let title = String(localized: "shareAlbum_stopSharing", comment: "Stop Sharing")
        return UIAction(title: title,
                        image: UIImage(systemName: "xmark.circle"),
                        attributes: .destructive) { [self] _ in
            // Cancelling the share invalidates the link which was already sent to people
            confirmShareChange(title: title,
                               message: String(localized: "shareAlbum_stopSharing_message",
                                               comment: "The link will stop working…")) { [self] in
                // Cancel the share, which clears the share data of the album in cache
                updateShare(ofAlbumWithID: pwgID) { catID in
                    try await JSONManager.shared.cancelShare(ofAlbumWithID: catID)
                    return nil
                } completion: { _ in }
            }
        }
    }
    
    
    // MARK: - Share Album Utilities
    /// Asks the user to confirm an action which invalidates the link of a shared album,
    /// i.e. which prevents the people who already received it from opening the album.
    private func confirmShareChange(title: String, message: String,
                                    handler: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: Localized.cancel, style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        
        let confirmAction = UIAlertAction(title: title, style: .destructive, handler: { _ in
            handler()
        })
        alert.addAction(confirmAction)
        
        // Present the alert
        alert.view.tintColor = PwgColor.tintColor
        alert.view.accessibilityIdentifier = "ShareAlbum"
        alert.overrideUserInterfaceStyle = UIVars.shared.isDarkPaletteActive ? UIUserInterfaceStyle.dark : UIUserInterfaceStyle.light
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = PwgColor.tintColor
        }
    }
    
    /// Performs a request modifying the share of an album, stores its result in cache and
    /// reports a failure to the user. The completion is only called when the request succeeded,
    /// with the URL of the share as stored in cache, or nil when the album is not shared anymore.
    private func updateShare(ofAlbumWithID pwgID: Int32,
                             with request: @escaping @Sendable (Int32) async throws -> ShareAlbumGetInfo?,
                             completion: @escaping (URL?) -> Void) {
        // Display HUD during the request
        navigationController?.showHUD(withTitle: Localized.loading)
        
        Task {
            do {
                // Check session
                try await LoginUtilities().checkSessionOfCurrentUser()
                
                // Create, renew or cancel the share
                let shareData = try await request(pwgID)
                
                // Store the new share data in cache and update the UI
                await MainActor.run { [self] in
                    try? albumProvider.updateShare(shareData, ofAlbumWithID: pwgID, inContext: mainContext)
                    
                    // Rebuild the menus so that they propose the commands matching the new state
                    updateBarsInPreviewMode()
                    
                    // Retrieve the URL as stored, i.e. relative to the address used to log in
                    let shareUrl = albumProvider.getAlbum(withID: pwgID, inContext: mainContext)?.shareUrl as? URL
                    navigationController?.hideHUD {
                        completion(shareUrl)
                    }
                }
            }
            catch {
                await MainActor.run { [self] in
                    navigationController?.hideHUD { [self] in
                        let title = String(localized: "internetErrorGeneral_title", comment: "Connection Error")
                        dismissPiwigoError(withTitle: title, message: error.localizedDescription) { }
                    }
                }
            }
        }
    }
    
    /// Presents the system share sheet so that the user sends the link to people
    /// who do not have a Piwigo account.
    private func presentActivityView(with shareUrl: URL) {
        let activityVC = UIActivityViewController(activityItems: [shareUrl], applicationActivities: nil)
        if let selectBarButton {
            activityVC.popoverPresentationController?.barButtonItem = selectBarButton
        } else {
            activityVC.popoverPresentationController?.sourceView = view
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX,
                                                                          y: view.bounds.midY,
                                                                          width: 0, height: 0)
        }
        present(activityVC, animated: true)
    }
}
