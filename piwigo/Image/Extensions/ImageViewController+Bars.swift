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

// MARK: Navigation Bar & Toolbar
extension ImageViewController {
    @MainActor
    func updateNavBar() {
        // Share button depends on Piwigo server version, user role and image data
        shareBarButton = getShareButton()
        
        // Favorites button depends on Piwigo server version, user role and image data
        favoriteBarButton = getFavoriteBarButton()
        
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
            if #available(iOS 26.0, *) {
                actionBarButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: menu)
            } else {
                // Fallback on previous version
                actionBarButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: menu)
            }
            actionBarButton?.accessibilityIdentifier = "actions"
            
            // Configure the navigation bar and toolbar
            if #available(iOS 26.0, *) {
                updateNavBarForAdmin(orientation: orientation)
            } else {
                // Fallback on previous version
                updateNavBarOldForAdmin(orientation: orientation)
            }
        } else {
            if #available(iOS 26.0, *) {
                updateNavBarForStdUserOrGuest(orientation: orientation)
            } else {
                // Fallback on previous version
                updateNavBarOldForStdUserOrGuest(orientation: orientation)
            }
        }
    }
    
    @MainActor @available(iOS 26.0, *)
    private func updateNavBarForAdmin(orientation: UIInterfaceOrientation) {
        // Case of users with admin or upload rights
        if view.traitCollection.userInterfaceIdiom == .phone, orientation.isPortrait {
            // Determine toolbar items
            var toolbarItems: [UIBarButtonItem?] = [shareBarButton, .space()]
            let type = pwgImageFileType(rawValue: imageData.fileType) ?? .image
            switch type {
            case .image:
                /// => [- delete] or [share - delete] or [- favorite delete] or [share - favorite delete]
                toolbarItems.append(contentsOf: [favoriteBarButton, deleteBarButton])
                
            case .video:
                /// => [- play mute - delete] or [- play favorite mute - delete] or [share - play mute - delete] or [share - play favorite mute - delete]
                toolbarItems.append(contentsOf: [playBarButton, favoriteBarButton, muteBarButton, .space(),
                                                 deleteBarButton])
                
            case .pdf:
                /// PDF   => [- goToPage delete] or [- goToPage favorite delete] or [share - goToPage delete] or [share - goToPage favorite - delete]
                toolbarItems.append(contentsOf: [goToPageButton, favoriteBarButton, deleteBarButton])
            }
            
            // We present the toolbar only if it contains at least two buttons
            let finalToolbarItems: [UIBarButtonItem] = toolbarItems.compactMap({ $0 })
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
                navigationItem.leftBarButtonItems = [backButton, playBarButton, muteBarButton, goToPageButton].compactMap {$0}
                navigationItem.rightBarButtonItems = [actionBarButton, deleteBarButton, favoriteBarButton, shareBarButton].compactMap { $0 }
            }
        }
        else {      // iPad or iPhone in landscape orientation
            // No toolbar
            isToolbarRequired = false
            setToolbarItems([], animated: false)
            navigationController?.setToolbarHidden(true, animated: true)
            
            // All buttons gathered in the navigation bar
            navigationItem.leftBarButtonItems = [backButton, playBarButton, muteBarButton, goToPageButton].compactMap {$0}
            navigationItem.rightBarButtonItems = [actionBarButton, deleteBarButton, favoriteBarButton, shareBarButton].compactMap { $0 }
        }
    }
    
    @MainActor @available(iOS 26.0, *)
    private func updateNavBarForStdUserOrGuest(orientation: UIInterfaceOrientation) {
        // Case of users without admin or upload rights
        if view.traitCollection.userInterfaceIdiom == .phone, orientation.isPortrait {
            // Determine toolbar items
            let toolbarItems: [UIBarButtonItem?] = [goToPageButton, playBarButton, favoriteBarButton, muteBarButton]
            // We get:
            /// Image => [] or [favorite]
            /// Video => [play mute] or [play favorite mute]
            /// PDF   => [goToPage] or [goToPage favorite]
            var finalToolbarItems = toolbarItems.compactMap { $0 }
            if finalToolbarItems.count == 1 { finalToolbarItems.insert(.space(), at: 0) }
            
            // Share button at right bar button?
            if shareBarButton != nil {
                // Present the toolbar if we have enough buttons
                if finalToolbarItems.count > 1 {
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
                // We present the toolbar only if it contains player controls or a PDF viewer
                if imageData.isNotImage {
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
    
    @MainActor @available(iOS, introduced: 15.0, obsoleted: 26.0, message: "Specific to iOS 15 to 18")
    private func updateNavBarOldForAdmin(orientation: UIInterfaceOrientation) {
        // Case of users with admin or upload rights
        if view.traitCollection.userInterfaceIdiom == .phone, orientation.isPortrait {
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
    
    @MainActor @available(iOS, introduced: 15.0, obsoleted: 26.0, message: "Specific to iOS 15 to 18")
    private func updateNavBarOldForStdUserOrGuest(orientation: UIInterfaceOrientation) {
        // Case of users without admin or upload rights
        if view.traitCollection.userInterfaceIdiom == .phone, orientation.isPortrait {
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
        actionBarButton?.isEnabled = state
        shareBarButton?.isEnabled = state
        deleteBarButton.isEnabled = state
        favoriteBarButton?.isEnabled = state
        playBarButton?.isEnabled = state
        muteBarButton?.isEnabled = state
        goToPageButton?.isEnabled = state
    }
    
    
    // MARK: - Title View
    @MainActor
    func setTitleViewFromImageData() {
        if #available(iOS 26.0, *) {
            setTitleView()
        } else {
            // Fallback on previous version
            setTitleViewOld()
        }
    }
    
    @MainActor @available(iOS 26.0, *)
    func setTitleView() {
        // Title
        var title = String()
        if imageData.titleStr.isEmpty {
            // No title => Use file name
            title = imageData.fileName
        } else {
            title = imageData.titleStr
        }
        
        // No subtitle when using acessibility category or when the creation date is unknown
        let tooLargeFont = traitCollection.preferredContentSizeCategory >= .accessibilityMedium
        if tooLargeFont || (imageData.dateCreated < DateUtilities.weekAfterInterval) {
            navigationItem.titleView = getTitleView(withTitle: title, titleColor: .label,
                                                    subtitle: "", subTitleColor: .label)
            return
        }
        
        // Subtitle
        var subTitle = String()
        let dateCreated = Date(timeIntervalSinceReferenceDate: imageData.dateCreated)
        let dateFormatter = DateUtilities.dateFormatter
        if view.traitCollection.userInterfaceIdiom == .pad {
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .medium   // Without time zone (unknown)
            subTitle = dateFormatter.string(from: dateCreated)
        } else {
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .medium
            subTitle = dateFormatter.string(from: dateCreated)
        }
        
        // Prepare title view
        navigationItem.titleView = getTitleView(withTitle: title, titleColor: .label,
                                                subtitle: subTitle, subTitleColor: .label)
    }
    
    @MainActor @available(iOS, introduced: 15.0, obsoleted: 26.0, message: "Specific to iOS 15 to 18")
    func setTitleViewOld() {
        // Title
        var title = String()
        if imageData.titleStr.isEmpty {
            // No title => Use file name
            title = imageData.fileName
        } else {
            title = imageData.titleStr
        }
        
        // No subtitle when using acessibility category or on iPhone in landscape mode
        // or when the creation date is unknown
        let orientation = view.window?.windowScene?.interfaceOrientation ?? .portrait
        let tooLargeFont = traitCollection.preferredContentSizeCategory >= .accessibilityMedium
        if tooLargeFont || (imageData.dateCreated < DateUtilities.weekAfterInterval) ||
            (view.traitCollection.userInterfaceIdiom == .phone && orientation.isLandscape) {
            navigationItem.titleView = getTitleView(withTitle: title, titleColor: .label,
                                                    subtitle: "", subTitleColor: .label)
            return
        }
        
        // Subtitle
        var subTitle = String()
        let dateCreated = Date(timeIntervalSinceReferenceDate: imageData.dateCreated)
        let dateFormatter = DateUtilities.dateFormatter
        if view.traitCollection.userInterfaceIdiom == .pad {
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .medium   // Without time zone (unknown)
            subTitle = dateFormatter.string(from: dateCreated)
        } else {
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .medium
            subTitle = dateFormatter.string(from: dateCreated)
        }
        
        // Prepare title view
        navigationItem.titleView = getTitleView(withTitle: title, titleColor: PwgColor.whiteCream,
                                                subtitle: subTitle, subTitleColor: PwgColor.rightLabel)
    }
    
    // The font size of the title is not updated automatically
    // for larger accessibility type sizes on iOS 26.0
    // Title/subtitle inside UIButton leads to top-right buttons misalignment
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
