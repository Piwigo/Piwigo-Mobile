//
//  AlbumViewController+Buttons.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

extension AlbumViewController
{
    // MARK: - "Settings" Button
    func getSettingsBarButton() -> UIBarButtonItem {
        var button: UIBarButtonItem!
        if #available(iOS 14.0, *) {
            button = UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(didTapSettingsButton))
        } else {
            button = UIBarButtonItem(image: UIImage(named: "settings"), landscapeImagePhone: UIImage(named: "settingsCompact"), style: .plain, target: self, action: #selector(didTapSettingsButton))
        }
        button.accessibilityIdentifier = "settings"
        return button
    }
    
    @objc func didTapSettingsButton() {
        let settingsSB = UIStoryboard(name: "SettingsViewController", bundle: nil)
        guard let settingsVC = settingsSB.instantiateViewController(withIdentifier: "SettingsViewController") as? SettingsViewController else {
            fatalError("No SettingsViewController")
        }
        settingsVC.settingsDelegate = self
        settingsVC.userProvider = userProvider
        settingsVC.albumProvider = albumProvider
        settingsVC.savingContext = mainContext
        let navController = UINavigationController(rootViewController: settingsVC)
        navController.modalTransitionStyle = .coverVertical
        navController.modalPresentationStyle = .formSheet
        let mainScreenBounds = UIScreen.main.bounds
        navController.popoverPresentationController?.sourceRect = CGRect(
            x: mainScreenBounds.midX, y: mainScreenBounds.midY,
            width: 0, height: 0)
        navController.preferredContentSize = CGSize(
            width: pwgPadSettingsWidth,
            height: ceil(mainScreenBounds.size.height * 2 / 3))
        present(navController, animated: true)
    }


    // MARK: - "Add" button above collection view and other buttons
    func getAddButton() -> UIButton {
        let button = UIButton(type: .system)
        button.frame = getAddButtonFrame()
        button.layer.cornerRadius = kRadius
        button.layer.masksToBounds = false
        button.layer.opacity = 0.0
        button.layer.shadowOpacity = 0.8
        button.backgroundColor = UIColor.piwigoColorOrange()
        button.tintColor = UIColor.white
        button.showsTouchWhenHighlighted = true
        if categoryId == 0 {
            button.setImage(UIImage(named: "createLarge"), for: .normal)
        } else {
            button.setImage(UIImage(named: "add"), for: .normal)
        }
        button.addTarget(self, action: #selector(didTapAddButton), for: .touchUpInside)
        button.isHidden = true
        button.accessibilityIdentifier = "add"
        return button
    }
    
    func getAddButtonFrame() -> CGRect {
        let xPos = view.bounds.size.width - 3 * kRadius
        let yPos = view.bounds.size.height - 3 * kRadius
        return CGRect(x: xPos, y: yPos, width: 2 * kRadius, height: 2 * kRadius)
    }
    
    @objc func didTapAddButton() {
        // Create album if root album shown
        if categoryId == 0 {
            // User in root album => Create album
            addButton.backgroundColor = UIColor.gray
            addButton.tintColor = UIColor.white
            showCreateCategoryDialog()
            return
        }

        // Hide Home button behind Add button if needed
        if homeAlbumButton?.isHidden ?? false {
            // Show CreateAlbum and UploadImages albums
            showOptionalButtonsCompletion({ [self] in
                // Change appearance and action of Add button
                addButton.removeTarget(self, action: #selector(didTapAddButton), for: .touchUpInside)
                addButton.addTarget( self, action: #selector(didCancelTapAddButton), for: .touchUpInside)
            })
        } else {
            // Hide Home Album button
            hideHomeAlbumButtonCompletion({ [self] in
                // Show CreateAlbum and UploadImages albums
                showOptionalButtonsCompletion({ [self] in
                    // Change appearance and action of Add button
                    addButton.removeTarget( self, action: #selector(didTapAddButton), for: .touchUpInside)
                    addButton.addTarget(self, action: #selector(didCancelTapAddButton), for: .touchUpInside)
                })
            })
        }
    }

    @objc func didCancelTapAddButton() {
        // User changed mind or finished job
        // First hide optional buttons
        hideOptionalButtonsCompletion({ [self] in
            // Reset appearance and action of Add button
            addButton.removeTarget(self, action: #selector(didCancelTapAddButton), for: .touchUpInside)
            addButton.addTarget(self, action: #selector(didTapAddButton), for: .touchUpInside)
            addButton.backgroundColor = UIColor.piwigoColorOrange()
            addButton.tintColor = UIColor.white

            // Show button on the left of the Add button if needed
            if ![0, AlbumVars.shared.defaultCategory].contains(categoryId) {
                // Show Home button if not in root or default album
                showHomeAlbumButtonIfNeeded()
            }
        })
    }


    // MARK: - "Upload Queue" button above collection view
    func getUploadQueueButton() -> UIButton {
        let button = UIButton(type: .system)
        button.frame = addButton.frame
        button.layer.cornerRadius = kRadius
        button.layer.masksToBounds = false
        button.layer.shadowOpacity = 0.8
        button.showsTouchWhenHighlighted = true
        button.addTarget(self, action: #selector(didTapUploadQueueButton), for: .touchUpInside)
        button.isHidden = true
        button.backgroundColor = UIColor.clear
        return button
    }
    
    func getUploadQueueButtonFrame(isHidden: Bool) -> CGRect {
        if isHidden {
            return addButton.frame
        }
        // Resize label to fit number
        nberOfUploadsLabel?.sizeToFit()

        // Adapt button width if needed
        let width = (nberOfUploadsLabel?.bounds.size.width ?? 0.0) + 20
        let height = nberOfUploadsLabel?.bounds.size.height ?? 0.0
        let extraWidth = CGFloat(fmax(0, Float((width - 2 * kRadius))))
        nberOfUploadsLabel?.frame = CGRect(x: kRadius + (extraWidth / 2.0) - width / 2.0,
                                           y: kRadius - height / 2.0, width: width, height: height)

        progressLayer?.frame = CGRect(x: 0, y: 0, width: 2 * kRadius + extraWidth, height: 2 * kRadius)
        let path = UIBezierPath(arcCenter: CGPoint(x: kRadius + extraWidth, y: kRadius), radius: kRadius - 1.5, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: kRadius, y: 2 * kRadius - 1.5))
        path.addArc(withCenter: CGPoint(x: kRadius, y: kRadius), radius: kRadius - 1.5, startAngle: .pi / 2, endAngle: .pi + .pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: kRadius + extraWidth, y: 1.5))
        path.lineCapStyle = .round
        progressLayer?.path = path.cgPath

        let xPos = addButton.frame.origin.x - extraWidth
        let yPos = addButton.frame.origin.y
        if addButton.isHidden {
            return CGRect(x: xPos, y: yPos,
                          width: 2 * kRadius + extraWidth, height: 2 * kRadius)
        } else {
            return CGRect(x: xPos - 3 * kRadius, y: yPos,
                          width: 2 * kRadius + extraWidth, height: 2 * kRadius)
        }
    }
    
    func getNberOfUploadsLabel() -> UILabel {
        let label = UILabel(frame: CGRect.zero)
        label.text = ""
        label.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
        label.adjustsFontSizeToFitWidth = false
        label.textAlignment = .center
        label.backgroundColor = UIColor.clear
        return label
    }
    
    func getProgressLayer() -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.frame = CGRect(x: 0, y: 0, width: 2 * kRadius, height: 2 * kRadius)
        layer.lineWidth = 3
        layer.strokeStart = 0
        layer.strokeEnd = 0
        return layer
    }
    
    @objc func updateNberOfUploads(_ notification: Notification?) {
        guard [0, AlbumVars.shared.defaultCategory].contains(categoryId),
              let nberOfUploads = (notification?.userInfo?["nberOfUploadsToComplete"] as? NSNumber)?.intValue else { return }

        // Only presented in the root or default album
        if nberOfUploads > 0 {
            // Set number of uploads
            let nber = String(format: "%lu", UInt(nberOfUploads))
            if nber.compare(nberOfUploadsLabel?.text ?? "") == .orderedSame,
               !(uploadQueueButton?.isHidden ?? false),
               uploadQueueButton?.frame != addButton.frame {
                // Number unchanged -> NOP
                return
            }
            nberOfUploadsLabel?.text = String(format: "%lu", UInt(nberOfUploads))

            // Show button if needed
            if uploadQueueButton?.isHidden ?? false {
                // Unhide transparent Upload Queue button
                uploadQueueButton?.isHidden = false
            }

            // Animate appearance / width change of Upload Queue button
            UIView.animate(withDuration: 0.3, animations: { [self] in
                // Progressive appearance
                uploadQueueButton?.layer.opacity = 0.8
                
                // Depends on number of upload requests and Add button visibility
                uploadQueueButton?.frame = getUploadQueueButtonFrame(isHidden: false)
                uploadQueueButton?.setNeedsLayout()
            })
        } else {
            // Hide button if not already hidden
            if !(uploadQueueButton?.isHidden ?? false) {
                // Hide Upload Queue button behind Add button
                UIView.animate(withDuration: 0.3, animations: { [self] in
                    // Progressive disappearance
                    uploadQueueButton?.layer.opacity = 0.0

                    // Animate displacement towards the Add button if needed
                    uploadQueueButton?.frame = getUploadQueueButtonFrame(isHidden: true)

                }) { [self] finished in
                    // Hide Home Album button
                    uploadQueueButton?.isHidden = true
                }
            }
        }
    }

    @objc func updateUploadQueueButton(withProgress notification: Notification?) {
        guard [0, AlbumVars.shared.defaultCategory].contains(categoryId),
              let progress = notification?.userInfo?["progressFraction"] as? NSNumber as? CGFloat else { return }

        // Animate progress layer of Upload Queue button
        if progress > 0.0 {
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = NSNumber(value: Double(progressLayer?.strokeEnd ?? 0))
            animation.toValue = NSNumber(value: Float(progress))
            progressLayer?.strokeEnd = progress
            animation.duration = 0.2
            progressLayer?.add(animation, forKey: nil)
        } else {
            // No animation
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            progressLayer?.strokeEnd = 0.0
            CATransaction.commit()
            // Animations are disabled until here...
        }
    }


    // MARK: - "Home Album" button above collection view
    func getHomeButton() -> UIButton {
        let button = UIButton(type: .system)
        button.frame = addButton.frame
        button.layer.cornerRadius = kRadius
        button.layer.masksToBounds = false
        button.layer.opacity = 0.0
        button.layer.shadowOpacity = 0.8
        button.showsTouchWhenHighlighted = true
        button.setImage(UIImage(named: "rootAlbum"), for: .normal)
        button.addTarget(self, action: #selector(returnToDefaultCategory), for: .touchUpInside)
        button.isHidden = true
        return button
    }
    
    func getHomeAlbumButtonFrame(isHidden: Bool) -> CGRect {
        if isHidden {
            return addButton.frame
        }
        // Position of Home Album button depends on user's rights
        // — admin rights
        // — normal rights and upload access to the current category
        if categoryId > 0,
           NetworkVars.hasAdminRights || userHasUploadRights {
            let xPos = addButton.frame.origin.x
            let yPos = addButton.frame.origin.y
            return CGRect(x: xPos - 3 * kRadius, y: yPos,
                          width: 2 * kRadius, height: 2 * kRadius)
        } else {
            return addButton.frame
        }
    }
    
    func showHomeAlbumButtonIfNeeded() {
        // Don't present the Home button in search mode
        if categoryId == pwgSmartAlbum.search.rawValue { return }
        
        // Present Home Album button if needed
        if (homeAlbumButton?.isHidden ?? false ||
            homeAlbumButton?.frame.contains(addButton.frame.origin) ?? false),
           (uploadImagesButton?.isHidden ?? false ||
            uploadImagesButton?.frame.contains(addButton.frame.origin) ?? false),
           (createAlbumButton?.isHidden ?? false ||
            createAlbumButton?.frame.contains(addButton.frame.origin) ?? false) {
            // Unhide transparent Home Album button
            homeAlbumButton?.isHidden = false

            // Animate appearance of Home Album button
            UIView.animate(withDuration: 0.3, animations: { [self] in
                // Progressive appearance
                homeAlbumButton?.layer.opacity = 0.8

                // Position of Home Album button depends on user's rights
                homeAlbumButton?.frame = getHomeAlbumButtonFrame(isHidden: false)
            })
        }
    }

    func hideHomeAlbumButtonCompletion(_ completion: @escaping () -> Void) {
        // Hide Home Album button behind Add button
        UIView.animate(withDuration: 0.2, animations: { [self] in
            // Progressive disappearance
            homeAlbumButton?.layer.opacity = 0.0

            // Animate displacement towards the Add button if needed
            homeAlbumButton?.frame = getHomeAlbumButtonFrame(isHidden: true)

        }) { [self] finished in
            // Hide Home Album button
            homeAlbumButton?.isHidden = true

            // Execute block
            completion()
        }
    }


    // MARK: - "Create Album" button above collection view
    func getCreateAlbumButton() -> UIButton {
        let button = UIButton(type: .system)
        button.frame = addButton.frame
        button.layer.cornerRadius = 0.86 * kRadius
        button.layer.masksToBounds = false
        button.layer.opacity = 0.0
        button.layer.shadowOpacity = 0.8
        button.backgroundColor = UIColor.piwigoColorOrange()
        button.tintColor = UIColor.white
        button.showsTouchWhenHighlighted = true
        button.setImage(UIImage(named: "create"), for: .normal)
        button.addTarget(self, action: #selector(addAlbum), for: .touchUpInside)
        button.isHidden = true
        button.accessibilityIdentifier = "createAlbum"
        return button
    }
    
    func getCreateAlbumButtonFrame(isHidden: Bool) -> CGRect {
        var xPos = addButton.frame.origin.x
        var yPos = addButton.frame.origin.y
        if isHidden == false {
            xPos -= 3 * kRadius * cos(15 * kDeg2Rad)
            yPos -= 3 * kRadius * sin(15 * kDeg2Rad)
        }
        return CGRect(x: xPos, y: yPos,
                      width: 1.72 * kRadius, height: 1.72 * kRadius)
    }
    
    
    // MARK: - "Upload Images" button above collection view
    func getUploadImagesButton() -> UIButton {
        let button = UIButton(type: .system)
        button.frame = addButton.frame
        button.layer.cornerRadius = 0.86 * kRadius
        button.layer.masksToBounds = false
        button.layer.opacity = 0.0
        button.layer.shadowOpacity = 0.8
        button.backgroundColor = UIColor.piwigoColorOrange()
        button.tintColor = UIColor.white
        button.showsTouchWhenHighlighted = true
        button.setImage(UIImage(named: "imageUpload"), for: .normal)
        button.addTarget(self, action: #selector(didTapUploadImagesButton), for: .touchUpInside)
        button.isHidden = true
        button.accessibilityIdentifier = "addImages"
        return button
    }

    func getUploadImagesButtonFrame(isHidden: Bool) -> CGRect {
        var xPos = addButton.frame.origin.x
        var yPos = addButton.frame.origin.y
        if isHidden == false {
            xPos -= 3 * kRadius * cos(75 * kDeg2Rad)
            yPos -= 3 * kRadius * sin(75 * kDeg2Rad)
        }
        return CGRect(x: xPos, y: yPos,
                      width: 1.72 * kRadius, height: 1.72 * kRadius)
    }

    
    // MARK: - Buttons in Preview mode
    func setTitleViewFromAlbumData(whileUpdating isUpdating: Bool) {
        // Get album name
        let albumName = albumData?.name ?? NSLocalizedString("categorySelection_title", comment: "Album")
        if #available(iOS 13.0, *) {
            self.view?.window?.windowScene?.title = albumName
        }

        // Do not present a custom title view for the default album or a smart album
        if categoryId < 0 || categoryId == AlbumVars.shared.defaultCategory {
            if categoryId == 0 {
                title = NSLocalizedString("tabBar_albums", comment: "Albums")
            } else {
                title = albumName
            }
            return
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
        let wholeRange = NSRange(location: 0, length: albumName.count)
        let style = NSMutableParagraphStyle()
        style.alignment = NSTextAlignment.center
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            NSAttributedString.Key.paragraphStyle: style
        ]
        let attTitle = NSMutableAttributedString(string: albumName)
        attTitle.addAttributes(attributes, range: wholeRange)
        titleLabel.attributedText = attTitle
        titleLabel.sizeToFit()

        // There is no subtitle in landscape mode on iPhone
        if let lastDate = albumData?.dateLast,
           (UIDevice.current.userInterfaceIdiom == .phone &&
            !UIApplication.shared.statusBarOrientation.isLandscape) {
            // Get last updated date
            var lastUpdated: String
            if #available(iOS 13.0, *) {
                let formatter = RelativeDateTimeFormatter()
                formatter.dateTimeStyle = .named
                lastUpdated = formatter.localizedString(for: lastDate, relativeTo: Date())
            } else {
                lastUpdated = DateFormatter.localizedString(from: lastDate,
                                                            dateStyle: .short, timeStyle: .short)
            }
            
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
            if isUpdating {
                subTitleLabel.text = NSLocalizedString("categoryUpdating", comment: "Updating…")
            } else {
                subTitleLabel.text = lastUpdated
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
    
    func initButtonsInPreviewMode() {
        // Title is name of category
        setTitleViewFromAlbumData(whileUpdating: false)

        // When using several scenes on iPad, buttons might have to be relocated.
        if #available(iOS 13.0, *) {
            let sizeOfScreen = UIScreen.main.bounds.size
            let sizeOfView = view.bounds.size
            if sizeOfView.equalTo(sizeOfScreen) == false {
                // Calculate reference position
                let xPos = view.bounds.size.width - 3 * kRadius
                let yPos = view.bounds.size.height - 3 * kRadius
                var newFrame = CGRect(x: xPos, y: yPos, width: 2 * kRadius, height: 2 * kRadius)
                
                // Relocate the "Add" button if needed
                if addButton?.frame.equalTo(newFrame) == false {
                    addButton?.frame = newFrame
                }
                
                // Relocate the "Upload Queue" button if needed
                newFrame = getUploadQueueButtonFrame(isHidden: uploadQueueButton?.isHidden ?? true)
                if uploadQueueButton?.frame.equalTo(newFrame) == false {
                    uploadQueueButton?.frame = newFrame
                }

                // Relocate the "Home Album" button if needed
                newFrame = getHomeAlbumButtonFrame(isHidden: homeAlbumButton?.isHidden ?? true)
                if homeAlbumButton?.frame.equalTo(newFrame) == false {
                    homeAlbumButton?.frame = newFrame
                }
                
                // Relocate "Create Album" button if needed
                newFrame = getCreateAlbumButtonFrame(isHidden: createAlbumButton.isHidden)
                if createAlbumButton?.frame.equalTo(newFrame) == false {
                    createAlbumButton?.frame = newFrame
                }
                
                // Relocate "Upload Images" button if needed
                newFrame = getUploadImagesButtonFrame(isHidden: uploadImagesButton.isHidden)
                if uploadImagesButton?.frame.equalTo(newFrame) == false {
                    uploadImagesButton?.frame = newFrame
                }
            }
        }
    }
    
    func updateButtonsInPreviewMode() {
        // Hide toolbar unless it is displaying the image detail view
        if let displayedVC = navigationController?.viewControllers.last,
           !(displayedVC is ImageViewController) {
            navigationController?.setToolbarHidden(true, animated: true)
        }

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
        } else if albumData?.nbImages ?? 0 > 0 {
            // Button for activating the selection mode
            navigationItem.setRightBarButtonItems([selectBarButton].compactMap { $0 }, animated: true)
            selectBarButton?.isEnabled = (images.fetchedObjects?.count ?? 0) > 0
        } else {
            // No button
            navigationItem.setRightBarButtonItems([], animated: true)

            // Following 2 lines fixes situation where the Edit button remains visible
            navigationController?.navigationBar.setNeedsLayout()
            navigationController?.navigationBar.layoutIfNeeded()
        }
        
        // User can upload images/videos if he/she has:
        // — admin rights
        // — normal rights and upload access to the current category
        if categoryId >= 0,
           NetworkVars.hasAdminRights || userHasUploadRights {
            // Show Upload button if needed
            if addButton.isHidden {
                // Unhide transparent Add button
                addButton.isHidden = false

                // Animate appearance of Add button
                UIView.animate(withDuration: 0.3, animations: { [self] in
                    addButton.layer.opacity = 0.9
                }) { [self] finished in
                    // Fixes tintColor forgotten (often on iOS 9)
                    addButton.tintColor = UIColor.white
                    // Show button on the left of the Add button if needed
                    if ![0, AlbumVars.shared.defaultCategory].contains(categoryId) {
                        // Show Home button if not in root or default album
                        showHomeAlbumButtonIfNeeded()
                    } else {
                        // Show UploadQueue button if needed
                        let nberOfUploads = UIApplication.shared.applicationIconBadgeNumber
                        let userInfo = ["nberOfUploadsToComplete": NSNumber(value: nberOfUploads)]
                        NotificationCenter.default.post(name: .pwgLeftUploads,
                                                        object: nil, userInfo: userInfo)
                    }
                }
            } else {
                // Present Home button if needed and if not in root or default album
                if ![0, AlbumVars.shared.defaultCategory].contains(categoryId) {
                    showHomeAlbumButtonIfNeeded()
                }
            }
        } else {
            // Show Home button if:
            /// - not in root or default album
            /// - not searching for images
            addButton.isHidden = true
            if ![0, AlbumVars.shared.defaultCategory, pwgSmartAlbum.search.rawValue].contains(categoryId) {
                showHomeAlbumButtonIfNeeded()
            }
        }
    }

    func showOptionalButtonsCompletion(_ completion: @escaping () -> Void) {
        // Unhide transparent CreateAlbum and UploadImages buttons
        createAlbumButton?.tintColor = UIColor.white
        createAlbumButton?.isHidden = false
        uploadImagesButton?.tintColor = UIColor.white
        uploadImagesButton?.isHidden = false

        // Show CreateAlbum and UploadImages buttons
        UIView.animate(withDuration: 0.3, animations: { [self] in
            // Progressive appearance
            createAlbumButton?.layer.opacity = 0.9
            uploadImagesButton?.layer.opacity = 0.9

            // Move buttons together
            createAlbumButton?.frame = getCreateAlbumButtonFrame(isHidden: false)
            uploadImagesButton?.frame = getUploadImagesButtonFrame(isHidden: false)

            // Rotate cross and change colour
            let rotatedImage = UIImage(named: "add")?.rotated(by: .pi / 4)
            addButton.setImage(rotatedImage, for: .normal)
            addButton.backgroundColor = UIColor.gray
            addButton.tintColor = UIColor.white
        }) { finished in
            // Execute block
            completion()
        }
    }

    func hideOptionalButtonsCompletion(_ completion: @escaping () -> Void) {
        // Hide CreateAlbum and UploadImages buttons
        UIView.animate(withDuration: 0.3, animations: { [self] in
            // Progressive disappearance
            createAlbumButton?.layer.opacity = 0.0
            uploadImagesButton?.layer.opacity = 0.0

            // Move buttons towards Add button
            createAlbumButton?.frame = getCreateAlbumButtonFrame(isHidden: true)
            uploadImagesButton?.frame = getUploadImagesButtonFrame(isHidden: true)

            // Rotate cross if not in root and change colour
            if categoryId == 0 {
                addButton.setImage(UIImage(named: "createLarge"), for: .normal)
            } else {
                addButton.setImage(UIImage(named: "add"), for: .normal)
            }
            addButton.backgroundColor = UIColor.gray
            addButton.tintColor = UIColor.white
        }) { [self] finished in
            // Hide transparent CreateAlbum and UploadImages buttons
            createAlbumButton?.isHidden = true
            uploadImagesButton?.isHidden = true

            // Reset background colours
            createAlbumButton?.backgroundColor = UIColor.piwigoColorOrange()
            uploadImagesButton?.backgroundColor = UIColor.piwigoColorOrange()

            // Execute block
            completion()
        }
    }
}
