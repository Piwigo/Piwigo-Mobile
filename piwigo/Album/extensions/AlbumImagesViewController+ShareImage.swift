//
//  AlbumImagesViewController+ShareImage.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 29/05/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: ShareImageActivityItemProviderDelegate Methods
extension AlbumImagesViewController: ShareImageActivityItemProviderDelegate
{
    func imageActivityItemProviderPreprocessingDidBegin(_ imageActivityItemProvider: UIActivityItemProvider?,
                                                        withTitle title: String) {
        // Show HUD to let the user know the image is being downloaded in the background.
        let detail = String(format: "%d / %d", totalNumberOfImages - selectedImageIds.count + 1, totalNumberOfImages)
        presentedViewController?.showPiwigoHUD(withTitle: title, detail: detail,
                                               buttonTitle: NSLocalizedString("alertCancelButton", comment: "Cancel"),
                                               buttonTarget: self, buttonSelector: #selector(cancelShareImages),
                                               inMode: .annularDeterminate)
    }
    
    func imageActivityItemProvider(_ imageActivityItemProvider: UIActivityItemProvider?,
                                   preprocessingProgressDidUpdate progress: Float) {
        // Update HUD
        presentedViewController?.updatePiwigoHUD(withProgress: progress)
    }
    
    func imageActivityItemProviderPreprocessingDidEnd(_ imageActivityItemProvider: UIActivityItemProvider?,
                                                      withImageId imageId: Int) {
        // Check activity item provider
        guard let imageActivityItemProvider = imageActivityItemProvider else { return }
        
        // Close HUD
        let imageIdObject = NSNumber(value: imageId)
        if imageActivityItemProvider.isCancelled {
            presentedViewController?.hidePiwigoHUD { }
        } else if selectedImageIds.contains(imageIdObject) {
            // Remove image from selection
            selectedImageIds.remove(imageIdObject)
            updateButtonsInSelectionMode()

            // Close HUD if last image
            if selectedImageIds.count == 0 {
                presentedViewController?.updatePiwigoHUDwithSuccess {
                    self.presentedViewController?.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { }
                }
            }
        }
    }
    
    func showError(withTitle title: String, andMessage message: String?) {
        // Cancel remaining shares
        cancelShareImages()
        
        // Close HUD if needed
        presentedViewController?.hidePiwigoHUD { }
        
        // Display error alert after trying to share image
        presentedViewController?.dismissPiwigoError(withTitle: title, message: message ?? "") {
            // Close ActivityView
            self.presentedViewController?.dismiss(animated: true)
        }
    }
}

