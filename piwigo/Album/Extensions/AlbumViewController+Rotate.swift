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
                              handler: { _ in
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
                              handler: { _ in
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
        initSelection(ofImagesWithIDs: selectedImageIDs, beforeAction: .rotateImagesLeft)
    }

    @objc func rotateSelectionRight() {
        initSelection(ofImagesWithIDs: selectedImageIDs, beforeAction: .rotateImagesRight)
    }

    func rotateImages(withID someIDs: Set<Int64>, by angle: Double, total: Float) {
        var remainingIDs = someIDs
        guard let imageID = remainingIDs.first else {
            // Save changes
//            bckgContext.saveIfNeeded()
            // Close HUD with success
            DispatchQueue.main.async {
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
            DispatchQueue.main.async {
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
                // Retrieve updated image data i.e. width, height, URLs
                /// We retrieve URLs of thumbnails which are not in cache anymore:
                /// - available: https://piwigo…/_data/i/upload/2024/02/17/20240217192937-d5cf80b5-xx.jpg
                /// - unavailable: https://piwigo…/i.php?/upload/2024/02/17/20240217192937-d5cf80b5-xx.jpg
                let imageID = imageData.pwgID
                self.imageProvider.getInfos(forID: imageID, inCategoryId: self.albumData.pwgID) { [self] in
                    // Update HUD
                    DispatchQueue.main.async {
                        // Update progress indicator
                        let progress: Float = 1 - Float(remainingIDs.count) / total
                        self.navigationController?.updateHUD(withProgress: progress)
                        
                        // Rotate cell image
                        let visibleCells = self.collectionView?.visibleCells ?? []
                        for cell in visibleCells {
                            if let cell = cell as? ImageCollectionViewCell, cell.imageData.pwgID == imageID,
                               let updatedImage = self.images.fetchedObjects?.filter({$0.pwgID == imageID}).first {
                                cell.config(with: updatedImage, placeHolder: self.imagePlaceHolder,
                                            size: self.imageSize, sortOption: self.sortOption)
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
        } failure: { [self] error in
            rotateImagesInDatabaseError(error)
        }
    }
    
    private func rotateImagesInDatabaseError(_ error: NSError) {
        DispatchQueue.main.async { [self] in
            // Session logout required?
            if let pwgError = error as? PwgSessionError,
               [.invalidCredentials, .incompatiblePwgVersion, .invalidURL, .authenticationFailed]
                .contains(pwgError) {
                ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
                return
            }

            // Report error
            let title = NSLocalizedString("rotateImageFail_title", comment: "Rotation Failed")
            let message = NSLocalizedString("rotateImageFail_message", comment: "Image could not be rotated")
            navigationController?.dismissPiwigoError(withTitle: title, message: message,
                                    errorMessage: error.localizedDescription) { [unowned self] in
                // Hide HUD
                navigationController?.hideHUD { [self] in
                    // Re-enable buttons
                    setEnableStateOfButtons(true)
                }
            }
        }
    }
}
