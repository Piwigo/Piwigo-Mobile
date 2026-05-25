//
//  AlbumViewController+Rotate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import PwgKit
import PwgAPIKit
import PwgCacheKit

// MARK: - Rotate Images Actions
extension AlbumViewController
{
    func rotateMenu() -> UIMenu? {
        if selectedVideosIDs.isEmpty {
            return UIMenu(title: String(localized: "rotateImage_rotate", comment: "Rotate 90°…"),
                          image: nil,
                          identifier: UIMenu.Identifier("org.piwigo.images.rotate"),
                          children: [rotateRightAction(), rotateLeftAction()])
        }
        return nil
    }
    
    private func rotateRightAction() -> UIAction {
        // Rotate image right
        let action = UIAction(title: String(localized: "rotateImage_right", comment: "Clockwise"),
                              image: UIImage(systemName: "rotate.right"),
                              handler: { [self] _ in
            // Rotate images right
            self.rotateSelectionRight()
        })
        action.accessibilityIdentifier = "Rotate Right"
        return action
    }

    private func rotateLeftAction() -> UIAction {
        // Rotate image left
        let action = UIAction(title: String(localized: "rotateImage_left", comment: "Counterclockwise"),
                              image: UIImage(systemName: "rotate.left"),
                              handler: { [self] _ in
            // Rotate images left
            self.rotateSelectionLeft()
        })
        action.accessibilityIdentifier = "Rotate Left"
        return action
    }
}


extension AlbumViewController
{
    // MARK: - Rotate Image
    @objc @MainActor
    func rotateSelectionLeft() {
        initSelection(ofImagesWithIDs: selectedImageIDs, beforeAction: .rotateImagesLeft, contextually: false)
    }

    @objc @MainActor
    func rotateSelectionRight() {
        initSelection(ofImagesWithIDs: selectedImageIDs, beforeAction: .rotateImagesRight, contextually: false)
    }

    @MainActor
    func rotateImages(withID someIDs: Set<Int64>, by angle: CGFloat, total: Float) {
        var remainingIDs = someIDs
        guard let imageID = remainingIDs.first else {
            // Save changes
            mainContext.saveIfNeeded()
            // Close HUD with success
            self.navigationController?.updateHUDwithSuccess() { [self] in
                navigationController?.hideHUD(afterDelay: pwgDelayHUD) { [self] in
                    // Deselect images
                    cancelSelect()
                }
            }
            return
        }

        // Get image data
        guard let imageData = (images.fetchedObjects ?? []).first(where: {$0.pwgID == imageID})
        else {
            // Forget this image
            remainingIDs.removeFirst()
            deselectImages(withIDs: Set([imageID]))

            // Update HUD
            let progress: Float = 1 - Float(remainingIDs.count) / total
            self.navigationController?.updateHUD(withProgress: progress)
            
            // Next image
            rotateImages(withID: remainingIDs, by: angle, total: total)
            return
        }

        // Send requests to Piwigo server
        Task {
            do {
                // Check session
                try await LoginUtilities().checkSession(ofUserWithID: user.objectID, lastConnected: user.lastUsed)
                
                // Rotate thumbnails on server
                try await JSONManager.shared.rotateImage(withID: imageData.pwgID, by: angle)
                
                // Image rotated successfully ► Rotate thumbnails in cache
                /// Image data not always immediately available from server.
                /// We rotate the images stored in cache instead of downloading them.
                imageData.rotateThumbnails(by: angle)
                
                // Update UI
                await MainActor.run {
                    // Update progress indicator
                    let progress: Float = 1 - Float(remainingIDs.count) / total
                    self.navigationController?.updateHUD(withProgress: progress)

                    // Check if we already have the image in cache
                    if let wantedImage = imageData.cachedThumbnail(ofSize: self.imageSize) {
                        // Downsample thumbnail (should not be needed)
                        let cachedImage = ImageUtilities.downsample(image: wantedImage, to: self.getImageCellSize())
                        // Rotate cell image if needed
                        let visibleCells = self.collectionView?.visibleCells ?? []
                        let imageCells = visibleCells.compactMap({$0 as? ImageCollectionViewCell})
                        if let cell = imageCells.first(where: { $0.imageData.pwgID == imageID}) {
                            // Rotate thumbnail
                            UIView.animate(withDuration: 0.25) {
                                cell.cellImage.transform = CGAffineTransform(rotationAngle: -angle)
                            } completion: { _ in
                                cell.configImage(cachedImage, withHiddenLabel: true)
                                cell.cellImage.transform = CGAffineTransformIdentity
                            }
                        }
                    }

                    // Next image
                    remainingIDs.removeFirst()
                    deselectImages(withIDs: Set([imageID]))
                    rotateImages(withID: remainingIDs, by: angle, total: total)
                }
            }
            catch let error as PwgKitError {
                rotateImagesInDatabaseError(error)
            }
        }
    }
    
    @MainActor
    private func rotateImagesInDatabaseError(_ error: PwgKitError) {
        // Session logout required?
        if error.requiresLogout {
            ClearCache.closeSessionWithPwgError(from: self, error: error)
            return
        }

        // Hide HUD
        navigationController?.hideHUD { [self] in
            // Plugin rotateImage installed?
            let title = String(localized: "rotateImageFail_title", comment: "Rotation Failed")
            var message = ""
            if error.pluginMissing {
                message = String(localized: "rotateImageFail_plugin", comment: "The rotateImage plugin is not activated.")
            }
            else {
                message = String(localized: "rotateImageFail_message", comment: "Image could not be rotated")
            }
            
            // Report error
            navigationController?.dismissPiwigoError(withTitle: title, message: message,
                                                     errorMessage: error.localizedDescription) { [self] in
                // Re-enable buttons
                setEnableStateOfButtons(true)
            }
        }
    }
}
