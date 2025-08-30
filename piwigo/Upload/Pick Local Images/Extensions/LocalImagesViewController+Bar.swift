//
//  LocalImagesViewController+Bar.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 17 August 2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import Photos
import UIKit

// MARK: Navigation Bar & Buttons
extension LocalImagesViewController {
    
    @MainActor
    func updateNavBar() {
        // Buttons
        let nberOfSelectedImages = selectedImages.compactMap{ $0 }.count
        let hasSelectedImages = nberOfSelectedImages > 0
        cancelBarButton.isEnabled = hasSelectedImages
        actionBarButton.isEnabled = (queue.operationCount == 0)
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
            navigationItem.attributedTitle = TableViewUtilities.shared.attributedTitle(imageCollectionName)
            
            // Subtitle
            if hasSelectedImages {
                let subtitle = nberOfSelectedImages == 1
                    ? NSLocalizedString("selectImageSelected", comment: "1 Photo Selected")
                    : String(format:NSLocalizedString("selectImagesSelected", comment: "%@ Photos Selected"), NSNumber(value: nberOfSelectedImages))
                navigationItem.attributedSubtitle = TableViewUtilities.shared.attributedSubTitleForAlbum(subtitle)
            }
            else {
                let subtitle = NSLocalizedString("selectImages", comment: "Select Photos")
                navigationItem.attributedSubtitle = TableViewUtilities.shared.attributedSubTitleForAlbum(subtitle)
            }
        } else {
            // Fallback on previous version
            setTitleView(withCount: nberOfSelectedImages)
        }
        
        // Right side of the navigation bar
        updateActionButton()
        if #available(iOS 26.0, *) {
            switch UIDevice.current.userInterfaceIdiom {
            case .phone:
                navigationItem.rightBarButtonItems = [uploadBarButton, .space(),
                                                      actionBarButton].compactMap { $0 }
            case .pad:
                trashBarButton.isEnabled = canDeleteUploadedImages() || canDeleteSelectedImages()
                navigationItem.rightBarButtonItems = [uploadBarButton, .space(),
                                                      actionBarButton, trashBarButton].compactMap { $0 }
            default:
                preconditionFailure("!!! User interface not managed !!!")
            }
        }
        else {
            switch UIDevice.current.userInterfaceIdiom {
            case .phone:
                navigationItem.rightBarButtonItems = [uploadBarButton, actionBarButton].compactMap { $0 }

            case .pad:
                trashBarButton.isEnabled = canDeleteUploadedImages() || canDeleteSelectedImages()
                navigationItem.rightBarButtonItems = [uploadBarButton, actionBarButton,
                                                      trashBarButton].compactMap { $0 }
            default:
                preconditionFailure("!!! User interface not managed !!!")
            }
        }
    }
    
    @MainActor @available(iOS, introduced: 15.0, deprecated: 26.0, message: "Specific to iOS 15 to 18")
    func setTitleView(withCount count: Int? = nil) {
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
        let wholeRange = NSRange(location: 0, length: imageCollectionName.count)
        let style = NSMutableParagraphStyle()
        style.alignment = NSTextAlignment.center
        let attributes = [
            NSAttributedString.Key.foregroundColor: PwgColor.whiteCream,
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            NSAttributedString.Key.paragraphStyle: style
        ]
        let attTitle = NSMutableAttributedString(string: imageCollectionName)
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

    @MainActor
    func updateActionButton() {
        // Update action button
        // The action button proposes:
        /// - to swap between ascending and descending sort orders,
        /// - to choose one of the 4 sort options
        /// - to select new photos in the Photo Library if the user did not grant full access to the Photo Library,
        /// - to allow/disallow re-uploading photos,
        /// - to delete photos already uploaded to the Piwigo server on iPhone only.
        var children: [UIMenuElement?] = [swapOrderAction(), groupMenu(),
                                          selectPhotosMenu(), reUploadAction()]
        if UIDevice.current.userInterfaceIdiom == .phone {
            children.append(deleteMenu())
        }
        let updatedMenu = actionBarButton?.menu?.replacingChildren(children.compactMap({$0}))
        actionBarButton?.menu = updatedMenu
    }
    
    func canDeleteUploadedImages() -> Bool {
        // Don't provide access to the Trash button until the preparation work is not done
        if queue.operationCount > 0 { return false }
        
        // Check if there are uploaded photos to delete
        let indexedUploads = self.indexedUploadsInQueue.compactMap({$0})
        let completed = (uploads.fetchedObjects ?? []).filter({[.finished, .moderated].contains($0.state)})
        for index in 0..<indexedUploads.count {
            if let _ = completed.first(where: {$0.localIdentifier == indexedUploads[index].0}),
               indexedUploads[index].2 {
                return true
            }
        }
        return false
    }
    
    func canDeleteSelectedImages() -> Bool {
        var hasImagesToDelete = false
        let imageIDs = selectedImages.compactMap({ $0?.localIdentifier })
        PHAsset.fetchAssets(withLocalIdentifiers: imageIDs, options: nil)
            .enumerateObjects(options: .concurrent) { asset, _ , stop in
                if asset.canPerform(.delete) {
                    hasImagesToDelete = true
                    stop.pointee = true
                }
            }
        return hasImagesToDelete
    }
    
    
    // MARK: - Show Upload Options
    @objc func didTapUploadButton() {
        // Avoid potential crash (should never happen, but…)
        uploadRequests = selectedImages.compactMap({ $0 })
        if uploadRequests.isEmpty { return }
        
        // Disable buttons
        cancelBarButton?.isEnabled = false
        uploadBarButton?.isEnabled = false
        actionBarButton?.isEnabled = false
        trashBarButton?.isEnabled = false
        
        // Show upload parameter views
        let uploadSwitchSB = UIStoryboard(name: "UploadSwitchViewController", bundle: nil)
        guard let uploadSwitchVC = uploadSwitchSB.instantiateViewController(withIdentifier: "UploadSwitchViewController") as? UploadSwitchViewController
        else { preconditionFailure("could not load UploadSwitchViewController") }
        
        uploadSwitchVC.delegate = self
        uploadSwitchVC.user = user
        uploadSwitchVC.categoryId = categoryId
        uploadSwitchVC.categoryCurrentCounter = categoryCurrentCounter

        // Will we propose to delete images after upload?
        if let firstLocalID = uploadRequests.first?.localIdentifier {
            if let imageAsset = PHAsset.fetchAssets(withLocalIdentifiers: [firstLocalID], options: nil).firstObject {
                // Only local images can be deleted
                if imageAsset.sourceType != .typeCloudShared {
                    // Will allow user to delete images after upload
                    uploadSwitchVC.canDeleteImages = true
                }
            }
        }
        
        // Push Edit view embedded in navigation controller
        let navController = UINavigationController(rootViewController: uploadSwitchVC)
        navController.modalPresentationStyle = .popover
        navController.modalTransitionStyle = .coverVertical
        navController.popoverPresentationController?.sourceView = localImagesCollection
        navController.popoverPresentationController?.barButtonItem = uploadBarButton
        navController.popoverPresentationController?.permittedArrowDirections = .up
        navigationController?.present(navController, animated: true)
    }
}
