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
            // Left side of navigation bar
            if [0, AlbumVars.shared.defaultCategory, pwgSmartAlbum.search.rawValue].contains(categoryId) {
                // No button in root, search and default albums
                navigationItem.setLeftBarButtonItems([], animated: true)
                navigationItem.hidesBackButton = true
            } else {
                // Back button to parent album
                navigationItem.setLeftBarButtonItems([], animated: true)
                navigationItem.hidesBackButton = false
                navigationItem.backButtonDisplayMode = view.bounds.size.width > minWidthForDefaultBackButton ? .default : .generic
            }
            
            // Right side of navigation bar and toolbar
            if categoryId == 0 {
                // Root album => Discover menu button in navigation bar
                let items = [discoverBarButton].compactMap { $0 }
                navigationItem.setRightBarButtonItems(items, animated: true)
                
                // [Search] and [Create Album] buttons in the tollbar
                let searchBarButton = navigationItem.searchBarPlacementBarButtonItem
                let toolBarItems = [.space(), addAlbumBarButton, searchBarButton].compactMap { $0 }
                navigationController?.setToolbarHidden(false, animated: true)
                toolbarItems = toolBarItems
            }
            else if categoryId == pwgSmartAlbum.search.rawValue {
                // Search bar => integrated into the toolbar
                navigationItem.preferredSearchBarPlacement = .integrated
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
                if categoryId == AlbumVars.shared.defaultCategory {
                    children.append(settingsMenu())
                }
                let menu = UIMenu(title: "", children: children.compactMap({$0}))
                selectBarButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: menu)
                selectBarButton?.accessibilityIdentifier = "select"
                
                // Set right bar buttons
                navigationItem.setRightBarButtonItems([selectBarButton].compactMap { $0 }, animated: true)
                let hasImages = albumData.nbImages != 0
                selectBarButton?.isEnabled = hasImages
                
                // [Add Photos] and [Create Album] buttons in the tollbar
                let toolBarItems = [.space(), addAlbumBarButton, addImageBarButton].compactMap { $0 }
                navigationController?.setToolbarHidden(false, animated: true)
                toolbarItems = toolBarItems
            }
        }
        else {
            // Fallback on previous version
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
                navigationItem.backButtonDisplayMode = view.bounds.size.width > minWidthForDefaultBackButton ? .default : .generic
            }

            // Right side of navigation bar
            if categoryId == 0 {
                // Root album => Discover menu button
                navigationItem.setRightBarButtonItems([discoverBarButton].compactMap { $0 }, animated: true)
            }
            else if categoryId == pwgSmartAlbum.search.rawValue {
                // Search bar => No action button and no toolbar
                navigationItem.setRightBarButtonItems([], animated: true)
                navigationController?.setToolbarHidden(true, animated: true)
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
    }
    
    @MainActor
    func updateBarsInPreviewMode() {
        // Right side of navigation bar
        if #available(iOS 26.0, *) {
            // Share button depends on Piwigo server version, user role and image data
            shareBarButton = getShareBarButton()
            
            // Menu for activating the selection mode or change the way images are sorted
            var children = [sortMenu(), viewOptionsMenu()]
            if shareBarButton != nil || favoriteBarButton != nil {
                children.insert(selectMenu(), at: 0)
            }
            if categoryId != 0, categoryId == AlbumVars.shared.defaultCategory {
                children.append(settingsMenu())
            }
            let updatedMenu = selectBarButton?.menu?.replacingChildren(children.compactMap({$0}))
            selectBarButton?.menu = updatedMenu
            selectBarButton?.isEnabled = albumData.nbImages != 0
        }
        else {
            // Hide toolbar unless it is displaying the image detail view
            if let displayedVC = navigationController?.viewControllers.last,
               !(displayedVC is ImageViewController) {
                navigationController?.setToolbarHidden(true, animated: true)
            }

            // Fallback on previous version
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
            actionBarButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle.fill"), menu: menu)
        }
        actionBarButton?.accessibilityIdentifier = "actions"

        if UIDevice.current.userInterfaceIdiom == .phone, orientation.isPortrait {
            // Left side of navigation bar
            navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)

            // Right side of navigation bar
            navigationItem.setRightBarButtonItems([actionBarButton].compactMap { $0 }, animated: true)

            // Remaining buttons in navigation toolbar
            /// We reset the bar button items which are not positioned correctly by iOS 15 after device rotation.
            /// They also disappear when coming back to portrait orientation.
            /// [share - delete] or [ favorite - delete ] or [share - favorite - delete]
            let toolBarItems = [shareBarButton, .space(),
                                favoriteBarButton, favoriteBarButton == nil ? nil : .space(),
                                deleteBarButton, shareBarButton == nil ? .space() : nil].compactMap { $0 }
            navigationController?.setToolbarHidden(false, animated: true)
            toolbarItems = toolBarItems
        } else {
            // Left side of navigation bar
            navigationItem.setLeftBarButtonItems([cancelBarButton, deleteBarButton].compactMap { $0 }, animated: true)

            // Right side of navigation bar
            let rightBarButtonItems = [actionBarButton, favoriteBarButton, shareBarButton].compactMap { $0 }
            navigationItem.setRightBarButtonItems(rightBarButtonItems, animated: true)

            // Hide toolbar
            navigationController?.setToolbarHidden(true, animated: true)
        }
    }
    
    @MainActor
    private func initBarsInSelectModeForStdUserOrGuest(orientation: UIInterfaceOrientation) {
        // Left side of navigation bar
        navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)

        // Right side and toolbar
        if UIDevice.current.userInterfaceIdiom == .phone, orientation.isPortrait {
            // Remaining two buttons
            // Button on the right
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
        if [0, pwgSmartAlbum.search.rawValue].contains(categoryId) {
            title = String(localized: "tabBar_albums", bundle: piwigoKit, comment: "Albums")
            self.view?.window?.windowScene?.title = title
            navigationItem.attributedTitle = TableViewUtilities.shared.attributedTitleForAlbum(title)
            return
        }
        title = albumData.name
        self.view?.window?.windowScene?.title = albumData.name
        navigationItem.attributedTitle = TableViewUtilities.shared.attributedTitleForAlbum(albumData.name)

        // Get subTitle
        var subTitle = ""
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
            case 2...nberPhotos:
                let nberPhotosStr = nberPhotos.formatted(.number)
                subTitle = String(format: NSLocalizedString("selectImagesSelected", comment: "%@ Photos Selected"), nberPhotosStr)
            default:
                break
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
        
        // Apply attributes to subTitle
        navigationItem.attributedSubtitle = TableViewUtilities.shared.attributedSubTitleForAlbum(subTitle)
    }
    
    @MainActor @available(iOS, introduced: 15.0, deprecated: 26.0, message: "Specific to iOS 15 to 18")
    func setTitleViewOld(progress: Float = 0) {
        // Title view
        if [0, pwgSmartAlbum.search.rawValue].contains(categoryId) {
            title = String(localized: "tabBar_albums", bundle: piwigoKit, comment: "Albums")
            self.view?.window?.windowScene?.title = title
            return
        } else {
            title = albumData.name
            self.view?.window?.windowScene?.title = albumData.name
        }
        
        // Create label programmatically
        let titleLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        titleLabel.backgroundColor = UIColor.clear
        titleLabel.textColor = PwgColor.whiteCream
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.adjustsFontSizeToFitWidth = false
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.allowsDefaultTighteningForTruncation = true
        let wholeRange = NSRange(location: 0, length: albumData.name.count)
        let style = NSMutableParagraphStyle()
        style.alignment = NSTextAlignment.center
        let attributes = [
            NSAttributedString.Key.foregroundColor: PwgColor.whiteCream,
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            NSAttributedString.Key.paragraphStyle: style
        ]
        let attTitle = NSMutableAttributedString(string: albumData.name)
        attTitle.addAttributes(attributes, range: wholeRange)
        titleLabel.attributedText = attTitle
        titleLabel.sizeToFit()
        
        // There is no subtitle in landscape mode on iPhone
        var subtitle = ""
        let orientation = view.window?.windowScene?.interfaceOrientation ?? .portrait
        if !(UIDevice.current.userInterfaceIdiom == .phone && orientation.isLandscape) {
            if AlbumVars.shared.isFetchingAlbumData.contains(categoryId) {
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
            else if inSelectionMode {
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
            else if albumData.dateGetImages > TimeInterval(86400) { // i.e. a day after minimum date
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
        
        // Prepare sub-title
        if subtitle.isEmpty == false {
            let subTitleLabel = UILabel(frame: CGRect(x: 0.0, y: titleLabel.frame.size.height, width: 0, height: 0))
            subTitleLabel.backgroundColor = UIColor.clear
            subTitleLabel.textColor = PwgColor.whiteCream
            subTitleLabel.textAlignment = .center
            subTitleLabel.numberOfLines = 1
            subTitleLabel.translatesAutoresizingMaskIntoConstraints = false
            subTitleLabel.font = .systemFont(ofSize: 10)
            subTitleLabel.adjustsFontSizeToFitWidth = false
            subTitleLabel.lineBreakMode = .byTruncatingTail
            subTitleLabel.allowsDefaultTighteningForTruncation = true
            subTitleLabel.text = subtitle
            subTitleLabel.sizeToFit()
            
            var titleWidth = CGFloat(fmax(subTitleLabel.bounds.size.width, titleLabel.bounds.size.width))
            titleWidth = fmin(titleWidth, (navigationController?.view.bounds.size.width ?? 0.0) * 0.4)
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
            navigationItem.titleView = twoLineTitleView
        } else {
            let titleWidth = CGFloat(fmin(titleLabel.bounds.size.width, view.bounds.size.width * 0.4))
            titleLabel.sizeThatFits(CGSize(width: titleWidth, height: titleLabel.bounds.size.height))
            let oneLineTitleView = UIView(frame: CGRect(x: 0, y: 0, width: CGFloat(titleWidth), height: titleLabel.bounds.size.height))
            oneLineTitleView.addSubview(titleLabel)
            oneLineTitleView.addConstraint(NSLayoutConstraint.constraintView(titleLabel, toWidth: titleWidth)!)
            oneLineTitleView.addConstraints(NSLayoutConstraint.constraintCenter(titleLabel)!)
            navigationItem.titleView = oneLineTitleView
        }
    }
}
