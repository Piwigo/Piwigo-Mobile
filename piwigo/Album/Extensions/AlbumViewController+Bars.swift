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
    func initBarsInPreviewMode() {
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
            if #available(iOS 14.0, *) {
                navigationItem.backButtonDisplayMode = view.bounds.size.width > minWidthForDefaultBackButton ? .default : .generic
            }
        }

        // Right side of navigation bar
        if categoryId == 0 {
            // Root album => Discover menu button
            navigationItem.setRightBarButtonItems([discoverBarButton].compactMap { $0 }, animated: true)
        }
        else if categoryId == pwgSmartAlbum.search.rawValue {
            // Search bar => No action button
            navigationItem.setRightBarButtonItems([], animated: true)
        }
        else {
            // Share button depends on Piwigo server version, user role and image data
            shareBarButton = getShareBarButton()
            // Favorites button depends on Piwigo server version, user role and image data
            favoriteBarButton = getFavoriteBarButton()

            if #available(iOS 14, *) {
                // Menu for activating the selection mode and changing the way images are sorted
                initRightSideInPreviewModeNew()
            } else {
                // Button for selecting and sorting photos
                initRightSideInPreviewModeOld()
            }
        }
    }
    
    @available(iOS 14, *)
    private func initRightSideInPreviewModeNew() {
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

    private func initRightSideInPreviewModeOld() {
        // Button for sorting photos
        actionBarButton = getSortBarButton()
        
        // Button for activating the selection mode
        selectBarButton = shareBarButton != nil || favoriteBarButton != nil ? getSelectBarButton() : nil
        
        // Set right bar buttons
        navigationItem.setRightBarButtonItems([actionBarButton, selectBarButton].compactMap { $0 }, animated: true)
        let hasImages = albumData.nbImages != 0
        actionBarButton?.isEnabled = hasImages
    }

    @MainActor
    func updateBarsInPreviewMode() {
        // Hide toolbar unless it is displaying the image detail view
        if let displayedVC = navigationController?.viewControllers.last,
           !(displayedVC is ImageViewController) {
            navigationController?.setToolbarHidden(true, animated: true)
        }
        
        // Right side of navigation bar
        if [0, pwgSmartAlbum.search.rawValue].contains(categoryId) {
            return
        }
        
        // Share button depends on Piwigo server version, user role and image data
        shareBarButton = getShareBarButton()
        
        let hasImages = albumData.nbImages != 0
        if #available(iOS 14, *) {
            // Menu for activating the selection mode or change the way images are sorted
            var children = [sortMenu(), viewOptionsMenu()]
            if shareBarButton != nil || favoriteBarButton != nil {
                children.insert(selectMenu(), at: 0)
            }
            let updatedMenu = selectBarButton?.menu?.replacingChildren(children.compactMap({$0}))
            selectBarButton?.menu = updatedMenu
            selectBarButton?.isEnabled = hasImages
        } else {
            actionBarButton?.isEnabled = hasImages
        }
    }
    
    
    // MARK: - Select Mode
    func initBarsInSelectMode() {
        // Hide back or Settings button
        navigationItem.hidesBackButton = true

        // Share button depends on Piwigo server version, user role and image data
        shareBarButton = getShareBarButton()

        // Button displayed in all circumstances
        if #available(iOS 14, *) {
            initBarsInSelectModeNew()
        } else {
            // Fallback on earlier versions
            initBarsInSelectModeOld()
        }

        // Set initial status
        updateBarsInSelectMode()
    }
    
    @available(iOS 14.0, *)
    private func initBarsInSelectModeNew() {
        // Interface depends on device and orientation
        let orientation = view.window?.windowScene?.interfaceOrientation ?? .portrait

        // User with admin or upload rights can do everything
        // except may be downloading images (i.e. sharing images)
        // User without admin rights cannot set album thumbnails, delete images
        // WRONG =====> 'normal' user with upload access to the current category can copy, move, edit images
        // SHOULD BE => 'normal' user having uploaded images can only edit their images.
        //              This requires 'user_id' and 'added_by' values of images for checking rights
        if user.hasUploadRights(forCatID: categoryId) {
            // The action button proposes:
            /// - to copy or move images to other albums
            /// - to rotate a photo clockwise or counterclockwise,
            /// - to edit image parameters
            let menu = UIMenu(title: "", children: [albumMenu(), imagesMenu()])
            actionBarButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle.fill"), menu: menu)
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
        } else {
            initBarsInSelectModeForStdUserOrGuest(for: orientation)
        }
    }

    private func initBarsInSelectModeOld() {
        // Interface depends on device and orientation
        let orientation = UIApplication.shared.statusBarOrientation

        // User with admin or upload rights can do everything
        // except may be downloading images (i.e. sharing images)
        // User without admin rights cannot set album thumbnails, delete images
        // WRONG =====> 'normal' user with upload access to the current category can copy, move, edit images
        // SHOULD BE => 'normal' user having uploaded images can only edit their images.
        //              This requires 'user_id' and 'added_by' values of images for checking rights
        if user.hasUploadRights(forCatID: categoryId) {
            // Button for rotating photos
            actionBarButton = getActionBarButton()
            // Button for editing properties
            selectBarButton = getEditBarButton()

            if UIDevice.current.userInterfaceIdiom == .phone, orientation.isPortrait {
                // Left side of navigation bar
                navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)

                // Right side of navigation bar
                navigationItem.setRightBarButtonItems([actionBarButton, selectBarButton].compactMap { $0 }, animated: true)

                // Remaining buttons in navigation toolbar
                /// We reset the bar button items which are not positioned correctly by iOS 15 after device rotation.
                /// They also disappear when coming back to portrait orientation.
                let toolBarItems = [shareBarButton, shareBarButton == nil ? nil : .space(),
                                    moveBarButton, .space(),
                                    favoriteBarButton, favoriteBarButton == nil ? nil : UIBarButtonItem.space(),
                                    deleteBarButton].compactMap { $0 }
                navigationController?.setToolbarHidden(false, animated: true)
                toolbarItems = toolBarItems
            } else {
                // Left side of navigation bar
                navigationItem.setLeftBarButtonItems([cancelBarButton, deleteBarButton, moveBarButton].compactMap { $0 }, animated: true)

                // Right side of navigation bar
                let rightBarButtonItems = [selectBarButton, actionBarButton, favoriteBarButton, shareBarButton].compactMap { $0 }
                navigationItem.setRightBarButtonItems(rightBarButtonItems, animated: true)

                // Hide toolbar
                navigationController?.setToolbarHidden(true, animated: true)
            }
        } else {
            initBarsInSelectModeForStdUserOrGuest(for: orientation)
        }
    }

    private func initBarsInSelectModeForStdUserOrGuest(for orientation: UIInterfaceOrientation) {
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

            if #available(iOS 14, *) {
                // Update menu
                let children = [albumMenu(), imagesMenu()].compactMap({$0})
                let updatedMenu = actionBarButton?.menu?.replacingChildren(children)
                actionBarButton?.menu = updatedMenu
            } else {
                moveBarButton.isEnabled = hasImagesSelected
            }
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
        moveBarButton.isEnabled = state
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
        // Title view
        if categoryId == 0 {
            title = NSLocalizedString("tabBar_albums", comment: "Albums")
            if #available(iOS 13.0, *) {
                self.view?.window?.windowScene?.title = title
            }
            return
        } else {
            title = albumData.name
            if #available(iOS 13.0, *) {
                self.view?.window?.windowScene?.title = albumData.name
            }
        }
        
        // Create label programmatically
        let titleLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        titleLabel.backgroundColor = UIColor.clear
        titleLabel.textColor = .piwigoColorWhiteCream()
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
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            NSAttributedString.Key.paragraphStyle: style
        ]
        let attTitle = NSMutableAttributedString(string: albumData.name)
        attTitle.addAttributes(attributes, range: wholeRange)
        titleLabel.attributedText = attTitle
        titleLabel.sizeToFit()

        // There is no subtitle in landscape mode on iPhone
        var subtitle = ""
        if !(UIDevice.current.userInterfaceIdiom == .phone &&
             UIApplication.shared.statusBarOrientation.isLandscape) {
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
            subTitleLabel.textColor = .piwigoColorWhiteCream()
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
