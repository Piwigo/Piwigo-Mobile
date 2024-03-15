//
//  ImageViewController+Rotate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 17/02/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

@available(iOS 13.0, *)
extension ImageViewController
{
    // MARK: - Rotate Image
    @objc func rotateImage(by angle: Double) {
        guard let imageData = imageData else { return }
        // Disable buttons during action
        setEnableStateOfButtons(false)

        // Display HUD during rotation
        showPiwigoHUD(withTitle: NSLocalizedString("rotateSingleImageHUD_rotating", comment: "Rotating Photo…"), detail: "", buttonTitle: "", buttonTarget: nil, buttonSelector: nil, inMode: .indeterminate)
        
        // Send request to Piwigo server
        NetworkUtilities.checkSession(ofUser: user) { [self] in
            ImageUtilities.rotate(imageData, by: angle) { [self] in
                // Retrieve updated image data i.e. width, height, URLs
                /// We retrieve URLs of thumbnails which are not in cache anymore:
                /// - available: https://piwigo…/_data/i/upload/2024/02/17/20240217192937-d5cf80b5-xx.jpg
                /// - unavailable: https://piwigo…/i.php?/upload/2024/02/17/20240217192937-d5cf80b5-xx.jpg
                let imageID = imageData.pwgID
                self.imageProvider.getInfos(forID: imageID, inCategoryId: self.categoryId) {
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
                            imageDVC.rotateImageView(by: angle) {
                                // Hide HUD
                                self.updatePiwigoHUDwithSuccess { [self] in
                                    self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { [self] in
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

            // Report error
            let title = NSLocalizedString("rotateImageFail_title", comment: "Rotation Failed")
            let message = NSLocalizedString("rotateImageFail_message", comment: "Image could not be rotated")
            self.dismissPiwigoError(withTitle: title, message: message,
                                    errorMessage: error.localizedDescription) { [unowned self] in
                // Hide HUD
                hidePiwigoHUD { [self] in
                    // Re-enable buttons
                    setEnableStateOfButtons(true)
                }
            }
        }
    }
}
