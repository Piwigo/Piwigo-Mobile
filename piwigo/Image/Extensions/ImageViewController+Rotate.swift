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
            self.rotateImage(by: CGFloat(-.pi/2.0))
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
            self.rotateImage(by: CGFloat(.pi/2.0))
        })
        action.accessibilityIdentifier = "Rotate Left"
        return action
    }
}


@available(iOS 13.0, *)
extension ImageViewController
{
    // MARK: - Rotate Image
    @objc func rotateImage(by angle: CGFloat) {
        guard let imageData = imageData else { return }
        // Disable buttons during action
        setEnableStateOfButtons(false)

        // Display HUD during rotation
        showHUD(withTitle: NSLocalizedString("rotateSingleImageHUD_rotating", comment: "Rotating Photo…"))
        
        // Send request to Piwigo server
        PwgSession.checkSession(ofUser: user) { [self] in
            ImageUtilities.rotate(imageData, by: angle) { [self] in
                DispatchQueue.main.async { [self] in
                    // Rotate image view
                    if let imageDVC = pageViewController?.viewControllers?.first as? ImageDetailViewController {
                        // Zoom out if needed
                        imageDVC.scrollView.setZoomScale(imageDVC.scrollView.minimumZoomScale, animated: true)
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
                    // Update thumbnails if needed
                    if let children = presentingViewController?.children {
                        let albumVCs = children.compactMap({$0 as? AlbumViewController}).filter({$0.categoryId != Int32.zero})
                        albumVCs.forEach { albumVC in
                            let visibleCells = albumVC.collectionView?.visibleCells ?? []
                            let imageCells = visibleCells.compactMap({$0 as? ImageCollectionViewCell})
                            if let cell = imageCells.first(where: { $0.imageData.pwgID == imageData.pwgID}) {
                                cell.config(withImageData: imageData, size: albumVC.imageSize, sortOption: albumVC.sortOption)
                            }
                        }
                    }
                    // Save changes
                    try? self.mainContext.save()
                }
            } failure: { [self] error in
                self.rotateImageInDatabaseError(error)
            }
        } failure: { [self] error in
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
            
            // Hide HUD
            self.hideHUD { [self] in
                // Plugin rotateImage installed?
                let title = NSLocalizedString("rotateImageFail_title", comment: "Rotation Failed")
                var message = "", errorMsg = ""
                if let pwgError = error as? PwgSessionError,
                   pwgError == .otherError(code: 501, msg: "") {
                    message = NSLocalizedString("rotateImageFail_plugin", comment: "The rotateImage plugin is not activated.")
                }
                else {
                    message = NSLocalizedString("rotateImageFail_message", comment: "Image could not be rotated")
                    errorMsg = error.localizedDescription
                }
                
                // Report error
                self.dismissPiwigoError(withTitle: title, message: message,
                                        errorMessage: errorMsg) { [self] in
                    // Re-enable buttons
                    setEnableStateOfButtons(true)
                }
            }
        }
    }
}
