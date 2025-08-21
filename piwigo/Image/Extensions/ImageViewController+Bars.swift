//
//  ImageViewController+Bars.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 07/03/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

extension ImageViewController {
    // MARK: Navigation Bar & Toolbar
    @MainActor
    func updateNavBar() {
        // Share button depends on Piwigo server version, user role and image data
        shareBarButton = getShareButton()
        // Favorites button depends on Piwigo server version, user role and image data
        favoriteBarButton = getFavoriteBarButton()

        if #available(iOS 14, *) {
            updateNavBarNew()
        } else {
            // Fallback on earlier versions
            updateNavBarOld()
        }
    }
    
    @available(iOS 14, *) @MainActor
    private func updateNavBarNew() {
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
            /// - to set the image as album thumbnail
            /// - to rotate a photo clockwise or counterclockwise,
            /// - to edit image parameters,
            let menu = UIMenu(title: "", children: [albumMenu(), goToMenu(), editMenu()].compactMap({$0}))
            actionBarButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: menu)
            actionBarButton?.accessibilityIdentifier = "actions"
            
            if UIDevice.current.userInterfaceIdiom == .phone, orientation.isPortrait {
                // Determine toolbar items
                var toolbarItems = [UIBarButtonItem?]()
                toolbarItems.append(contentsOf: [shareBarButton == nil ? nil : .space(), shareBarButton])
                toolbarItems.append(contentsOf: [goToPageButton == nil ? nil : .space(), goToPageButton])
                toolbarItems.append(contentsOf: [playBarButton == nil ? nil : .space(), playBarButton])
                toolbarItems.append(contentsOf: [favoriteBarButton == nil ? nil : .space(), favoriteBarButton])
                toolbarItems.append(contentsOf: [muteBarButton == nil ? nil : .space(), muteBarButton])
                toolbarItems.append(contentsOf: [.space(), deleteBarButton])
                // We get:
                /// Image => [- delete] or [- share - delete] or [- share - favorite - delete]
                /// Video => [- share - play - mute - delete] or [- share - play - favorite - mute - delete]
                /// PDF   => [- share - goToPage - delete] or [- share - goToPage - favorite - delete]
                
                var finalToolbarItems = toolbarItems.compactMap { $0 }
                if finalToolbarItems.count == 4 { finalToolbarItems.append(.space()) }
                if finalToolbarItems.count >= 6 { finalToolbarItems.remove(at: 0) }
                // We finally get:
                /// Image => [- delete] or [- share - delete -] or [share - favorite - delete]
                /// Video => [share - play - mute - delete] or [share - play - favorite - mute - delete]
                /// PDF   => [share - goToPage - delete] or [share - goToPage - favorite - delete]

                // We present the toolbar only if it contains at least two buttons
                if finalToolbarItems.count > 2 {
                    // Show toolbar
                    isToolbarRequired = true
                    setToolbarItems(finalToolbarItems, animated: false)
                    let isNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
                    navigationController?.setToolbarHidden(isNavigationBarHidden, animated: true)

                    // Set buttons in the navigation bar
                    navigationItem.leftBarButtonItems = [backButton].compactMap {$0}
                    navigationItem.rightBarButtonItems = [actionBarButton].compactMap {$0}
                }
                else {
                    // No toolbar
                    isToolbarRequired = false
                    setToolbarItems([], animated: false)
                    navigationController?.setToolbarHidden(true, animated: true)

                    // Remaining buttons gathered in the navigation bar
                    navigationItem.leftBarButtonItems = [backButton, playBarButton, muteBarButton].compactMap {$0}
                    navigationItem.rightBarButtonItems = [actionBarButton, deleteBarButton, favoriteBarButton, shareBarButton].compactMap { $0 }
                }
            }
            else {      // iPad or iPhone in landscape orientation
                // No toolbar
                isToolbarRequired = false
                setToolbarItems([], animated: false)
                navigationController?.setToolbarHidden(true, animated: true)

                // All buttons gathered in the navigation bar
                navigationItem.leftBarButtonItems = [backButton, playBarButton, muteBarButton].compactMap {$0}
                navigationItem.rightBarButtonItems = [actionBarButton, deleteBarButton, favoriteBarButton, shareBarButton].compactMap { $0 }
            }
        }
        else {      // Case of users without admin or upload rights
            updateBarForStdUserOrGuest(for: orientation)
        }
    }
    
    @MainActor
    private func updateNavBarOld() {
        // Interface depends on device and orientation
        let orientation = UIApplication.shared.statusBarOrientation
        
        // User with admin or upload rights can do everything
        // WRONG =====> 'normal' user with upload access to the current category can edit images
        // SHOULD BE => 'normal' user having uploaded images can edit them. This requires 'user_id' and 'added_by' values of images for checking rights
        if user.hasUploadRights(forCatID: categoryId) {
            // Navigation bar
            // The action menu is simply an Edit button
            actionBarButton = UIBarButtonItem(barButtonSystemItem: .edit,
                                              target: self, action: #selector(editImage))
            actionBarButton?.accessibilityIdentifier = "edit"
            navigationItem.leftBarButtonItems = [backButton, playBarButton].compactMap {$0}
            navigationItem.rightBarButtonItems = [actionBarButton, muteBarButton, goToPageButton].compactMap { $0 }

            // Navigation toolbar
            isToolbarRequired = true
            let isNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
            var toolbarItems = [UIBarButtonItem?]()
            // [share - move - favorite - setThumb - delete]
            toolbarItems.append(contentsOf: [shareBarButton, shareBarButton == nil ? nil : .space()])
            toolbarItems.append(contentsOf: [moveBarButton, .space()])
            toolbarItems.append(contentsOf: [favoriteBarButton, favoriteBarButton == nil ? nil : .space()])
            toolbarItems.append(contentsOf: [setThumbnailBarButton, .space()])
            toolbarItems.append(deleteBarButton)
            setToolbarItems(toolbarItems.compactMap { $0 }, animated: false)
            navigationController?.setToolbarHidden(isNavigationBarHidden, animated: true)
        }
        else {      // Case of users without admin or upload rights
            updateBarForStdUserOrGuest(for: orientation)
        }
    }
    
    @MainActor
    private func updateBarForStdUserOrGuest(for orientation: UIInterfaceOrientation) {
        if UIDevice.current.userInterfaceIdiom == .phone, orientation.isPortrait {
            // Determine toolbar items
            var toolbarItems = [UIBarButtonItem?]()
            toolbarItems.append(contentsOf: [goToPageButton == nil ? nil : .space(), goToPageButton])
            toolbarItems.append(contentsOf: [playBarButton == nil ? nil : .space(), playBarButton])
            toolbarItems.append(contentsOf: [favoriteBarButton == nil ? nil : .space(), favoriteBarButton])
            toolbarItems.append(contentsOf: [muteBarButton == nil ? nil : .space(), muteBarButton])
            // We get:
            /// Image => [] or [- favorite]
            /// Video => [- play - mute] or [- play - favorite - mute]
            /// PDF   => [- goToPage] or [- goToPage - favorite]

            var finalToolbarItems = toolbarItems.compactMap { $0 }
            if finalToolbarItems.count == 4 { finalToolbarItems.append(.space()) }
            if finalToolbarItems.count == 6 { finalToolbarItems.remove(at: 0) }
            // We finally get:
            /// Image => [] or [- favorite]
            /// Video => [- play - mute -] or [play - favorite - mute]
            /// PDF   => [- goToPage] or [- goToPage - favorite -]

            // Share button at right bar button?
            if shareBarButton != nil {
                // Present the toolbar if we have enough buttons
                if finalToolbarItems.count == 5 {
                    // Show toolbar with
                    isToolbarRequired = true
                    setToolbarItems(finalToolbarItems, animated: false)
                    let isNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
                    navigationController?.setToolbarHidden(isNavigationBarHidden, animated: true)
                    
                    // Buttons not related to video player or PDF viewer in the navigation bar
                    navigationItem.leftBarButtonItems = [backButton].compactMap {$0}
                    navigationItem.rightBarButtonItems = [shareBarButton].compactMap { $0 }
                }
                else {
                    // goToPage or favorite alone —> No toolbar
                    isToolbarRequired = false
                    setToolbarItems([], animated: false)
                    navigationController?.setToolbarHidden(true, animated: true)
                    
                    // Navigation bar
                    navigationItem.leftBarButtonItems = [backButton].compactMap {$0}
                    navigationItem.rightBarButtonItems = [shareBarButton, goToPageButton, favoriteBarButton].compactMap { $0 }
                }
            }
            else {
                // We present the toolbar only if it contains player controls
                if imageData.isVideo {
                    // Show toolbar with player controls
                    isToolbarRequired = true
                    setToolbarItems(finalToolbarItems, animated: false)
                    let isNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
                    navigationController?.setToolbarHidden(isNavigationBarHidden, animated: true)
                    
                    // Buttons w/o player controls in the navigation bar
                    navigationItem.leftBarButtonItems = [backButton].compactMap {$0}
                    navigationItem.rightBarButtonItems = [goToPageButton, favoriteBarButton].compactMap { $0 }
                }
                else {
                    // No toolbar
                    isToolbarRequired = false
                    setToolbarItems([], animated: false)
                    navigationController?.setToolbarHidden(true, animated: true)
                    
                    // Buttons w/o player controls in the navigation bar
                    navigationItem.leftBarButtonItems = [backButton].compactMap {$0}
                    navigationItem.rightBarButtonItems = [goToPageButton, favoriteBarButton].compactMap { $0 }
                }
            }
        } else {      // iPad or iPhone in landscape orientation
            // No toolbar
            isToolbarRequired = false
            setToolbarItems([], animated: false)
            navigationController?.setToolbarHidden(true, animated: true)

            // All buttons gathered in the navigation bar
            navigationItem.leftBarButtonItems = [backButton, playBarButton, muteBarButton, goToPageButton].compactMap {$0}
            navigationItem.rightBarButtonItems = [shareBarButton, favoriteBarButton].compactMap { $0 }
        }
    }
    
    // Buttons are disabled (greyed) when retrieving image data
    // They are also disabled during an action
    @MainActor
    func setEnableStateOfButtons(_ state: Bool) {
//        debugPrint("••> \(state ? "Enable" : "Disable") buttons")
        actionBarButton?.isEnabled = state
        shareBarButton?.isEnabled = state
        moveBarButton.isEnabled = state
        setThumbnailBarButton.isEnabled = state
        deleteBarButton.isEnabled = state
        favoriteBarButton?.isEnabled = state
        playBarButton?.isEnabled = state
        muteBarButton?.isEnabled = state
        goToPageButton?.isEnabled = state
    }


    // MARK: - Title View
    @MainActor
    func setTitleViewFromImageData() {
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
        if imageData.title.string.isEmpty == false {
            let wholeRange = NSRange(location: 0, length: imageData.title.string.count)
            let style = NSMutableParagraphStyle()
            style.alignment = NSTextAlignment.center
            let attributes = [
                NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                NSAttributedString.Key.paragraphStyle: style
            ]
            let attTitle = NSMutableAttributedString(attributedString: imageData.title)
            attTitle.addAttributes(attributes, range: wholeRange)
            titleLabel.attributedText = attTitle
        } else {
            // No title => Use file name
            titleLabel.text = imageData.fileName
        }
        titleLabel.sizeToFit()

        // There is no subtitle in landscape mode on iPhone or when the creation date is unknown
        if ((UIDevice.current.userInterfaceIdiom == .phone) &&
            (UIApplication.shared.statusBarOrientation.isLandscape)) ||
            imageData.dateCreated < DateUtilities.weekAfterInterval { // i.e. a week after unknown date
            let titleWidth = CGFloat(fmin(titleLabel.bounds.size.width, view.bounds.size.width * 0.4))
            titleLabel.sizeThatFits(CGSize(width: titleWidth, height: titleLabel.bounds.size.height))
            let oneLineTitleView = UIView(frame: CGRect(x: 0, y: 0, width: CGFloat(titleWidth), height: titleLabel.bounds.size.height))
            navigationItem.titleView = oneLineTitleView

            oneLineTitleView.addSubview(titleLabel)
            oneLineTitleView.addConstraint(NSLayoutConstraint.constraintView(titleLabel, toWidth: titleWidth)!)
            oneLineTitleView.addConstraints(NSLayoutConstraint.constraintCenter(titleLabel)!)
        }
        else {
            let dateCreated = Date(timeIntervalSinceReferenceDate: imageData.dateCreated)
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
            let dateFormatter = DateUtilities.dateFormatter()
            if UIDevice.current.userInterfaceIdiom == .pad {
                dateFormatter.dateStyle = .long
                dateFormatter.timeStyle = .medium   // Without time zone (unknown)
                subTitleLabel.text = dateFormatter.string(from: dateCreated)
            } else {
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .medium
                subTitleLabel.text = dateFormatter.string(from: dateCreated)
            }
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
        }
    }
}
