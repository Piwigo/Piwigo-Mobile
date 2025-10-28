//
//  AlbumViewController+Buttons.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit
import uploadKit

extension AlbumViewController
{
    // MARK: - Buttons Management
    // Exclusively before iOS 26
    func relocateButtons() {
        // Buttons might have to be relocated:
        /// - when using several scenes on iPad
        /// - when launching the app in landscape mode on iPhone and returning to the root album in portrait mode
        // Calculate reference position
        let xPos = view.bounds.size.width - 3 * kRadius
        let yPos = view.bounds.size.height - 3 * kRadius
        var newFrame = CGRect(x: xPos, y: yPos, width: 2 * kRadius, height: 2 * kRadius)
        
        // Relocate the "Add" button if needed
        if addButton.frame.equalTo(newFrame) == false {
            addButton.frame = newFrame
        }
        
        // Relocate the "Upload Queue" button if needed
        newFrame = getUploadQueueButtonFrame(isHidden: uploadQueueButton.isHidden)
        if uploadQueueButton.frame.equalTo(newFrame) == false {
            uploadQueueButton.frame = newFrame
        }

        // Relocate the "Home Album" button if needed
        newFrame = getHomeAlbumButtonFrame(isHidden: homeAlbumButton.isHidden)
        if homeAlbumButton.frame.equalTo(newFrame) == false {
            homeAlbumButton.frame = newFrame
        }
        
        // Relocate "Create Album" button if needed
        newFrame = getCreateAlbumButtonFrame(isHidden: createAlbumButton.isHidden)
        if createAlbumButton.frame.equalTo(newFrame) == false {
            createAlbumButton.frame = newFrame
        }
        
        // Relocate "Upload Images" button if needed
        newFrame = getUploadImagesButtonFrame(isHidden: uploadImagesButton.isHidden)
        if uploadImagesButton.frame.equalTo(newFrame) == false {
            uploadImagesButton.frame = newFrame
        }
    }
    
    func updateButtons() {
        // User can upload images/videos if he/she has:
        // — admin rights
        // — normal rights and upload access to the current category
        if [0, AlbumVars.shared.defaultCategory].contains(categoryId),
           user.hasUploadRights(forCatID: categoryId) {
            // Show Add Album button
            if addButton.isHidden {
                // Show Add button
                showAddButton {
                    // Show UploadQueue button if needed
                    let nberOfUploads = UploadVars.shared.nberOfUploadsToComplete
                    let userInfo = ["nberOfUploadsToComplete": nberOfUploads]
                    NotificationCenter.default.post(name: .pwgLeftUploads,
                                                    object: nil, userInfo: userInfo)
                }
            }
        } else if categoryId > 0,
                  user.hasUploadRights(forCatID: categoryId) {
            // Show Upload button if needed
            if addButton.isHidden {
                // Show Add button
                showAddButton { [self] in
                    // Show Home button on the left of the Add button if needed
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
    
    func hideButtons() {
        // Hide Upload and Home buttons
        addButton.isHidden = true
        homeAlbumButton.isHidden = true
    }

    func showOptionalButtons(_ completion: @escaping () -> Void) {
        // Unhide transparent CreateAlbum and UploadImages buttons
        createAlbumButton.alpha = 0.0
        createAlbumButton.isHidden = false
        uploadImagesButton.alpha = 0.0
        uploadImagesButton.isHidden = false

        // Show CreateAlbum and UploadImages buttons
        UIView.animate(withDuration: 0.25, animations: { [self] in
            // Progressive appearance
            createAlbumButton.alpha = 0.9
            uploadImagesButton.alpha = 0.9

            // Move buttons together
            createAlbumButton.frame = getCreateAlbumButtonFrame(isHidden: false)
            uploadImagesButton.frame = getUploadImagesButtonFrame(isHidden: false)

            // Rotate cross and change colour
            addButton.configuration = addButtonGray
            addButton.transform = CGAffineTransform(rotationAngle: .pi/2)
        }) { finished in
            // Execute block
            completion()
        }
    }

    func hideOptionalButtons(_ completion: @escaping () -> Void) {
        // Hide CreateAlbum and UploadImages buttons
        UIView.animate(withDuration: 0.25, animations: { [self] in
            // Progressive disappearance
            createAlbumButton.alpha = 0.0
            uploadImagesButton.alpha = 0.0

            // Move buttons towards Add button
            createAlbumButton.frame = getCreateAlbumButtonFrame(isHidden: true)
            uploadImagesButton.frame = getUploadImagesButtonFrame(isHidden: true)

            // Rotate cross if not in root and change colour
            if categoryId != 0 {
                addButton.configuration = addButtonOrange
                addButton.transform = CGAffineTransform.identity
            }
        }) { [self] finished in
            // Hide transparent CreateAlbum and UploadImages buttons
            createAlbumButton.isHidden = true
            uploadImagesButton.isHidden = true

            // Execute block
            completion()
        }
    }
    
    
    // MARK: - "Add" button above collection view and other buttons
    func getAddButton() -> UIButton {
        let button = UIButton(configuration: addButtonOrange)
        button.frame = getAddButtonFrame()
        button.layer.shadowOpacity = 0.8
        button.addTarget(self, action: #selector(didTapAddButton), for: .touchUpInside)
        button.isHidden = true
        button.accessibilityIdentifier = "add"
        button.accessibilityLabel = NSLocalizedString("createNewAlbum_title", comment: "New Album")
        return button
    }
    
    func getAddButtonFrame() -> CGRect {
        let xPos = view.bounds.size.width - 3 * kRadius
        let yPos = view.bounds.size.height - 3 * kRadius
        return CGRect(x: xPos, y: yPos, width: 2 * kRadius, height: 2 * kRadius)
    }
    
    func getAddButtonOrangeConfiguration() -> UIButton.Configuration {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .fixed
        config.baseForegroundColor = .white
        config.baseBackgroundColor = PwgColor.orange
        config.background.cornerRadius = kRadius
        config.image = getAddButtonImage()
        return config
    }

    func getAddButtonGrayConfiguration() -> UIButton.Configuration {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .fixed
        config.baseForegroundColor = .white
        config.baseBackgroundColor = .gray
        config.background.cornerRadius = kRadius
        config.image = getAddButtonImage()
        return config
    }
    
    func getAddButtonImage() -> UIImage? {
        if categoryId == 0 {
            let imageConfig = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
            return UIImage(systemName: "rectangle.stack.badge.plus", withConfiguration: imageConfig)
        } else {
            let imageConfig = UIImage.SymbolConfiguration(pointSize: 23, weight: .medium)
            return UIImage(systemName: "plus", withConfiguration: imageConfig)
        }
    }

    @objc func didTapAddButton() {
        // Create album if root album shown
        if categoryId == 0 {
            // User in root album => Create album
            hideAddButton { [self] in
                showCreateCategoryDialog()
            }
            return
        }

        // Hide Home button behind Add button if needed
        if homeAlbumButton.isHidden {
            // Show CreateAlbum and UploadImages albums
            showOptionalButtons { [self] in
                // Change appearance and action of Add button
                addButton.removeTarget(self, action: #selector(didTapAddButton), for: .touchUpInside)
                addButton.addTarget( self, action: #selector(didCancelTapAddButton), for: .touchUpInside)
            }
        } else {
            // Hide Home Album button
            hideHomeAlbumButton { [self] in
                // Show CreateAlbum and UploadImages albums
                showOptionalButtons { [self] in
                    // Change appearance and action of Add button
                    addButton.removeTarget( self, action: #selector(didTapAddButton), for: .touchUpInside)
                    addButton.addTarget(self, action: #selector(didCancelTapAddButton), for: .touchUpInside)
                }
            }
        }
    }

    @objc func didCancelTapAddButton() {
        // User changed mind or finished job
        // First hide optional buttons
        hideOptionalButtons { [self] in
            // Reset appearance and action of Add button
            showAddButton { [self] in
                addButton.removeTarget(self, action: #selector(didCancelTapAddButton), for: .touchUpInside)
                addButton.addTarget(self, action: #selector(didTapAddButton), for: .touchUpInside)
            }

            // Show button on the left of the Add button if needed
            if ![0, AlbumVars.shared.defaultCategory].contains(categoryId) {
                // Show Home button if not in root or default album
                showHomeAlbumButtonIfNeeded()
            }
        }
    }
    
    func showAddButton(_ completion: @escaping () -> Void) {
        // Show Add button
        addButton.alpha = 0.0
        addButton.isHidden = false

        // Show Add button
        UIView.animate(withDuration: 0.25, animations: { [self] in
            // Progressive appearance
            addButton.alpha = 0.9
        }) { finished in
            completion()
        }
    }
    
    func hideAddButton(_ completion: @escaping () -> Void) {
        // Hide Add button
        UIView.animate(withDuration: 0.25, animations: { [self] in
            // Progressive disappearance
            addButton.alpha = 0.0
        }) { [self] finished in
            addButton.isHidden = true
            completion()
        }
    }


    // MARK: - "Upload Queue" button above collection view
    func getUploadQueueButton() -> UIButton {
        let config = getUploadQueueButtonConfiguration()
        let button = UIButton(configuration: config)
        button.frame = addButton.frame
        button.layer.shadowOpacity = 0.8
        button.addTarget(self, action: #selector(didTapUploadQueueButton), for: .touchUpInside)
        button.isHidden = true
        button.accessibilityIdentifier = "Upload Queue"
        button.accessibilityLabel = NSLocalizedString("UploadRequests_cache", comment: "Uploads")
        return button
    }
    
    func getUploadQueueButtonFrame(isHidden: Bool) -> CGRect {
        if isHidden {
            return addButton.frame
        }
        // Resize label to fit number
        nberOfUploadsLabel.sizeToFit()

        // Adapt button width if needed
        let width = nberOfUploadsLabel.bounds.size.width + 20
        let height = nberOfUploadsLabel.bounds.size.height
        let extraWidth = CGFloat(fmax(0, Float((width - 2 * kRadius))))
        nberOfUploadsLabel.frame = CGRect(x: kRadius + (extraWidth / 2.0) - width / 2.0,
                                          y: kRadius - height / 2.0, width: width, height: height)

        progressLayer.frame = CGRect(x: 0, y: 0, width: 2 * kRadius + extraWidth, height: 2 * kRadius)
        let path = UIBezierPath(arcCenter: CGPoint(x: kRadius + extraWidth, y: kRadius), 
                                radius: kRadius - 1.5, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: kRadius, y: 2 * kRadius - 1.5))
        path.addArc(withCenter: CGPoint(x: kRadius, y: kRadius), 
                    radius: kRadius - 1.5, startAngle: .pi / 2, endAngle: .pi + .pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: kRadius + extraWidth, y: 1.5))
        path.lineCapStyle = .round
        progressLayer.path = path.cgPath

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
    
    func getUploadQueueButtonConfiguration() -> UIButton.Configuration {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .fixed
        config.baseForegroundColor = PwgColor.background
        config.baseBackgroundColor = PwgColor.rightLabel
        config.background.cornerRadius = kRadius
        return config
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
        layer.lineCap = .round
        layer.lineJoin = .round
        layer.strokeStart = 0
        layer.strokeEnd = 0
        return layer
    }
    
    func showOldUploadQueueButton() {
        // Show button if needed
        if uploadQueueButton.isHidden {
            // Unhide transparent Upload Queue button
            uploadQueueButton.alpha = 0.0
            uploadQueueButton.isHidden = false
        }

        // Animate appearance / width change of Upload Queue button
        UIView.animate(withDuration: 0.25, animations: { [self] in
            // Progressive appearance
            uploadQueueButton.alpha = 0.9
            
            // Depends on number of upload requests and Add button visibility
            uploadQueueButton.frame = getUploadQueueButtonFrame(isHidden: false)
        })
    }
    
    func hideOldUploadQueueButton() {
        // Hide button if not already hidden
        if uploadQueueButton.isHidden { return }
        
        // Hide Upload Queue button behind Add button
        UIView.animate(withDuration: 0.25, animations: { [self] in
            // Progressive disappearance
            uploadQueueButton.alpha = 0.0

            // Animate displacement towards the Add button if needed
            uploadQueueButton.frame = getUploadQueueButtonFrame(isHidden: true)

        }) { [self] finished in
            // Hide Home Album button
            uploadQueueButton.isHidden = true
        }
    }

    @objc func updateOldButton(withNberOfUploads nberOfUploads: Int) {
        // Only called in the root or default album
        if nberOfUploads > 0 {
            if (!NetworkVars.shared.isConnectedToWiFi && UploadVars.shared.wifiOnlyUploading) ||
                ProcessInfo.processInfo.isLowPowerModeEnabled {
                nberOfUploadsLabel.text = "⚠️"
            } else {
                // Set number of uploads
                let nber = String(format: "%lu", UInt(nberOfUploads))
                if nber.compare(nberOfUploadsLabel.text ?? "") == .orderedSame,
                   !uploadQueueButton.isHidden,
                   uploadQueueButton.frame != addButton.frame {
                    // Nothing changed ► NOP
                    return
                }
                nberOfUploadsLabel.text = String(format: "%lu", UInt(nberOfUploads))
            }
            
            // Resize and show button if needed
            showOldUploadQueueButton()
        } else {
            // Hide button if not already hidden
            hideOldUploadQueueButton()
        }
    }
    
    @objc func updateUploadQueueButton(withProgress notification: Notification?) {
        guard let progress = notification?.userInfo?["progressFraction"] as? Float else { return }

        // Show button is needed
        showOldUploadQueueButton()
        
        // Animate progress layer of Upload Queue button
        if progress > 0.0 {
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = NSNumber(value: Double(progressLayer.strokeEnd))
            animation.toValue = NSNumber(value: progress)
            progressLayer.strokeEnd = CGFloat(progress)
            progressLayer.lineCap = .round
            animation.duration = 0.2
            progressLayer.add(animation, forKey: nil)
        } else {
            // No animation
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            progressLayer.strokeEnd = 0.0
            CATransaction.commit()
            // Animations are disabled until here...
        }
    }


    // MARK: - "Home Album" button above collection view
    func getHomeAlbumButton() -> UIButton {
        let config = getHomeAlbumConfiguration()
        let button = UIButton(configuration: config)
        button.frame = addButton.frame
        button.layer.shadowOpacity = 0.8
        button.addTarget(self, action: #selector(returnToDefaultCategory), for: .touchUpInside)
        button.isHidden = true
        button.accessibilityIdentifier = "rootAlbum"
        button.accessibilityLabel = pwgSmartAlbum.root.name
        return button
    }
    
    func getHomeAlbumButtonFrame(isHidden: Bool) -> CGRect {
        if isHidden {
            return addButton.frame
        }
        // Position of Home Album button depends on user's rights
        // — webmaster or admin rights
        // — normal rights and upload access to the current category
        if categoryId > 0, user.hasUploadRights(forCatID: categoryId) {
            let xPos = addButton.frame.origin.x
            let yPos = addButton.frame.origin.y
            return CGRect(x: xPos - 3 * kRadius, y: yPos,
                          width: 2 * kRadius, height: 2 * kRadius)
        } else {
            return addButton.frame
        }
    }
    
    func getHomeAlbumConfiguration() -> UIButton.Configuration {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .fixed
        config.baseForegroundColor = PwgColor.background
        config.baseBackgroundColor = PwgColor.rightLabel
        config.background.cornerRadius = kRadius
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold)
        config.image = UIImage(systemName: "house.fill", withConfiguration: imageConfig)
        return config
    }
    
    func showHomeAlbumButtonIfNeeded() {
        // Don't present the Home button in search mode
        if categoryId == pwgSmartAlbum.search.rawValue { return }
        
        // Present Home Album button if needed
        if (homeAlbumButton.isHidden ||
            homeAlbumButton.frame.contains(addButton.frame.origin)),
           (uploadImagesButton.isHidden ||
            uploadImagesButton.frame.contains(addButton.frame.origin)),
           (createAlbumButton.isHidden ||
            createAlbumButton.frame.contains(addButton.frame.origin)) {
            // Unhide transparent Home Album button
            homeAlbumButton.alpha = 0.0
            homeAlbumButton.isHidden = false

            // Animate appearance of Home Album button
            UIView.animate(withDuration: 0.25, animations: { [self] in
                // Progressive appearance
                homeAlbumButton.alpha = 0.9

                // Position of Home Album button depends on user's rights
                homeAlbumButton.frame = getHomeAlbumButtonFrame(isHidden: false)
            })
        }
    }

    func hideHomeAlbumButton(_ completion: @escaping () -> Void) {
        // Hide Home Album button behind Add button
        UIView.animate(withDuration: 0.25, animations: { [self] in
            // Progressive disappearance
            homeAlbumButton.alpha = 0.0

            // Animate displacement towards the Add button if needed
            homeAlbumButton.frame = getHomeAlbumButtonFrame(isHidden: true)

        }) { [self] finished in
            // Hide Home Album button
            homeAlbumButton.isHidden = true

            // Execute block
            completion()
        }
    }


    // MARK: - "Create Album" button above collection view
    func getCreateAlbumButton() -> UIButton {
        let button = UIButton(configuration: createAlbumOrange)
        button.frame = addButton.frame
        button.layer.shadowOpacity = 0.8
        button.addTarget(self, action: #selector(didTapCreateAlbum), for: .touchUpInside)
        button.isHidden = true
        button.accessibilityIdentifier = "createAlbum"
        button.accessibilityLabel = NSLocalizedString("createNewAlbum_title", comment: "New Album")
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
    
    func getCreateAlbumButtonConfiguration() -> UIButton.Configuration {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .fixed
        config.baseForegroundColor = .white
        config.baseBackgroundColor = PwgColor.orange
        config.background.cornerRadius = 0.86 * kRadius
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        config.image = UIImage(systemName: "rectangle.stack.badge.plus", withConfiguration: imageConfig)
        return config
    }
    

    // MARK: - "Upload Images" button above collection view
    func getUploadImagesButton() -> UIButton {
        let button = UIButton(configuration: uploadImagesOrange)
        button.frame = addButton.frame
        button.layer.shadowOpacity = 0.8
        button.addTarget(self, action: #selector(didTapUploadImagesButton), for: .touchUpInside)
        button.isHidden = true
        button.accessibilityIdentifier = "org.piwigo.addImages"
        button.accessibilityLabel = NSLocalizedString("tabBar_upload", comment: "Upload")
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

    func getUploadImagesButtonConfiguration() -> UIButton.Configuration {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .fixed
        config.baseForegroundColor = .white
        config.baseBackgroundColor = PwgColor.orange
        config.background.cornerRadius = 0.86 * kRadius
        if #available(iOS 17.0, *) {
            let imageConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            config.image = UIImage(systemName: "photo.badge.plus", withConfiguration: imageConfig)
        } else {
            config.image = UIImage(named: "photo.badge.plus")
        }
        return config
    }
}
