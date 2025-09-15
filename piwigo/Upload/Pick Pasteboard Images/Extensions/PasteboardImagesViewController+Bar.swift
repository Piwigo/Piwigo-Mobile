//
//  PasteboardImagesViewController+Bar.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 17/08/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

// MARK: Navigation Bar & Buttons
extension PasteboardImagesViewController {
    
    // MARK: - Navigation Bar
    func updateNavBar() {
        // Buttons
        let nberOfSelectedImages = selectedImages.compactMap{ $0 }.count
        let hasSelectedImages = nberOfSelectedImages > 0
        cancelBarButton.isEnabled = hasSelectedImages
        uploadBarButton.isEnabled = hasSelectedImages

        // Left side of navigation bar
        if hasSelectedImages {
            // Display "Cancel" button
            navigationItem.leftBarButtonItems = [cancelBarButton].compactMap { $0 }
        } else {
            // Display "Back" button
            navigationItem.leftBarButtonItems = []
        }

        // Title and subtitle
        if #available(iOS 26.0, *) {
            // Title
            title = NSLocalizedString("categoryUpload_pasteboard", comment: "Clipboard")
            
            // Subtitle
            if hasSelectedImages {
                let subtitle = nberOfSelectedImages == 1
                    ? NSLocalizedString("selectImageSelected", comment: "1 Photo Selected")
                    : String(format:NSLocalizedString("selectImagesSelected", comment: "%@ Photos Selected"), NSNumber(value: nberOfSelectedImages))
                navigationItem.subtitle = subtitle
            }
            else {
                let subtitle = NSLocalizedString("selectImages", comment: "Select Photos")
                navigationItem.subtitle = subtitle
            }
        } else {
            // Fallback on previous version
            setTitleView(withCount: nberOfSelectedImages)
        }

        // Right side of the navigation bar
        updateActionButton()
        if #available(iOS 26.0, *) {
            navigationItem.rightBarButtonItems = [uploadBarButton, .space(),
                                                  actionBarButton].compactMap { $0 }
        }
        else {
            navigationItem.rightBarButtonItems = [uploadBarButton, actionBarButton].compactMap { $0 }
        }
    }
    
    @MainActor @available(iOS, introduced: 15.0, deprecated: 26.0, message: "Specific to iOS 15 to 18")
    func setTitleView(withCount count: Int? = nil) {
        let title = NSLocalizedString("categoryUpload_pasteboard", comment: "Clipboard")
        
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
        let wholeRange = NSRange(location: 0, length: title.count)
        let style = NSMutableParagraphStyle()
        style.alignment = NSTextAlignment.center
        let attributes = [
            NSAttributedString.Key.foregroundColor: PwgColor.whiteCream,
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            NSAttributedString.Key.paragraphStyle: style
        ]
        let attTitle = NSMutableAttributedString(string: title)
        attTitle.addAttributes(attributes, range: wholeRange)
        titleLabel.attributedText = attTitle
        titleLabel.sizeToFit()
        
        // There is no subtitle in landscape mode on iPhone
        var subtitle = ""
        let orientation = view.window?.windowScene?.interfaceOrientation ?? .portrait
        if !(UIDevice.current.userInterfaceIdiom == .phone && orientation.isLandscape) {
            let nberOfSelectedImages = count ?? selectedImages.compactMap{ $0 }.count
            switch nberOfSelectedImages {
            case 0:
                subtitle = NSLocalizedString("selectImages", comment: "Select Photos")
            case 1:
                subtitle = NSLocalizedString("selectImageSelected", comment: "1 Photo Selected")
            case 2...nberOfSelectedImages:
                var nberPhotosStr = ""
                if #available(iOS 16, *) {
                    nberPhotosStr = nberOfSelectedImages.formatted(.number)
                } else {
                    let numberFormatter = NumberFormatter()
                    numberFormatter.numberStyle = NumberFormatter.Style.decimal
                    nberPhotosStr = numberFormatter.string(from: NSNumber(value: nberOfSelectedImages)) ?? String(nberOfSelectedImages)
                }
                subtitle = String(format: NSLocalizedString("selectImagesSelected", comment: "%@ Photos Selected"), nberPhotosStr)
            default:
                subtitle = ""
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


    // MARK: - Action Button
    func updateActionButton() {
        // The action button proposes:
        /// - to allow/disallow  re-uploading photos
        if let child = getMenuForReuploadingPhotos() {
            let menu = UIMenu(title: "", children: [child])
            if #available(iOS 26.0, *) {
                actionBarButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: menu)
            } else {
                // Fallback on previous version
                actionBarButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: menu)
            }
        } else {
            actionBarButton = nil
        }
    }
}
