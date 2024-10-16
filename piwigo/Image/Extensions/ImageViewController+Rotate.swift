//
//  ImageViewController+Rotate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 17/02/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

// MARK: - Rotate Image Actions
@available(iOS 14, *)
extension ImageViewController
{
    func rotateMenu() -> UIMenu {
        return UIMenu(title: NSLocalizedString("rotateImage_rotate", comment: "Rotate 90°…"),
                      image: nil,
                      identifier: UIMenu.Identifier("org.piwigo.piwigoImage.rotate"),
                      children: [rotateRightAction(), rotateLeftAction()])
    }
    
    func rotateRightAction() -> UIAction {
        // Rotate image right
        let action = UIAction(title: NSLocalizedString("rotateImage_right", comment: "Clockwise"),
                              image: UIImage(systemName: "rotate.right"),
                              handler: { [self] _ in
            // Edit image informations
            self.rotateImage(by: -90.0)
        })
        action.accessibilityIdentifier = "Rotate Right"
        return action
    }

    func rotateLeftAction() -> UIAction {
        // Rotate image left
        let action = UIAction(title: NSLocalizedString("rotateImage_left", comment: "Counterclockwise"),
                              image: UIImage(systemName: "rotate.left"),
                              handler: { [self] _ in
            // Edit image informations
            self.rotateImage(by: 90.0)
        })
        action.accessibilityIdentifier = "Rotate Left"
        return action
    }
}


@available(iOS 13.0, *)
extension ImageViewController
{
    // MARK: - Rotate Image
    @objc func rotateImage(by angle: Double) {
        guard let imageData = imageData else { return }
        // Disable buttons during action
        setEnableStateOfButtons(false)

        // Display HUD during rotation
        showHUD(withTitle: NSLocalizedString("rotateSingleImageHUD_rotating", comment: "Rotating Photo…"))
        
        // Send request to Piwigo server
        PwgSession.checkSession(ofUser: user) { [unowned self] in
            ImageUtilities.rotate(imageData, by: angle) { [self] in
                // Retrieve updated image data i.e. width, height, URLs
                /// We retrieve URLs of thumbnails which are not in cache anymore:
                /// - available: https://piwigo…/_data/i/upload/2024/02/17/20240217192937-d5cf80b5-xx.jpg
                /// - unavailable: https://piwigo…/i.php?/upload/2024/02/17/20240217192937-d5cf80b5-xx.jpg
                let imageID = imageData.pwgID
                self.imageProvider.getInfos(forID: imageID, inCategoryId: self.categoryId) { [self] in
                    // Download image in cache and present it
                    DispatchQueue.main.async { [self] in
                        if let imageDVC = pageViewController?.viewControllers?.first as? ImageDetailViewController,
                           let updatedImage = self.images.fetchedObjects?.filter({$0.pwgID == imageID}).first {
                            // Zoom out if needed
                            imageDVC.scrollView.setZoomScale(imageDVC.scrollView.minimumZoomScale, animated: true)
                            // Update image data
                            if updatedImage.isFault {
                                // The album is not fired yet.
                                updatedImage.willAccessValue(forKey: nil)
                                updatedImage.didAccessValue(forKey: nil)
                            }
                            imageDVC.imageData = updatedImage
                            // Rotate image view
                            imageDVC.rotateImageView(by: angle) { [self] in
                                // Hide HUD
                                self.updateHUDwithSuccess { [self] in
                                    self.hideHUD(afterDelay: pwgDelayHUD) { [self] in
                                        // Re-enable buttons
                                        setEnableStateOfButtons(true)
                                    }
                                }
                            }
                        }
                    }
                } failure: { [self] error in
                    self.rotateImageInDatabaseError(error)
                }
            } failure: { [self] error in
                self.rotateImageInDatabaseError(error)
            }
        } failure: { [unowned self] error in
            self.rotateImageInDatabaseError(error)
        }
    }
    
    private func rotateImageInDatabaseError(_ error: NSError) {
        DispatchQueue.main.async { [self] in
            // Session logout required?
            if let pwgError = error as? PwgSessionError,
               [.invalidCredentials, .incompatiblePwgVersion, .invalidURL, .authenticationFailed]
                .contains(pwgError) {
                ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
                return
            }
            
            // Plugin rotateImage installed?
            let title = NSLocalizedString("rotateImageFail_title", comment: "Rotation Failed")
            var message = ""
            if let pwgError = error as? PwgSessionError,
               pwgError == .invalidMethod {
                message = NSLocalizedString("rotateImageFail_plugin", comment: "The rotateImage plugin is not activated.")
            }
            else {
                message = NSLocalizedString("rotateImageFail_message", comment: "Image could not be rotated")
            }

            // Report error
            self.dismissPiwigoError(withTitle: title, message: message,
                                    errorMessage: error.localizedDescription) { [self] in
                // Hide HUD
                hideHUD { [self] in
                    // Re-enable buttons
                    setEnableStateOfButtons(true)
                }
            }
        }
    }
}
