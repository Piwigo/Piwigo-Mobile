//
//  AlbumViewController+Rotate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

// MARK: - Rotate Images Actions
@available(iOS 14, *)
extension AlbumViewController
{
    func rotateMenu() -> UIMenu? {
        if selectedVideosIDs.isEmpty {
            return UIMenu(title: NSLocalizedString("rotateImage_rotate", comment: "Rotate 90°…"),
                          image: nil,
                          identifier: UIMenu.Identifier("org.piwigo.images.rotate"),
                          children: [rotateRightAction(), rotateLeftAction()])
        }
        return nil
    }
    
    private func rotateRightAction() -> UIAction {
        // Rotate image right
        let action = UIAction(title: NSLocalizedString("rotateImage_right", comment: "Clockwise"),
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
        let action = UIAction(title: NSLocalizedString("rotateImage_left", comment: "Counterclockwise"),
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
    @objc func rotateSelectionLeft() {
        initSelection(ofImagesWithIDs: selectedImageIDs, beforeAction: .rotateImagesLeft, contextually: false)
    }

    @objc func rotateSelectionRight() {
        initSelection(ofImagesWithIDs: selectedImageIDs, beforeAction: .rotateImagesRight, contextually: false)
    }

    func rotateImages(withID someIDs: Set<Int64>, by angle: CGFloat, total: Float) {
        var remainingIDs = someIDs
        guard let imageID = remainingIDs.first else {
            // Save changes
//            bckgContext.saveIfNeeded()
            // Close HUD with success
            DispatchQueue.main.async { [self] in
                self.navigationController?.updateHUDwithSuccess() { [self] in
                    navigationController?.hideHUD(afterDelay: pwgDelayHUD) { [self] in
                        // Deselect images
                        cancelSelect()
                    }
                }
            }
            return
        }

        // Get image data
        guard let imageData = (images.fetchedObjects ?? []).first(where: {$0.pwgID == imageID})
        else {
            // Forget this image
            remainingIDs.removeFirst()
            selectedImageIDs.remove(imageID)
            selectedFavoriteIDs.remove(imageID)
            selectedVideosIDs.remove(imageID)

            // Update HUD
            DispatchQueue.main.async { [self] in
                let progress: Float = 1 - Float(remainingIDs.count) / total
                self.navigationController?.updateHUD(withProgress: progress)
            }
            
            // Next image
            rotateImages(withID: remainingIDs, by: angle, total: total)
            return
        }

        // Send request to Piwigo server
        PwgSession.checkSession(ofUser: user) { [self] in
            ImageUtilities.rotate(imageData, by: angle) { [self] in
                // Update HUD
                DispatchQueue.main.async { [self] in
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
                }
                
                // Next image
                remainingIDs.removeFirst()
                selectedImageIDs.remove(imageID)
                selectedFavoriteIDs.remove(imageID)
                selectedVideosIDs.remove(imageID)
                rotateImages(withID: remainingIDs, by: angle, total: total)
                
            } failure: { [self] error in
                rotateImagesInDatabaseError(error)
            }
        } failure: { [self] error in
            rotateImagesInDatabaseError(error)
        }
    }
    
    private func rotateImagesInDatabaseError(_ error: Error) {
        DispatchQueue.main.async { [self] in
            // Session logout required?
            if let pwgError = error as? PwgSessionError,
               [.invalidCredentials, .incompatiblePwgVersion, .invalidURL, .authenticationFailed].contains(pwgError) {
                ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
                return
            }

            // Hide HUD
            navigationController?.hideHUD { [self] in
                // Plugin rotateImage installed?
                let title = NSLocalizedString("rotateImageFail_title", comment: "Rotation Failed")
                var message = ""
                if let pwgError = error as? PwgSessionError,
                   pwgError == .otherError(code: 501, msg: "") {
                    message = NSLocalizedString("rotateImageFail_plugin", comment: "The rotateImage plugin is not activated.")
                }
                else {
                    message = NSLocalizedString("rotateImageFail_message", comment: "Image could not be rotated")
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
}
