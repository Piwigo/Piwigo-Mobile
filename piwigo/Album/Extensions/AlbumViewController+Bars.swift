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
        // Set title
        let isFetching = AlbumVars.shared.isFetchingAlbumData.contains(categoryId)
        setTitleViewFromAlbumData(whileUpdating: isFetching)

        // Left side of navigation bar
        if [0, AlbumVars.shared.defaultCategory].contains(categoryId) {
            // Button for accessing settings
            navigationItem.setLeftBarButtonItems([settingsBarButton].compactMap { $0 }, animated: true)
            navigationItem.hidesBackButton = true
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
        else if NetworkVars.userStatus != .guest {
            if #available(iOS 14, *) {
                // Menu for activating the selection mode or changing the way images are sorted
                actionBarButton = nil
                selectBarButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: actionMenu())
                selectBarButton?.accessibilityIdentifier = "select"
            } else {
                // Button for sorting photos
                actionBarButton = getActionBarButton()
                // Button for activating the selection mode (not for guests)
                selectBarButton = getSelectBarButton()
            }
            navigationItem.setRightBarButtonItems([actionBarButton, selectBarButton].compactMap { $0 }, animated: true)
            let hasImages = albumData.nbImages != 0
            actionBarButton?.isEnabled = hasImages
            selectBarButton?.isEnabled = hasImages
        }
        else {
            // No button
            navigationItem.setRightBarButtonItems([], animated: true)
            
            // Following 2 lines fixes situation where the Edit button remains visible
            navigationController?.navigationBar.setNeedsLayout()
            navigationController?.navigationBar.layoutIfNeeded()
        }
    }
    
    func updateBarsInPreviewMode() {
        // Hide toolbar unless it is displaying the image detail view
        if let displayedVC = navigationController?.viewControllers.last,
           !(displayedVC is ImageViewController) {
            navigationController?.setToolbarHidden(true, animated: true)
        }
        
        // Right side of navigation bar
        if categoryId == 0 {
            return
        }
        if NetworkVars.userStatus != .guest {
            if #available(iOS 14, *) {
                // Menu for activating the selection mode or change the way images are sorted
                let children = [selectMenu(), sortMenu(), viewOptionsMenu()].compactMap({$0})
                let updatedMenu = selectBarButton?.menu?.replacingChildren(children)
                selectBarButton?.menu = updatedMenu
            }
            let hasImages = albumData.nbImages != 0
            actionBarButton?.isEnabled = hasImages
            selectBarButton?.isEnabled = hasImages
        }
        else {
            // Following 2 lines fixes situation where the Edit button remains visible
            navigationController?.navigationBar.setNeedsLayout()
            navigationController?.navigationBar.layoutIfNeeded()
        }
    }
    
    
    // MARK: - Select Mode
    func initBarsInSelectMode() {
        // Hide back or Settings button
        navigationItem.hidesBackButton = true

        // Favorites button depends on Piwigo server version, user role and image data
        favoriteBarButton = getFavoriteBarButton()

        // Button displayed in all circumstances
        if #available(iOS 14, *) {
            // Interface depends on device and orientation
            let orientation = view.window?.windowScene?.interfaceOrientation ?? .portrait

            // User with admin or upload rights can do everything
            if user.hasUploadRights(forCatID: categoryId) {
                // The action button proposes:
                /// - to copy or move images to other albums
                /// - to edit image parameters
                /// - to rotate images
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
                    let toolBarItems = [shareBarButton, UIBarButtonItem.space(),
                                        favoriteBarButton, favoriteBarButton == nil ? nil : UIBarButtonItem.space(),
                                        deleteBarButton].compactMap { $0 }
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
            } else if favoriteBarButton != nil {
                if UIDevice.current.userInterfaceIdiom == .phone, orientation.isPortrait {
                    // Left side of navigation bar
                    navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)
                    
                    // No button on the right
                    navigationItem.setRightBarButtonItems([], animated: true)
                    
                    // Remaining buttons in navigation toolbar
                    navigationController?.setToolbarHidden(false, animated: true)
                    toolbarItems = [shareBarButton, UIBarButtonItem.space(), favoriteBarButton].compactMap { $0 }
                } else {
                    // All buttons in navigation bar
                    navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)
                    navigationItem.setRightBarButtonItems([favoriteBarButton, shareBarButton].compactMap { $0 }, animated: true)
                    
                    // Hide navigation toolbar
                    navigationController?.setToolbarHidden(true, animated: true)
                }
            }
            else if NetworkVars.userStatus != .guest {
                // All buttons in navigation bar
                navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)
                navigationItem.setRightBarButtonItems([shareBarButton].compactMap { $0 }, animated: true)

                // Hide navigation toolbar
                navigationController?.setToolbarHidden(true, animated: true)
            }
            else {
                // Guest cannot share images
                navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)
                navigationItem.setRightBarButtonItems([].compactMap { $0 }, animated: true)

                // Hide navigation toolbar
                navigationController?.setToolbarHidden(true, animated: true)
            }
        } else {
            // Fallback on earlier versions
            // Interface depends on device and orientation
            let orientation = UIApplication.shared.statusBarOrientation

            // User with admin or upload rights can do everything
            // WRONG =====> 'normal' user with upload access to the current category can edit images
            // SHOULD BE => 'normal' user having uploaded images can edit them. This requires 'user_id' and 'added_by'
            if user.hasUploadRights(forCatID: categoryId) {
                // The action button only proposes to edit image parameters
                actionBarButton = UIBarButtonItem(barButtonSystemItem: .edit, target: self,
                                                  action: #selector(editSelection))
                actionBarButton?.accessibilityIdentifier = "actions"

                if UIDevice.current.userInterfaceIdiom == .phone, orientation.isPortrait {
                    // Left side of navigation bar
                    navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)

                    // Right side of navigation bar
                    navigationItem.setRightBarButtonItems([actionBarButton].compactMap { $0 }, animated: true)

                    // Remaining buttons in navigation toolbar
                    /// We reset the bar button items which are not positioned correctly by iOS 15 after device rotation.
                    /// They also disappear when coming back to portrait orientation.
                    let toolBarItems = [shareBarButton, UIBarButtonItem.space(),
                                        moveBarButton, UIBarButtonItem.space(),
                                        favoriteBarButton, favoriteBarButton == nil ? nil : UIBarButtonItem.space(),
                                        deleteBarButton].compactMap { $0 }
                    navigationController?.setToolbarHidden(false, animated: true)
                    toolbarItems = toolBarItems
                } else {
                    // Left side of navigation bar
                    navigationItem.setLeftBarButtonItems([cancelBarButton, deleteBarButton, moveBarButton].compactMap { $0 }, animated: true)

                    // Right side of navigation bar
                    let rightBarButtonItems = [actionBarButton, favoriteBarButton, shareBarButton].compactMap { $0 }
                    navigationItem.setRightBarButtonItems(rightBarButtonItems, animated: true)

                    // Hide toolbar
                    navigationController?.setToolbarHidden(true, animated: true)
                }
            } else if favoriteBarButton != nil {
                if UIDevice.current.userInterfaceIdiom == .phone, orientation.isPortrait {
                    // Left side of navigation bar
                    navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)
                    
                    // No button on the right
                    navigationItem.setRightBarButtonItems([], animated: true)
                    
                    // Remaining buttons in navigation toolbar
                    navigationController?.setToolbarHidden(false, animated: true)
                    toolbarItems = [shareBarButton, UIBarButtonItem.space(), favoriteBarButton].compactMap { $0 }
                } else {
                    // Left side of navigation bar
                    navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)
                    
                    // All other buttons in navigation bar
                    navigationItem.setRightBarButtonItems([favoriteBarButton, shareBarButton].compactMap { $0 }, animated: true)
                    
                    // Hide navigation toolbar
                    navigationController?.setToolbarHidden(true, animated: true)
                }
            }
            else if NetworkVars.userStatus != .guest {
                // Non-guest can only share images
                navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)
                navigationItem.setRightBarButtonItems([shareBarButton].compactMap { $0 }, animated: true)

                // Hide toolbar
                navigationController?.setToolbarHidden(true, animated: true)
            }
            else {
                // Guest cannot share images
                navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)
                navigationItem.setRightBarButtonItems([].compactMap { $0 }, animated: true)

                // Hide toolbar
                navigationController?.setToolbarHidden(true, animated: true)
            }
        }

        // Set initial status
        updateBarsInSelectMode()
    }
    
    func updateBarsInSelectMode() {
        let hasImagesSelected = !selectedImageIds.isEmpty
        cancelBarButton.isEnabled = true

        // User with admin or upload rights can do everything
        // WRONG =====> 'normal' user with upload access to the current category can edit images
        // SHOULD BE => 'normal' user having uploaded images can edit them. This requires 'user_id' and 'added_by'
        if user.hasUploadRights(forCatID: categoryId) {
            actionBarButton?.isEnabled = hasImagesSelected
            shareBarButton.isEnabled = hasImagesSelected
            deleteBarButton.isEnabled = hasImagesSelected
            favoriteBarButton?.isEnabled = hasImagesSelected
            let selected = selectedImageIds
            let favorites = selectedFavoriteIds
            let areFavorites = selected == favorites
            favoriteBarButton?.setFavoriteImage(for: areFavorites)
            favoriteBarButton?.action = areFavorites ? #selector(removeFromFavorites) : #selector(addToFavorites)

            if #available(iOS 14, *) {
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
            shareBarButton.isEnabled = hasImagesSelected
            favoriteBarButton?.isEnabled = hasImagesSelected
            let selected = selectedImageIds
            let favorites = selectedFavoriteIds
            let areFavorites = selected == favorites
            favoriteBarButton?.setFavoriteImage(for: areFavorites)
            favoriteBarButton?.action = areFavorites ? #selector(removeFromFavorites) : #selector(addToFavorites)
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
        shareBarButton.isEnabled = state
        favoriteBarButton?.isEnabled = state
    }
        
    
    // MARK: - Title View
    func setTitleViewFromAlbumData(whileUpdating isUpdating: Bool) {
        // Title view
        if categoryId == 0 {
            title = NSLocalizedString("tabBar_albums", comment: "Albums")
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
        var lastUpdated = ""
        if !(UIDevice.current.userInterfaceIdiom == .phone &&
             UIApplication.shared.statusBarOrientation.isLandscape) {
            if isUpdating {
                // Inform user that the app is fetching album data
                lastUpdated = NSLocalizedString("categoryUpdating", comment: "Updating…")
            }
            else if albumData.dateGetImages > TimeInterval(86400) { // i.e. a day after minimum date
                let dateGetImages = Date(timeIntervalSinceReferenceDate: albumData.dateGetImages)
                if Date().timeIntervalSinceReferenceDate - albumData.dateGetImages < 60 {
                    lastUpdated = NSLocalizedString("categoryUpdatedNow", comment: "Updated just now")
                } else {
                    let calendar = Calendar.current
                    let updatedDay = calendar.dateComponents([.day], from: dateGetImages)
                    let dateDay = calendar.dateComponents([.day], from: Date())
                    if updatedDay.day == dateDay.day {
                        // Album data updated today
                        let time = DateFormatter.localizedString(from: dateGetImages,
                                                                 dateStyle: .none, timeStyle: .short)
                        lastUpdated = String(format: NSLocalizedString("categoryUpdatedAt",
                                                                       comment: "Updated at…"), time)
                    } else {
                        // Album data updated yesterday or before
                        let date = DateFormatter.localizedString(from: dateGetImages,
                                                                 dateStyle: .short, timeStyle: .none)
                        lastUpdated = String(format: NSLocalizedString("categoryUpdatedOn",
                                                                       comment: "Updated on…"), date)
                    }
                }
            }
        }
        
        // Prepare sub-title
        if lastUpdated.isEmpty == false {
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
            subTitleLabel.text = lastUpdated
            subTitleLabel.sizeToFit()
            
            var titleWidth = CGFloat(fmax(subTitleLabel.bounds.size.width, titleLabel.bounds.size.width))
            titleWidth = fmin(titleWidth, (navigationController?.view.bounds.size.width ?? 0.0) * 0.4)
            let twoLineTitleView = UIView(frame: CGRect(x: 0, y: 0, width: CGFloat(titleWidth),
                                                        height: titleLabel.bounds.size.height + subTitleLabel.bounds.size.height))
            navigationItem.titleView = twoLineTitleView
            
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
        } else {
            let titleWidth = CGFloat(fmin(titleLabel.bounds.size.width, view.bounds.size.width * 0.4))
            titleLabel.sizeThatFits(CGSize(width: titleWidth, height: titleLabel.bounds.size.height))
            let oneLineTitleView = UIView(frame: CGRect(x: 0, y: 0, width: CGFloat(titleWidth), height: titleLabel.bounds.size.height))
            navigationItem.titleView = oneLineTitleView

            oneLineTitleView.addSubview(titleLabel)
            oneLineTitleView.addConstraint(NSLayoutConstraint.constraintView(titleLabel, toWidth: titleWidth)!)
            oneLineTitleView.addConstraints(NSLayoutConstraint.constraintCenter(titleLabel)!)
        }
    }
}
