//
//  AlbumImagesViewController+Share.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 29/05/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import Photos

// MARK: Share Images
extension AlbumImagesViewController
{
    @objc func shareSelection() {
        initSelection(beforeAction: .share)
    }

    func checkPhotoLibraryAccessBeforeShare() {
        // Check autorisation to access Photo Library (camera roll)
        if #available(iOS 14, *) {
            PhotosFetch.shared.checkPhotoLibraryAuthorizationStatus(
                for: PHAccessLevel.addOnly, for: self,
                onAccess: { [self] in
                    // User allowed to save image in camera roll
                    presentShareImageViewController(withCameraRollAccess: true)
                },
                onDeniedAccess: { [self] in
                    // User not allowed to save image in camera roll
                    DispatchQueue.main.async { [self] in
                        presentShareImageViewController(withCameraRollAccess: false)
                    }
                })
        } else {
            // Fallback on earlier versions
            PhotosFetch.shared.checkPhotoLibraryAccessForViewController(nil) { [self] in
                // User allowed to save image in camera roll
                presentShareImageViewController(withCameraRollAccess: true)
            } onDeniedAccess: { [self] in
                // User not allowed to save image in camera roll
                if Thread.isMainThread {
                    self.presentShareImageViewController(withCameraRollAccess: false)
                } else {
                    DispatchQueue.main.async(execute: { [self] in
                        presentShareImageViewController(withCameraRollAccess: false)
                    })
                }
            }
        }
    }

    func presentShareImageViewController(withCameraRollAccess hasCameraRollAccess: Bool) {
        // To exclude some activity types
        var excludedActivityTypes = [UIActivity.ActivityType]()

        // Create new activity provider items to pass to the activity view controller
        totalNumberOfImages = selectedImageData.count
        var itemsToShare: [UIActivityItemProvider] = []
        for imageData in selectedImageData {
            if imageData.isVideo {
                // Case of a video
                let videoItemProvider = ShareVideoActivityItemProvider(placeholderImage: imageData)

                // Use delegation to monitor the progress of the item method
                videoItemProvider.delegate = self

                // Add to list of items to share
                itemsToShare.append(videoItemProvider)

                // Exclude "assign to contact" activity
                excludedActivityTypes.append(.assignToContact)
                
            } else {
                // Case of an image
                let imageItemProvider = ShareImageActivityItemProvider(placeholderImage: imageData)

                // Use delegation to monitor the progress of the item method
                imageItemProvider.delegate = self

                // Add to list of items to share
                itemsToShare.append(imageItemProvider)
            }
        }

        // Create an activity view controller with the activity provider item.
        // ShareImageActivityItemProvider's superclass conforms to the UIActivityItemSource protocol
        let activityViewController = UIActivityViewController(activityItems: itemsToShare, applicationActivities: nil)

        // Exclude camera roll activity if needed
        if !hasCameraRollAccess {
            // Exclude "camera roll" activity when the Photo Library is not accessible
            excludedActivityTypes.append(.saveToCameraRoll)
        }
        activityViewController.excludedActivityTypes = Array(excludedActivityTypes)

        // Delete image/video files and remove observers after dismissing activity view controller
        activityViewController.completionWithItemsHandler = { [self] activityType, completed, returnedItems, activityError in
            //        NSLog(@"Activity Type selected: %@", activityType);
            if completed {
                //            NSLog(@"Selected activity was performed and returned error:%ld", (long)activityError.code);
                // Delete shared files & remove observers
                NotificationCenter.default.post(name: .pwgDidShare, object: nil)

                // Close HUD with success
                updatePiwigoHUDwithSuccess() { [self] in
                    hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { [self] in
                        // Deselect images
                        cancelSelect()
                        // Close ActivityView
                        presentedViewController?.dismiss(animated: true)
                    }
                }
            } else {
                if activityType == nil {
                    //                NSLog(@"User dismissed the view controller without making a selection.");
                    updateButtonsInSelectionMode()
                } else {
                    // Check what to do with selection
                    if selectedImageIds.isEmpty {
                        cancelSelect()
                    } else {
                        setEnableStateOfButtons(true)
                    }

                    // Cancel download task
                    NotificationCenter.default.post(name: .pwgCancelDownload, object: nil)

                    // Delete shared file & remove observers
                    NotificationCenter.default.post(name: .pwgDidShare, object: nil)

                    // Close ActivityView
                    presentedViewController?.dismiss(animated: true)
                }
            }
        }

        // Present share image activity view controller
        activityViewController.popoverPresentationController?.barButtonItem = shareBarButton
        present(activityViewController, animated: true)
    }

    @objc func cancelShareImages() {
        // Cancel image file download and remaining activity shares if any
        NotificationCenter.default.post(name: .pwgCancelDownload, object: nil)
    }
}


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
            selectedImageIds.removeAll(where: {$0 == imageIdObject})
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

