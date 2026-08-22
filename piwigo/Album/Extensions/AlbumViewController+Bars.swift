//
//  AlbumViewController+Bars.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import PwgKit
import PwgCacheKit
import PwgUIKit

extension AlbumViewController
{
    // MARK: - Preview Mode
    /// Bar changes should not be animated when the view is not on screen yet (e.g. in viewWillAppear):
    /// the bars have no width at that time and animating their content makes UIKit lay out
    /// the bar buttons at zero width, which produces unsatisfiable constraint warnings.
    @MainActor
    func initBarsInPreviewMode(animated: Bool = true) {
        if #available(iOS 26.0, *) {
            initBarsInModernPreviewMode(animated: animated)
        }
        else {
            // Fallback on previous version
            initNavBarsInLegacyPreviewMode(animated: animated)
        }
    }
    
    @MainActor
    func updateBarsInPreviewMode() {
        // Right side of navigation bar
        if #available(iOS 26.0, *) {
            updateBarsInModernPreviewMode()
        }
        else {
            // Fallback on previous version
            updateRightBarInLegacyPreviewMode()
        }
    }
    
    
    // MARK: Preview Mode for iOS 26+
    @MainActor @available(iOS 26.0, *)
    private func initBarsInModernPreviewMode(animated: Bool) {
        // Left side of navigation bar
        if [0, AlbumVars.shared.defaultCategory, pwgSmartAlbum.search.rawValue].contains(categoryId) {
            // No button in root, search and default albums
            navigationItem.setLeftBarButtonItems([], animated: animated)
            navigationItem.hidesBackButton = true
        } else {
            // Back button to parent album
            navigationItem.setLeftBarButtonItems(nil, animated: animated)
            navigationItem.hidesBackButton = false
        }
        
        // Right side of navigation bar and toolbar
        /// Admin user can do everything except may be downloading images (i.e. sharing images)
        /// Community user may have or not:
        /// - album creation rights in some albums
        /// - upload rights in some albums
        /// - download rights (i.e. sharing images)
        /// - can only be allowed to edit properties of images he/she has uploaded.
        ///   This requires 'user_id' and 'added_by' values of images for checking rights.
        ///   'user_id' is deduced after a first upload, unknown before or after a clear of the data cache
        if categoryId == pwgSmartAlbum.root.rawValue {
            // Root album
            /// - Discover menu button in navigation bar including options and settings access
            /// - Create album button in toolbar if user has appropriate rights
            discoverBarButton = getDiscoverButton()
            addAlbumBarButton = getAddAlbumBarButton()
            
            // What follows is user interface dependent
            switch view.traitCollection.userInterfaceIdiom {
            case .phone:
                // Right side of the navigation bar
                let items = [discoverBarButton]
                navigationItem.setRightBarButtonItems(items, animated: animated)
                
                // Prepare toolbar
                navigationItem.preferredSearchBarPlacement = .integratedButton
                let searchBarButton = navigationItem.searchBarPlacementBarButtonItem
                var toolBarItems = [.space(), addAlbumBarButton, searchBarButton]

                // Add UploadQueue button if needed
                let nberOfUploads = UploadVars.shared.nberOfUploadsToComplete
                if nberOfUploads > 0 {
                    setUploadQueueButton(withNberOfUploads: nberOfUploads)
                    toolBarItems.insert(uploadQueueBarButton, at: 0)
                }
                
                // Gather buttons in toolbar
                navigationController?.setToolbarHidden(false, animated: animated)
                setToolbarItems(toolBarItems.compactMap { $0 }, animated: animated)
                
            case .pad:
                // Right side of the navigation bar
                navigationItem.preferredSearchBarPlacement = .integrated
                var items = [discoverBarButton, addAlbumBarButton]
                
                // Add UploadQueue button if needed
                let nberOfUploads = UploadVars.shared.nberOfUploadsToComplete
                if nberOfUploads > 0 {
                    setUploadQueueButton(withNberOfUploads: nberOfUploads)
                    items.append(contentsOf: [.fixedSpace(16.0), uploadQueueBarButton])
                }
                
                // Gather buttons in navigation bar
                navigationItem.setRightBarButtonItems(items.compactMap { $0 }, animated: animated)
                
                // No toolbar
                navigationController?.setToolbarHidden(true, animated: animated)
                setToolbarItems(nil, animated: false)
                
            default:
                preconditionFailure("!!! Interface not managed !!!")
            }
        }
        else {
            // Initialise Select menu with options and settings
            var children = [shareAlbumMenu(forAlbumWithID: categoryId), viewOptionsMenu(), settingsMenu()]
            
            // Select command enabled?
            shareBarButton = getShareBarButton()        // depends on Piwigo server version, user role and image data
            favoriteBarButton = getFavoriteBarButton()  // depends on Piwigo server version, user role and image data
            if shareBarButton != nil || favoriteBarButton != nil {
                children.insert(selectMenu(enabled: albumData.nbImages != 0), at: 0)
            }
            
            // Menu for activating the selection mode and changing the way images are sorted
            let menu = UIMenu(title: "", options: UIMenu.Options.displayInline, children: children.compactMap({$0}))
            selectBarButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: menu)
            selectBarButton?.accessibilityIdentifier = "select"
            selectBarButton?.accessibilityLabel = String(localized: "categoryImageList_selectButton", comment: "Select")
            
            // What follows is user interface dependent
            switch view.traitCollection.userInterfaceIdiom {
            case .phone:
                // Right side of the navigation bar
                navigationItem.setRightBarButtonItems([selectBarButton].compactMap { $0 }, animated: animated)

                // Toolbar
                if categoryId == pwgSmartAlbum.search.rawValue {
                    // Keep search bar integrated to toolbar
                    navigationItem.preferredSearchBarPlacement = .integrated
                    setToolbarItems(nil, animated: animated)
                }
                else if categoryId > 0 {
                    // Prepare toolbar
                    addAlbumBarButton = getAddAlbumBarButton()
                    addImageBarButton = getAddImageBarButton()
                    var toolBarItems: [UIBarButtonItem?] = [.space(), addAlbumBarButton, addImageBarButton]
                    
                    // Add UploadQueue button if needed
                    let nberOfUploads = UploadVars.shared.nberOfUploadsToComplete
                    if nberOfUploads > 0 {
                        setUploadQueueButton(withNberOfUploads: nberOfUploads)
                        toolBarItems.insert(uploadQueueBarButton, at: 0)
                    }
                    
                    // Gather buttons in toolbar
                    navigationController?.setToolbarHidden(false, animated: animated)
                    setToolbarItems(toolBarItems.compactMap { $0 }, animated: animated)
                }
                
            case .pad:
                // Right side of the navigation bar
                addAlbumBarButton = getAddAlbumBarButton()
                addImageBarButton = getAddImageBarButton()
                var barItems: [UIBarButtonItem?] = [selectBarButton, addImageBarButton, addAlbumBarButton]

                // Add UploadQueue button if needed
                let nberOfUploads = UploadVars.shared.nberOfUploadsToComplete
                if nberOfUploads > 0 {
                    setUploadQueueButton(withNberOfUploads: nberOfUploads)
                    barItems.append(contentsOf: [.fixedSpace(16.0), uploadQueueBarButton])
                }
                navigationItem.setRightBarButtonItems(barItems.compactMap({ $0 }), animated: animated)

                // No toolbar
                navigationController?.setToolbarHidden(true, animated: animated)
                setToolbarItems(nil, animated: false)

            default:
                preconditionFailure("!!! Interface not managed !!!")
            }
        }
    }
        
    @MainActor @available(iOS 26.0, *)
    func updateBarsInModernPreviewMode() {
        if categoryId == pwgSmartAlbum.root.rawValue {
            // What follows is user interface dependent
            switch view.traitCollection.userInterfaceIdiom {
            case .phone:
                // Prepare toolbar
                navigationItem.preferredSearchBarPlacement = .integratedButton
                let searchBarButton = navigationItem.searchBarPlacementBarButtonItem
                addAlbumBarButton = getAddAlbumBarButton()
                var toolBarItems: [UIBarButtonItem?] = [.space(), addAlbumBarButton, searchBarButton]
                
                // Add UploadQueue button if needed
                let nberOfUploads = UploadVars.shared.nberOfUploadsToComplete
                if nberOfUploads > 0 {
                    setUploadQueueButton(withNberOfUploads: nberOfUploads)
                    toolBarItems.insert(uploadQueueBarButton, at: 0)
                }
                
                // Gather buttons in toolbar
                navigationController?.setToolbarHidden(false, animated: true)
                setToolbarItems(toolBarItems.compactMap { $0 }, animated: true)
                
            case .pad:
                // Right side of the navigation bar
                addAlbumBarButton = getAddAlbumBarButton()
                navigationItem.preferredSearchBarPlacement = .integrated
                var barItems: [UIBarButtonItem?] = [discoverBarButton, addAlbumBarButton]
                
                // Add UploadQueue button if needed
                let nberOfUploads = UploadVars.shared.nberOfUploadsToComplete
                if nberOfUploads > 0 {
                    setUploadQueueButton(withNberOfUploads: nberOfUploads)
                    barItems.append(contentsOf: [.fixedSpace(16.0), uploadQueueBarButton])
                }
                
                // Gather buttons in navigation bar
                navigationItem.setRightBarButtonItems(barItems.compactMap { $0 }, animated: true)
                
            default:
                preconditionFailure("!!! Interface not managed !!!")
            }
        }
        else {
            // Below buttons depend on Piwigo server version, user role and image data
            shareBarButton = getShareBarButton()
            favoriteBarButton = getFavoriteBarButton()
            addAlbumBarButton = getAddAlbumBarButton()
            addImageBarButton = getAddImageBarButton()

            // Menu for activating the selection mode or changing the way images are sorted
            var children = [shareAlbumMenu(forAlbumWithID: categoryId), viewOptionsMenu(), settingsMenu()]
            if shareBarButton != nil || favoriteBarButton != nil {
                children.insert(selectMenu(enabled: albumData.nbImages != 0), at: 0)
            }
            let updatedMenu = selectBarButton?.menu?.replacingChildren(children.compactMap({$0}))
            selectBarButton?.menu = updatedMenu
            
            // What follows is user interface dependent
            switch view.traitCollection.userInterfaceIdiom {
            case .phone:
                // Toolbar
                if categoryId > 0 {
                    var toolBarItems: [UIBarButtonItem?] = [.space(), addAlbumBarButton, addImageBarButton]
                    
                    // Add UploadQueue button if needed
                    let nberOfUploads = UploadVars.shared.nberOfUploadsToComplete
                    if nberOfUploads > 0 {
                        setUploadQueueButton(withNberOfUploads: nberOfUploads)
                        toolBarItems.insert(uploadQueueBarButton, at: 0)
                    }
                    
                    // Gather buttons in toolbar
                    navigationController?.setToolbarHidden(false, animated: true)
                    setToolbarItems(toolBarItems.compactMap { $0 }, animated: true)
                }
                
            case .pad:
                // Right side of the navigation bar
                var barItems: [UIBarButtonItem?] = [selectBarButton, addImageBarButton, addAlbumBarButton]
                
                // Add UploadQueue button if needed
                let nberOfUploads = UploadVars.shared.nberOfUploadsToComplete
                if nberOfUploads > 0 {
                    setUploadQueueButton(withNberOfUploads: nberOfUploads)
                    barItems.append(contentsOf: [.fixedSpace(16.0), uploadQueueBarButton])
                }
                
                // Gather buttons in navigation bar
                navigationItem.setRightBarButtonItems(barItems.compactMap({ $0 }), animated: true)

            default:
                preconditionFailure("!!! Interface not managed !!!")
            }
        }
    }
    
    
    // MARK: Preview Mode before iOS 26
    @MainActor @available(iOS, introduced: 15.0, obsoleted: 26.0, message: "Specific to iOS 15 to 18")
    private func initNavBarsInLegacyPreviewMode(animated: Bool) {
        // Left side of navigation bar
        if [0, AlbumVars.shared.defaultCategory].contains(categoryId) {
            // Button for accessing settings
            navigationItem.setLeftBarButtonItems([settingsBarButton].compactMap { $0 }, animated: animated)
            navigationItem.hidesBackButton = true
        } else if categoryId == pwgSmartAlbum.search.rawValue {
            // Search bar => No action button
            navigationItem.setLeftBarButtonItems([], animated: animated)
        } else {
            // Back button to parent album
            navigationItem.setLeftBarButtonItems(nil, animated: animated)
            navigationItem.hidesBackButton = false
        }

        // Right side of navigation bar
        if categoryId == pwgSmartAlbum.root.rawValue {
            // Root album => Discover menu button
            navigationItem.setRightBarButtonItems([discoverBarButton].compactMap { $0 }, animated: animated)
        }
        else if categoryId == pwgSmartAlbum.search.rawValue {
            // Search mode => No action button and no toolbar
            navigationItem.setRightBarButtonItems([], animated: animated)
            navigationController?.setToolbarHidden(true, animated: animated)
            searchController?.searchBar.becomeFirstResponder()
        }
        else {
            // Below button depends on Piwigo server version, user role and image data
            shareBarButton = getShareBarButton()
            favoriteBarButton = getFavoriteBarButton()
            
            // Menu for activating the selection mode and changing the way images are sorted
            var children = [shareAlbumMenu(forAlbumWithID: categoryId), viewOptionsMenu()]
            if shareBarButton != nil || favoriteBarButton != nil {
                children.insert(selectMenu(enabled: albumData.nbImages != 0), at: 0)
            }
            let menu = UIMenu(title: "", children: children.compactMap({$0}))
            selectBarButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: menu)
            selectBarButton?.accessibilityIdentifier = "select"
            selectBarButton?.accessibilityLabel = String(localized: "categoryImageList_selectButton", comment: "Select")
            
            // Set right bar buttons
            navigationItem.setRightBarButtonItems([selectBarButton].compactMap { $0 }, animated: animated)
        }
    }
    
    @MainActor @available(iOS, introduced: 15.0, obsoleted: 26.0, message: "Specific to iOS 15 to 18")
    private func updateRightBarInLegacyPreviewMode() {
        // Hide toolbar unless it is displaying the image detail view
        if let displayedVC = navigationController?.viewControllers.last,
           !(displayedVC is ImageViewController) {
            navigationController?.setToolbarHidden(true, animated: true)
        }

        // No share/select buttons in root or search album
        if [0, pwgSmartAlbum.search.rawValue].contains(categoryId) {
            return
        }
        
        // Share button depends on Piwigo server version, user role and image data
        shareBarButton = getShareBarButton()
        
        // Menu for activating the selection mode or change the way images are sorted
        var children = [shareAlbumMenu(forAlbumWithID: categoryId), viewOptionsMenu()]
        if shareBarButton != nil || favoriteBarButton != nil {
            children.insert(selectMenu(enabled: albumData.nbImages != 0), at: 0)
        }
        let updatedMenu = selectBarButton?.menu?.replacingChildren(children.compactMap({$0}))
        selectBarButton?.menu = updatedMenu
    }
    
    
    // MARK: - Select Mode
    @MainActor
    func initBarsInSelectMode() {
        // Hide back or Settings button
        navigationItem.hidesBackButton = true

        // Share button depends on Piwigo server version, user role and image data
        shareBarButton = getShareBarButton()

        // Interface depends on device and orientation
        let orientation = view.currentInterfaceOrientation

        // Admin user can do everything except may be downloading images (i.e. sharing images)
        // Community user can only be allowed to edit properties of images he/she has uploaded.
        /// This requires 'user_id' and 'added_by' values of images for checking rights.
        /// 'user_id' is deduced after a first upload, unknown before or after a clear of the data cache
        if userData.hasEditRights(forImagesAddedToAlbum: categoryId, byUserWithIDs: selectedAddedByIDs) {
            initBarsInSelectModeForAdmin(orientation: orientation)
        } else {
            initBarsInSelectModeForStdUserOrGuest(orientation: orientation)
        }

        // Set initial status
        updateBarsInSelectMode()
    }
    
    @MainActor
    private func initBarsInSelectModeForAdmin(orientation: UIInterfaceOrientation) {
        // The action button proposes:
        /// - to copy or move images to other albums
        /// - to rotate a photo clockwise or counterclockwise,
        /// - to edit image parameters
        let menu = UIMenu(title: "", children: [albumMenu(), imagesMenu()])
        if #available(iOS 26.0, *) {
            actionBarButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: menu)
        } else {
            // Fallback on previous version
            actionBarButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle.fill"), menu: menu)
        }
        actionBarButton?.accessibilityIdentifier = "actions"
        actionBarButton?.accessibilityLabel = String(localized: "moreOptions_title", comment: "More")

        if view.traitCollection.userInterfaceIdiom == .phone, orientation.isPortrait {
            // Left side of navigation bar
            navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)

            // Right side of navigation bar
            navigationItem.setRightBarButtonItems([actionBarButton].compactMap { $0 }, animated: true)

            // Remaining buttons in navigation toolbar
            if #available(iOS 26.0, *) {
                // Toolbar
                let toolbarItems: [UIBarButtonItem] = [shareBarButton, .space(),
                                                       favoriteBarButton, deleteBarButton].compactMap({ $0 })
                navigationController?.setToolbarHidden(false, animated: true)
                setToolbarItems(toolbarItems, animated: true)
            }
            else {
                // Fallback on previous version
                // Toolbar
                /// We reset the bar button items which are not positioned correctly by iOS 15 after device rotation.
                /// They also disappear when coming back to portrait orientation.
                /// [share - delete] or [ favorite - delete ] or [share - favorite - delete]
                let toolBarItems = [shareBarButton, .space(),
                                    favoriteBarButton, favoriteBarButton == nil ? nil : .space(),
                                    deleteBarButton, shareBarButton == nil ? .space() : nil].compactMap { $0 }
                navigationController?.setToolbarHidden(false, animated: true)
                setToolbarItems(toolBarItems, animated: true)
            }
        } else {    // iPad
            // Left side of navigation bar
            navigationItem.setLeftBarButtonItems([cancelBarButton, deleteBarButton].compactMap { $0 }, animated: true)

            // Right side of navigation bar (may include search bar)
            let rightBarButtonItems = [actionBarButton, favoriteBarButton, shareBarButton].compactMap { $0 }
            navigationItem.setRightBarButtonItems(rightBarButtonItems, animated: true)

            // Hide toolbar
            navigationController?.setToolbarHidden(true, animated: true)
            setToolbarItems(nil, animated: false)
        }
    }
    
    @MainActor
    private func initBarsInSelectModeForStdUserOrGuest(orientation: UIInterfaceOrientation) {
        // Left side of navigation bar
        navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)

        // Right side of navigation bar
        if view.traitCollection.userInterfaceIdiom == .phone, orientation.isPortrait {
            // Remaining two buttons on the right side of the navigation bar
            navigationItem.setRightBarButtonItems([shareBarButton, favoriteBarButton].compactMap { $0 }, animated: true)
        } else {
            // All buttons in navigation bar
            navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)
            navigationItem.setRightBarButtonItems([shareBarButton, favoriteBarButton].compactMap { $0 }, animated: true)
        }

        // Hide toolbar
        navigationController?.setToolbarHidden(true, animated: true)
    }
    
    @MainActor
    func updateBarsInSelectMode() {
        setTitleViewFromAlbumData()
        let hasImagesSelected = !selectedImages.isEmpty
        cancelBarButton.isEnabled = true

        // Admin user can do everything except may be downloading images (i.e. sharing images)
        // Community user can only be allowed to edit properties of images he/she has uploaded.
        /// This requires 'user_id' and 'added_by' values of images for checking rights.
        /// 'user_id' is deduced after a first upload, unknown before or after a clear of the data cache
        if userData.hasEditRights(forImagesAddedToAlbum: categoryId, byUserWithIDs: selectedAddedByIDs) {
            selectBarButton?.isEnabled = hasImagesSelected
            actionBarButton?.isEnabled = hasImagesSelected
            shareBarButton?.isEnabled = hasImagesSelected
            deleteBarButton.isEnabled = hasImagesSelected
            favoriteBarButton?.isEnabled = hasImagesSelected
            let areFavorites = selectedImageIDs == selectedFavoriteIDs
            favoriteBarButton?.setFavoriteImage(for: areFavorites)
            favoriteBarButton?.action = areFavorites ? #selector(unfavoriteSelection) : #selector(favoriteSelection)

            // Update menu
            let children = [albumMenu(), imagesMenu()].compactMap({$0})
            let updatedMenu = actionBarButton?.menu?.replacingChildren(children)
            actionBarButton?.menu = updatedMenu
        } else {
            selectBarButton?.isEnabled = false
            actionBarButton?.isEnabled = false
            deleteBarButton.isEnabled = false
            shareBarButton?.isEnabled = hasImagesSelected
            favoriteBarButton?.isEnabled = hasImagesSelected
            let areFavorites = selectedImageIDs == selectedFavoriteIDs
            favoriteBarButton?.setFavoriteImage(for: areFavorites)
            favoriteBarButton?.action = areFavorites ? #selector(unfavoriteSelection) : #selector(favoriteSelection)
        }
    }
    
    // Buttons are disabled (greyed) when:
    /// - retrieving image data
    /// - executing an action
    func setEnableStateOfButtons(_ state: Bool) {
        cancelBarButton.isEnabled = state
        actionBarButton?.isEnabled = state
        deleteBarButton.isEnabled = state
        shareBarButton?.isEnabled = state
        favoriteBarButton?.isEnabled = state
    }
        
    
    // MARK: - Title View
    @MainActor
    @objc func updateTitleView(_ notification: Notification?) {
        // Check notification data
        guard let info = notification?.userInfo,
              let categoryID = info["pwgID"] as? Int32, categoryID == categoryId,
              let progress = info["fetchProgressFraction"] as? Float
        else { return }

        // Update title view
        setTitleViewFromAlbumData(progress: progress)
    }
    
    @MainActor
    func setTitleViewFromAlbumData(progress: Float = 0) {
        if #available(iOS 26.0, *) {
            setTitleView(progress: progress)
        } else {
            // Fallback on previous version
            setTitleViewOld(progress: progress)
        }
    }

    @MainActor @available(iOS 26.0, *)
    func setTitleView(progress: Float = 0) {
        // Title
        guard categoryId != pwgSmartAlbum.search.rawValue
        else {
            title = nil
            navigationItem.attributedTitle = nil
            navigationItem.attributedSubtitle = nil
            navigationItem.subtitle = nil
            navigationItem.largeSubtitle = nil
            return
        }
        
        let title: String = categoryId == Int32.zero ? Localized.tabBar_albums : albumData.name
        navigationItem.title = title
        view?.window?.windowScene?.title = title
        
        // No subtitle when using acessibility category or on iPhone in landscape mode
        let orientation = view.currentInterfaceOrientation
        let tooLargeFont = traitCollection.preferredContentSizeCategory >= .accessibilityMedium
        if (tooLargeFont && categoryId != AlbumVars.shared.defaultCategory) ||
            (view.traitCollection.userInterfaceIdiom == .phone && orientation.isLandscape) {
            // Set title and subtitle
            if prefersLargeTitles {
                navigationItem.subtitle = nil
            } else {
                navigationItem.titleView = getTitleView(withTitle: title, titleColor: .label,
                                                        subtitle: "", subTitleColor: .label)
            }
            return
        }
        
        // Subtitle
        var subTitle: String = ""
        if AlbumVars.shared.isFetchingAlbumData.contains(categoryId) {
            // Inform user that the app is fetching album data
            if progress == 0 {
                subTitle = String(localized: "categoryUpdating", comment: "Updating…")
            } else {
                let numberFormatter = NumberFormatter()
                numberFormatter.numberStyle = NumberFormatter.Style.percent
                let percent = numberFormatter.string(from: NSNumber(value: progress)) ?? ""
                subTitle = String(localized: "categoryUpdating", comment: "Updating…") + " " + percent
            }
        }
        else if inSelectionMode {
            let nberPhotos = selectedImages.count
            switch nberPhotos {
            case 0:
                subTitle = String(localized: "selectImages", comment: "Select Photos")
            case 1:
                subTitle = String(localized: "selectImageSelected", comment: "1 Photo Selected")
            default:
                let nberPhotosStr = nberPhotos.formatted(.number)
                subTitle = String(format: String(localized: "selectImagesSelected", comment: "%@ Photos Selected"), nberPhotosStr)
            }
        }
        else if albumData.dateGetImages > TimeInterval(86400) { // i.e. a day after minimum date
            let dateGetImages = Date(timeIntervalSinceReferenceDate: albumData.dateGetImages)
            if Date.timeIntervalSinceReferenceDate - albumData.dateGetImages < 60 {
                subTitle = String(localized: "categoryUpdatedNow", comment: "Updated just now")
            } else {
                let calendar = Calendar.current
                let updatedDay = calendar.dateComponents([.day], from: dateGetImages)
                let dateDay = calendar.dateComponents([.day], from: Date())
                if updatedDay.day == dateDay.day {
                    // Album data updated today
                    let time = DateFormatter.localizedString(from: dateGetImages,
                                                             dateStyle: .none, timeStyle: .short)
                    subTitle = String(format: String(localized: "categoryUpdatedAt", comment: "Updated at…"), time)
                } else {
                    // Album data updated yesterday or before
                    let date = DateFormatter.localizedString(from: dateGetImages,
                                                             dateStyle: .short, timeStyle: .none)
                    subTitle = String(format: String(localized: "categoryUpdatedOn", comment: "Updated on…"), date)
                }
            }
        }
        
        // Set subtitle
        if prefersLargeTitles {
            navigationItem.subtitle = subTitle
            navigationItem.largeAttributedSubtitle = TableViewUtilities.largeAttributedSubTitleForAlbum(subTitle)
        } else {
            navigationItem.titleView = getTitleView(withTitle: title, titleColor: .label,
                                                    subtitle: subTitle, subTitleColor: .label)
        }
        self.view?.window?.windowScene?.subtitle = subTitle
    }
    
    @MainActor @available(iOS, introduced: 15.0, obsoleted: 26.0, message: "Specific to iOS 15 to 18")
    func setTitleViewOld(progress: Float = 0) {
        // Title
        if [0, pwgSmartAlbum.search.rawValue].contains(categoryId) {
            self.title = Localized.tabBar_albums
            self.view?.window?.windowScene?.title = self.title
            return
        }
        
        let title = albumData.name
        self.title = title
        self.view?.window?.windowScene?.title = title
        
        // There is no subtitle in landscape mode on iPhone
        // nor when using acessibility category
        var subtitle = ""
        let orientation = view.currentInterfaceOrientation
        let isAccessibilityCategory = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        if !(view.traitCollection.userInterfaceIdiom == .phone && orientation.isLandscape) {
            if AlbumVars.shared.isFetchingAlbumData.contains(categoryId) && !isAccessibilityCategory {
                // Inform user that the app is fetching album data
                if progress == 0 {
                    subtitle = String(localized: "categoryUpdating", comment: "Updating…")
                } else {
                    let numberFormatter = NumberFormatter()
                    numberFormatter.numberStyle = NumberFormatter.Style.percent
                    let percent = numberFormatter.string(from: NSNumber(value: progress)) ?? ""
                    subtitle = String(localized: "categoryUpdating", comment: "Updating…") + " " + percent
                }
            }
            else if inSelectionMode && !isAccessibilityCategory {
                let nberPhotos = selectedImages.count
                switch nberPhotos {
                case 0:
                    subtitle = String(localized: "selectImages", comment: "Select Photos")
                case 1:
                    subtitle = String(localized: "selectImageSelected", comment: "1 Photo Selected")
                case 2...nberPhotos:
                    var nberPhotosStr = ""
                    if #available(iOS 16, *) {
                        nberPhotosStr = nberPhotos.formatted(.number)
                    } else {
                        let numberFormatter = NumberFormatter()
                        numberFormatter.numberStyle = NumberFormatter.Style.decimal
                        nberPhotosStr = numberFormatter.string(from: NSNumber(value: nberPhotos)) ?? String(nberPhotos)
                    }
                    subtitle = String(format: String(localized: "selectImagesSelected", comment: "%@ Photos Selected"), nberPhotosStr)
                default:
                    subtitle = ""
                }
            }
            else if albumData.dateGetImages > TimeInterval(86400) && !isAccessibilityCategory { // i.e. a day after minimum date
                let dateGetImages = Date(timeIntervalSinceReferenceDate: albumData.dateGetImages)
                if Date.timeIntervalSinceReferenceDate - albumData.dateGetImages < 60 {
                    subtitle = String(localized: "categoryUpdatedNow", comment: "Updated just now")
                } else {
                    let calendar = Calendar.current
                    let updatedDay = calendar.dateComponents([.day], from: dateGetImages)
                    let dateDay = calendar.dateComponents([.day], from: Date())
                    if updatedDay.day == dateDay.day {
                        // Album data updated today
                        let time = DateFormatter.localizedString(from: dateGetImages,
                                                                 dateStyle: .none, timeStyle: .short)
                        subtitle = String(format: String(localized: "categoryUpdatedAt", comment: "Updated at…"), time)
                    } else {
                        // Album data updated yesterday or before
                        let date = DateFormatter.localizedString(from: dateGetImages,
                                                                 dateStyle: .short, timeStyle: .none)
                        subtitle = String(format: String(localized: "categoryUpdatedOn", comment: "Updated on…"), date)
                    }
                }
            }
        }
        
        // Set title view
        navigationItem.titleView = getTitleView(withTitle: title, titleColor: PwgColor.whiteCream,
                                                subtitle: subtitle, subTitleColor: PwgColor.rightLabel)
    }
    
    // The font size of the title is not updated automatically
    // for larger accessibility type sizes on iOS 26.0
    private func getTitleView(withTitle title: String, titleColor: UIColor,
                              subtitle: String, subTitleColor: UIColor) -> UIView {
        // Create title label programmatically
        let titleLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        titleLabel.backgroundColor = UIColor.clear
        titleLabel.textColor = titleColor
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.adjustsFontSizeToFitWidth = false
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.allowsDefaultTighteningForTruncation = true
        let wholeRange = NSRange(location: 0, length: title.count)
        let style = NSMutableParagraphStyle()
        style.alignment = NSTextAlignment.center
        let attributes = [
            NSAttributedString.Key.foregroundColor: titleColor,
            NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .headline),
            NSAttributedString.Key.paragraphStyle: style
        ]
        let attTitle = NSMutableAttributedString(string: title)
        attTitle.addAttributes(attributes, range: wholeRange)
        titleLabel.attributedText = attTitle
        titleLabel.sizeToFit()
        
        // No subtitle?
        guard subtitle.isEmpty == false
        else {
            let titleWidth = CGFloat(fmin(titleLabel.bounds.size.width, view.bounds.size.width - 100.0))
            titleLabel.sizeThatFits(CGSize(width: titleWidth, height: titleLabel.bounds.size.height))
            let oneLineTitleView = UIView(frame: CGRect(x: 0, y: 0, width: CGFloat(titleWidth), height: titleLabel.bounds.size.height))
            oneLineTitleView.addSubview(titleLabel)
            oneLineTitleView.addConstraint(NSLayoutConstraint.constraintView(titleLabel, toWidth: titleWidth)!)
            oneLineTitleView.addConstraints(NSLayoutConstraint.constraintCenter(titleLabel)!)
            return oneLineTitleView
        }

        // Create subtitle label programmatically
        let subTitleLabel = UILabel(frame: CGRect(x: 0.0, y: titleLabel.frame.size.height, width: 0, height: 0))
        subTitleLabel.backgroundColor = UIColor.clear
        subTitleLabel.textColor = subTitleColor
        subTitleLabel.textAlignment = .center
        subTitleLabel.numberOfLines = 1
        subTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        if traitCollection.preferredContentSizeCategory < .extraExtraExtraLarge {
            subTitleLabel.font = .preferredFont(forTextStyle: .caption2)
        } else {
            subTitleLabel.font = .systemFont(ofSize: 15.0)  // instead of 17.0
        }
        subTitleLabel.adjustsFontSizeToFitWidth = false
        subTitleLabel.lineBreakMode = .byTruncatingTail
        subTitleLabel.allowsDefaultTighteningForTruncation = true
        subTitleLabel.text = subtitle
        subTitleLabel.sizeToFit()
        
        // Create two-line title view
        var titleWidth = CGFloat(fmax(subTitleLabel.bounds.size.width, titleLabel.bounds.size.width))
        titleWidth = fmin(titleWidth, view.bounds.size.width - 100.0)
        titleLabel.sizeThatFits(CGSize(width: titleWidth, height: titleLabel.bounds.size.height))
        let twoLineTitleView = UIView(frame: CGRect(x: 0, y: 0, width: CGFloat(titleWidth),
                                                    height: titleLabel.bounds.size.height + subTitleLabel.bounds.size.height))
        twoLineTitleView.addSubview(titleLabel)
        twoLineTitleView.addSubview(subTitleLabel)
        twoLineTitleView.addConstraint(NSLayoutConstraint.constraintView(titleLabel, toWidth: titleWidth)!)
        twoLineTitleView.addConstraint(NSLayoutConstraint.constraintCenterVerticalView(titleLabel)!)
        twoLineTitleView.addConstraint(NSLayoutConstraint.constraintCenterVerticalView(subTitleLabel)!)
        let views = ["title": titleLabel,
                     "subtitle": subTitleLabel]
        twoLineTitleView.addConstraints(
            NSLayoutConstraint.constraints(withVisualFormat: "V:|[title][subtitle]|",
                                           options: [], metrics: nil, views: views))
        return twoLineTitleView
    }
}
