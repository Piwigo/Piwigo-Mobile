//
//  AlbumViewController+Bars.swift
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
    // MARK: - Preview Mode
    @MainActor
    func initBarsInPreviewMode() {
        if #available(iOS 26.0, *) {
            initNavBarsInPreviewMode()
        }
        else {
            // Fallback on previous version
            initNavBarsOldInPreviewMode()
        }
    }
    
    @MainActor @available(iOS 26.0, *)
    private func initNavBarsInPreviewMode() {
        // Left side of navigation bar
        if [0, AlbumVars.shared.defaultCategory, pwgSmartAlbum.search.rawValue].contains(categoryId) {
            // No button in root, search and default albums
            navigationItem.setLeftBarButtonItems([], animated: true)
            navigationItem.hidesBackButton = true
        } else {
            // Back button to parent album
            navigationItem.setLeftBarButtonItems([], animated: true)
            navigationItem.hidesBackButton = false
        }
        
        // Right side of navigation bar and toolbar
        if categoryId == Int32.zero {
            // Root album => Discover menu button in navigation bar
            discoverBarButton = getDiscoverButton()
            
            // User with admin or upload rights can do everything
            // except may be downloading images (i.e. sharing images)
            // User without admin rights cannot set album thumbnails, delete images
            // WRONG =====> 'normal' user with upload access to the current category can copy, move, edit images
            // SHOULD BE => 'normal' user having uploaded images can only edit their images.
            //              This requires 'user_id' and 'added_by' values of images for checking rights
            if user.hasUploadRights(forCatID: categoryId) {
                // Initialise UploadQueue toolbar button if needed
                // and place it with other buttons in the navigation bar
                let nberOfUploads = UploadVars.shared.nberOfUploadsToComplete
                if nberOfUploads > 0 {
                    // In toolbar or on the right side of the navigation bar
                    setNavBarWithUploadQueueButton(andNberOfUploads: nberOfUploads)
                } else {
                    // In toolbar or on the right side of the navigation bar
                    setNavBarWithoutUploadQueueButton()
                }

                // Items not gathered with the upload queue bar button
                switch view.traitCollection.userInterfaceIdiom {
                case .phone:
                    // Right side of the navigation bar
                    let items = [discoverBarButton].compactMap { $0 }
                    navigationItem.setRightBarButtonItems(items, animated: true)
                    
                case .pad:
                    // No toolbar
                    navigationController?.setToolbarHidden(true, animated: true)
                    setToolbarItems(nil, animated: false)

                default:
                    preconditionFailure("!!! Interface not managed !!!")
                }
            }
            else {
                // Navigation bar
                switch view.traitCollection.userInterfaceIdiom {
                case .phone:
                    // Right side of the navigation bar
                    navigationItem.preferredSearchBarPlacement = .integrated
                    let items = [discoverBarButton].compactMap { $0 }
                    navigationItem.setRightBarButtonItems(items, animated: true)
                
                case .pad:
                    // Right side of the navigation bar
                    navigationItem.preferredSearchBarPlacement = .integrated
                    let items: [UIBarButtonItem] = [discoverBarButton].compactMap({ $0 })
                    navigationItem.setRightBarButtonItems(items, animated: true)

                default:
                    preconditionFailure("!!! Interface not managed !!!")
                }

                // No toolbar
                navigationController?.setToolbarHidden(true, animated: true)
                setToolbarItems(nil, animated: false)
            }
        }
        else {
            // Share button depends on Piwigo server version, user role and image data
            shareBarButton = getShareBarButton()
            
            // Favorites button depends on Piwigo server version, user role and image data
            favoriteBarButton = getFavoriteBarButton()
            
            // Menu for activating the selection mode and changing the way images are sorted
            var children = [sortMenu(), viewOptionsMenu(), settingsMenu()]
            if shareBarButton != nil || favoriteBarButton != nil {
                children.insert(selectMenu(), at: 0)
            }
            let menu = UIMenu(title: "", options: UIMenu.Options.displayInline, children: children.compactMap({$0}))
            selectBarButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: menu)
            selectBarButton?.accessibilityIdentifier = "select"
            let hasImages = albumData.nbImages != 0
            selectBarButton?.isEnabled = hasImages

            // User with admin or upload rights can do everything
            // except may be downloading images (i.e. sharing images)
            // User without admin rights cannot set album thumbnails, delete images
            // WRONG =====> 'normal' user with upload access to the current category can copy, move, edit images
            // SHOULD BE => 'normal' user having uploaded images can only edit their images.
            //              This requires 'user_id' and 'added_by' values of images for checking rights
            if user.hasUploadRights(forCatID: categoryId) {
                switch view.traitCollection.userInterfaceIdiom {
                case .phone:
                    // Select menu on the right side of the navigation bar
                    navigationItem.setRightBarButtonItems([selectBarButton].compactMap { $0 }, animated: true)

                    if categoryId == pwgSmartAlbum.search.rawValue {
                        // Keep search bar integrated to toolbar
                        navigationItem.preferredSearchBarPlacement = .integrated
                        setToolbarItems(nil, animated: true)
                    }
                    else if categoryId > 0 {
                        // [Add Photos] and [Create Album] buttons in the toolbar
                        let toolBarItems = [.space(), addAlbumBarButton, addImageBarButton].compactMap { $0 }
                        navigationController?.setToolbarHidden(false, animated: true)
                        setToolbarItems(toolBarItems, animated: true)
                    }

                case .pad:
                    // All buttons in the navigation bar
                    var items: [UIBarButtonItem?] = [selectBarButton]
                    if categoryId > 0 {
                        items.append(contentsOf: [addImageBarButton, addAlbumBarButton])
                    }
                    navigationItem.setRightBarButtonItems(items.compactMap({ $0 }), animated: true)
                    
                    // No toolbar
                    navigationController?.setToolbarHidden(true, animated: true)
                    setToolbarItems(nil, animated: false)

                default:
                    preconditionFailure("!!! Interface not managed !!!")
                }
            } else {
                // Select menu on the right side of the navigation bar
                navigationItem.setRightBarButtonItems([selectBarButton].compactMap { $0 }, animated: true)

                // No toolbar
                navigationController?.setToolbarHidden(true, animated: true)
                setToolbarItems(nil, animated: false)
            }
        }
    }
    
    @MainActor @available(iOS, introduced: 15.0, obsoleted: 26.0, message: "Specific to iOS 15 to 18")
    private func initNavBarsOldInPreviewMode() {
        // Left side of navigation bar
        if [0, AlbumVars.shared.defaultCategory].contains(categoryId) {
            // Button for accessing settings
            navigationItem.setLeftBarButtonItems([settingsBarButton].compactMap { $0 }, animated: true)
            navigationItem.hidesBackButton = true
        } else if categoryId == pwgSmartAlbum.search.rawValue {
            // Search bar => No action button
            navigationItem.setLeftBarButtonItems([], animated: true)
        } else {
            // Back button to parent album
            navigationItem.setLeftBarButtonItems([], animated: true)
            navigationItem.hidesBackButton = false
        }

        // Right side of navigation bar
        if categoryId == 0 {
            // Root album => Discover menu button
            navigationItem.setRightBarButtonItems([discoverBarButton].compactMap { $0 }, animated: true)
        }
        else if categoryId == pwgSmartAlbum.search.rawValue {
            // Search mode => No action button and no toolbar
            navigationItem.setRightBarButtonItems([], animated: true)
            navigationController?.setToolbarHidden(true, animated: true)
            searchController?.searchBar.becomeFirstResponder()
        }
        else {
            // Share button depends on Piwigo server version, user role and image data
            shareBarButton = getShareBarButton()
            
            // Favorites button depends on Piwigo server version, user role and image data
            favoriteBarButton = getFavoriteBarButton()
            
            // Menu for activating the selection mode and changing the way images are sorted
            var children = [sortMenu(), viewOptionsMenu()]
            if shareBarButton != nil || favoriteBarButton != nil {
                children.insert(selectMenu(), at: 0)
            }
            let menu = UIMenu(title: "", children: children.compactMap({$0}))
            selectBarButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: menu)
            selectBarButton?.accessibilityIdentifier = "select"
            
            // Set right bar buttons
            navigationItem.setRightBarButtonItems([selectBarButton].compactMap { $0 }, animated: true)
            let hasImages = albumData.nbImages != 0
            selectBarButton?.isEnabled = hasImages
        }
    }
    
    @MainActor
    func updateBarsInPreviewMode() {
        // Right side of navigation bar
        if #available(iOS 26.0, *) {
            updateRightBarInPreviewMode()
        }
        else {
            // Fallback on previous version
            updateRightBarOldInPreviewMode()
        }
    }
    
    @MainActor @available(iOS 26.0, *)
    private func updateRightBarInPreviewMode() {
        // Share button depends on Piwigo server version, user role and image data
        shareBarButton = getShareBarButton()
        
        // Menu for activating the selection mode or change the way images are sorted
        var children = [sortMenu(), viewOptionsMenu(), settingsMenu()]
        if shareBarButton != nil || favoriteBarButton != nil {
            children.insert(selectMenu(), at: 0)
        }
        let updatedMenu = selectBarButton?.menu?.replacingChildren(children.compactMap({$0}))
        selectBarButton?.menu = updatedMenu
        selectBarButton?.isEnabled = albumData.nbImages != 0
    }
    
    @MainActor @available(iOS, introduced: 15.0, obsoleted: 26.0, message: "Specific to iOS 15 to 18")
    private func updateRightBarOldInPreviewMode() {
        // Hide toolbar unless it is displaying the image detail view
        if let displayedVC = navigationController?.viewControllers.last,
           !(displayedVC is ImageViewController) {
            navigationController?.setToolbarHidden(true, animated: true)
        }

        // No share/select buttons in root album
        if [0, pwgSmartAlbum.search.rawValue].contains(categoryId) {
            return
        }
        
        // Share button depends on Piwigo server version, user role and image data
        shareBarButton = getShareBarButton()
        
        // Menu for activating the selection mode or change the way images are sorted
        var children = [sortMenu(), viewOptionsMenu()]
        if shareBarButton != nil || favoriteBarButton != nil {
            children.insert(selectMenu(), at: 0)
        }
        let updatedMenu = selectBarButton?.menu?.replacingChildren(children.compactMap({$0}))
        selectBarButton?.menu = updatedMenu
        selectBarButton?.isEnabled = albumData.nbImages != 0
    }
    
    
    // MARK: - Select Mode
    @MainActor
    func initBarsInSelectMode() {
        // Hide back or Settings button
        navigationItem.hidesBackButton = true

        // Share button depends on Piwigo server version, user role and image data
        shareBarButton = getShareBarButton()

        // Interface depends on device and orientation
        let orientation = view.window?.windowScene?.interfaceOrientation ?? .portrait

        // User with admin or upload rights can do everything
        // except may be downloading images (i.e. sharing images)
        // User without admin rights cannot set album thumbnails, delete images
        // WRONG =====> 'normal' user with upload access to the current category can copy, move, edit images
        // SHOULD BE => 'normal' user having uploaded images can only edit their images.
        //              This requires 'user_id' and 'added_by' values of images for checking rights
        if user.hasUploadRights(forCatID: categoryId) {
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

        if view.traitCollection.userInterfaceIdiom == .phone, orientation.isPortrait {
            // Remaining buttons in navigation toolbar
            if #available(iOS 26.0, *) {
                // Left side of navigation bar
                navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)

                // Right side of navigation bar
                navigationItem.setRightBarButtonItems([actionBarButton].compactMap { $0 }, animated: true)

                // Toolbar
                let toolbarItems: [UIBarButtonItem] = [shareBarButton, .space(),
                                                       favoriteBarButton, deleteBarButton].compactMap({ $0 })
                setToolbarItems(toolbarItems, animated: true)
                navigationController?.setToolbarHidden(false, animated: true)
            }
            else {
                // Fallback on previous version
                // Left side of navigation bar
                navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)

                // Right side of navigation bar
                navigationItem.setRightBarButtonItems([actionBarButton].compactMap { $0 }, animated: true)

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
        } else {
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

        // Right side and toolbar
        if view.traitCollection.userInterfaceIdiom == .phone, orientation.isPortrait {
            // Remaining two buttons on the right side of the navigation bar
            navigationItem.setRightBarButtonItems([shareBarButton, favoriteBarButton].compactMap { $0 }, animated: true)

            // Hide navigation toolbar
            navigationController?.setToolbarHidden(true, animated: true)
        } else {
            // All buttons in navigation bar
            navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)
            navigationItem.setRightBarButtonItems([shareBarButton, favoriteBarButton].compactMap { $0 }, animated: true)
            
            // Hide navigation toolbar
            navigationController?.setToolbarHidden(true, animated: true)
        }
    }
    
    @MainActor
    func updateBarsInSelectMode() {
        setTitleViewFromAlbumData()
        let hasImagesSelected = !selectedImageIDs.isEmpty
        cancelBarButton.isEnabled = true

        // User with admin or upload rights can do everything
        // except may be downloading images (i.e. sharing images)
        // User without admin rights cannot set album thumbnails, delete images
        // WRONG =====> 'normal' user with upload access to the current category can copy, move, edit images
        // SHOULD BE => 'normal' user having uploaded images can only edit their images.
        //              This requires 'user_id' and 'added_by' values of images for checking rights
        if user.hasUploadRights(forCatID: categoryId) {
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
            // Right side of navigation bar
            /// — guests can share photo of high-resolution or not
            /// — non-guest users can set favorites in addition
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
        
        let title: String = categoryId == Int32.zero
            ? String(localized: "tabBar_albums", bundle: piwigoKit, comment: "Albums")
            : albumData.name
        navigationItem.title = title
        view?.window?.windowScene?.title = title
        
        // No subtitle when using acessibility category or on iPhone in landscape mode
        let orientation = view.window?.windowScene?.interfaceOrientation ?? .portrait
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
                subTitle = NSLocalizedString("categoryUpdating", comment: "Updating…")
            } else {
                let numberFormatter = NumberFormatter()
                numberFormatter.numberStyle = NumberFormatter.Style.percent
                let percent = numberFormatter.string(from: NSNumber(value: progress)) ?? ""
                subTitle = NSLocalizedString("categoryUpdating", comment: "Updating…") + " " + percent
            }
        }
        else if inSelectionMode {
            let nberPhotos = selectedImageIDs.count
            switch nberPhotos {
            case 0:
                subTitle = NSLocalizedString("selectImages", comment: "Select Photos")
            case 1:
                subTitle = NSLocalizedString("selectImageSelected", comment: "1 Photo Selected")
            default:
                let nberPhotosStr = nberPhotos.formatted(.number)
                subTitle = String(format: NSLocalizedString("selectImagesSelected", comment: "%@ Photos Selected"), nberPhotosStr)
            }
        }
        else if albumData.dateGetImages > TimeInterval(86400) { // i.e. a day after minimum date
            let dateGetImages = Date(timeIntervalSinceReferenceDate: albumData.dateGetImages)
            if Date().timeIntervalSinceReferenceDate - albumData.dateGetImages < 60 {
                subTitle = NSLocalizedString("categoryUpdatedNow", comment: "Updated just now")
            } else {
                let calendar = Calendar.current
                let updatedDay = calendar.dateComponents([.day], from: dateGetImages)
                let dateDay = calendar.dateComponents([.day], from: Date())
                if updatedDay.day == dateDay.day {
                    // Album data updated today
                    let time = DateFormatter.localizedString(from: dateGetImages,
                                                             dateStyle: .none, timeStyle: .short)
                    subTitle = String(format: NSLocalizedString("categoryUpdatedAt", comment: "Updated at…"), time)
                } else {
                    // Album data updated yesterday or before
                    let date = DateFormatter.localizedString(from: dateGetImages,
                                                             dateStyle: .short, timeStyle: .none)
                    subTitle = String(format: NSLocalizedString("categoryUpdatedOn", comment: "Updated on…"), date)
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
            self.title = String(localized: "tabBar_albums", bundle: piwigoKit, comment: "Albums")
            self.view?.window?.windowScene?.title = self.title
            return
        }
        
        let title = albumData.name
        self.title = title
        self.view?.window?.windowScene?.title = title
        
        // There is no subtitle in landscape mode on iPhone
        // nor when using acessibility category
        var subtitle = ""
        let orientation = view.window?.windowScene?.interfaceOrientation ?? .portrait
        let isAccessibilityCategory = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        if !(view.traitCollection.userInterfaceIdiom == .phone && orientation.isLandscape) {
            if AlbumVars.shared.isFetchingAlbumData.contains(categoryId) && !isAccessibilityCategory {
                // Inform user that the app is fetching album data
                if progress == 0 {
                    subtitle = NSLocalizedString("categoryUpdating", comment: "Updating…")
                } else {
                    let numberFormatter = NumberFormatter()
                    numberFormatter.numberStyle = NumberFormatter.Style.percent
                    let percent = numberFormatter.string(from: NSNumber(value: progress)) ?? ""
                    subtitle = NSLocalizedString("categoryUpdating", comment: "Updating…") + " " + percent
                }
            }
            else if inSelectionMode && !isAccessibilityCategory {
                let nberPhotos = selectedImageIDs.count
                switch nberPhotos {
                case 0:
                    subtitle = NSLocalizedString("selectImages", comment: "Select Photos")
                case 1:
                    subtitle = NSLocalizedString("selectImageSelected", comment: "1 Photo Selected")
                case 2...nberPhotos:
                    var nberPhotosStr = ""
                    if #available(iOS 16, *) {
                        nberPhotosStr = nberPhotos.formatted(.number)
                    } else {
                        let numberFormatter = NumberFormatter()
                        numberFormatter.numberStyle = NumberFormatter.Style.decimal
                        nberPhotosStr = numberFormatter.string(from: NSNumber(value: nberPhotos)) ?? String(nberPhotos)
                    }
                    subtitle = String(format: NSLocalizedString("selectImagesSelected", comment: "%@ Photos Selected"), nberPhotosStr)
                default:
                    subtitle = ""
                }
            }
            else if albumData.dateGetImages > TimeInterval(86400) && !isAccessibilityCategory { // i.e. a day after minimum date
                let dateGetImages = Date(timeIntervalSinceReferenceDate: albumData.dateGetImages)
                if Date().timeIntervalSinceReferenceDate - albumData.dateGetImages < 60 {
                    subtitle = NSLocalizedString("categoryUpdatedNow", comment: "Updated just now")
                } else {
                    let calendar = Calendar.current
                    let updatedDay = calendar.dateComponents([.day], from: dateGetImages)
                    let dateDay = calendar.dateComponents([.day], from: Date())
                    if updatedDay.day == dateDay.day {
                        // Album data updated today
                        let time = DateFormatter.localizedString(from: dateGetImages,
                                                                 dateStyle: .none, timeStyle: .short)
                        subtitle = String(format: NSLocalizedString("categoryUpdatedAt", comment: "Updated at…"), time)
                    } else {
                        // Album data updated yesterday or before
                        let date = DateFormatter.localizedString(from: dateGetImages,
                                                                 dateStyle: .short, timeStyle: .none)
                        subtitle = String(format: NSLocalizedString("categoryUpdatedOn", comment: "Updated on…"), date)
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
