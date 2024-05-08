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
        if selectedVideosIds.isEmpty {
            return UIMenu(title: NSLocalizedString("rotateImage_rotate", comment: "Rotate 90°…"),
                          image: nil,
                          identifier: UIMenu.Identifier("org.piwigo.piwigoImages.rotate"),
                          children: [rotateRightAction(), rotateLeftAction()])
        }
        return nil
    }
    
    private func rotateRightAction() -> UIAction {
        // Rotate image right
        let action = UIAction(title: NSLocalizedString("rotateImage_right", comment: "Clockwise"),
                              image: UIImage(systemName: "rotate.right"),
                              handler: { _ in
            // Edit image informations
            self.rotateImagesRight()
        })
        action.accessibilityIdentifier = "Rotate Right"
        return action
    }

    private func rotateLeftAction() -> UIAction {
        // Rotate image left
        let action = UIAction(title: NSLocalizedString("rotateImage_left", comment: "Counterclockwise"),
                              image: UIImage(systemName: "rotate.left"),
                              handler: { _ in
            // Edit image informations
            self.rotateImagesLeft()
        })
        action.accessibilityIdentifier = "Rotate Left"
        return action
    }
}


extension AlbumViewController
{
    // MARK: - Rotate Image
    @objc func rotateImagesLeft() {
        initSelection(beforeAction: .rotateImagesLeft)
    }

    @objc func rotateImagesRight() {
        initSelection(beforeAction: .rotateImagesRight)
    }

    func rotateImages(by angle: Double) {
        guard let imageId = selectedImageIds.first else {
            // Save changes
//            bckgContext.saveIfNeeded()
            // Close HUD with success
            navigationController?.updateHUDwithSuccess() { [self] in
                navigationController?.hideHUD(afterDelay: pwgDelayHUD) { [self] in
                    // Deselect images
                    cancelSelect()
                }
            }
            return
        }

        // Get image data
        guard let imageData = (images.fetchedObjects ?? []).first(where: {$0.pwgID == imageId}) else {
            // Forget this image
            selectedImageIds.removeFirst()
            selectedFavoriteIds.remove(imageId)
            selectedVideosIds.remove(imageId)

            // Update HUD
            navigationController?.updateHUD(withProgress: 1.0 - Float(selectedImageIds.count) / Float(totalNumberOfImages))

            // Next image
            rotateImages(by: angle)
            return
        }

        // Send request to Piwigo server
        NetworkUtilities.checkSession(ofUser: user) { [self] in
            ImageUtilities.rotate(imageData, by: angle) { [self] in
                // Retrieve updated image data i.e. width, height, URLs
                /// We retrieve URLs of thumbnails which are not in cache anymore:
                /// - available: https://piwigo…/_data/i/upload/2024/02/17/20240217192937-d5cf80b5-xx.jpg
                /// - unavailable: https://piwigo…/i.php?/upload/2024/02/17/20240217192937-d5cf80b5-xx.jpg
                let imageID = imageData.pwgID
                self.imageProvider.getInfos(forID: imageID, inCategoryId: self.albumData.pwgID) { [self] in
                    // Update HUD
                    navigationController?.updateHUD(withProgress: 1.0 - Float(self.selectedImageIds.count) / Float(self.totalNumberOfImages))
                    
                    // Next image
                    selectedImageIds.removeFirst()
                    selectedFavoriteIds.remove(imageId)
                    selectedVideosIds.remove(imageId)
                    rotateImages(by: angle)
                    
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
