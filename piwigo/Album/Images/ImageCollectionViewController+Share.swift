//
//  ImageCollectionViewController+Share.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import Photos
import UIKit

extension ImageCollectionViewController
{
    // MARK: Share Bar Button
    func getShareBarButton() -> UIBarButtonItem {
        let button = UIBarButtonItem(barButtonSystemItem: .action, target: self,
                                     action: #selector(shareSelection))
        button.tintColor = UIColor.piwigoColorOrange()
        return button
    }


    // MARK: Share Images
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
        totalNumberOfImages = selectedImageIds.count
        var itemsToShare: [UIActivityItemProvider] = []
        for selectedImageId in selectedImageIds {
            guard let selectedImage = (images.fetchedObjects ?? []).first(where: {$0.pwgID == selectedImageId})
                else { continue }
            if selectedImage.isVideo {
                // Case of a video
                let videoItemProvider = ShareVideoActivityItemProvider(placeholderImage: selectedImage)

                // Use delegation to monitor the progress of the item method
                videoItemProvider.delegate = self

                // Add to list of items to share
                itemsToShare.append(videoItemProvider)

                // Exclude "assign to contact" activity
                excludedActivityTypes.append(.assignToContact)
                
            } else {
                // Case of an image
                let imageItemProvider = ShareImageActivityItemProvider(placeholderImage: selectedImage)

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

                // Deselect images
                imageSelectionDelegate?.deselectImages()

                // Close HUD with success
                presentedViewController?.updateHUDwithSuccess() { [self] in
                    presentedViewController?.hideHUD(afterDelay: pwgDelayHUD) { [self] in
                        // Close ActivityView
                        presentedViewController?.dismiss(animated: true)
                    }
                }
            } else {
                if activityType == nil {
                    // User dismissed the view controller without making a selection.
                    imageSelectionDelegate?.updateSelectMode(withInit: false)
                } else {
                    // Check what to do with selection
                    if selectedImageIds.isEmpty {
                        imageSelectionDelegate?.deselectImages()
                    } else {
                        imageSelectionDelegate?.setButtonsState(true)
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
        if let parent = parent as? AlbumImageTableViewController {
            activityViewController.popoverPresentationController?.barButtonItem = parent.shareBarButton
        }
        present(activityViewController, animated: true)
    }

    @objc func cancelShareImages() {
        // Cancel image file download and remaining activity shares if any
        NotificationCenter.default.post(name: .pwgCancelDownload, object: nil)
    }
}


// MARK: - ShareImageActivityItemProviderDelegate Methods
extension ImageCollectionViewController: ShareImageActivityItemProviderDelegate
{
    func imageActivityItemProviderPreprocessingDidBegin(_ imageActivityItemProvider: UIActivityItemProvider?,
                                                        withTitle title: String) {
        // Show HUD to let the user know the image is being downloaded in the background.
        let detail = String(format: "%d / %d", totalNumberOfImages - selectedImageIds.count + 1, totalNumberOfImages)
        if presentedViewController?.isShowingHUD() ?? false {
            presentedViewController?.updateHUD(title: title, detail: detail)
        } else {
            presentedViewController?.showHUD(withTitle: title, detail: detail,
                                             buttonTitle: NSLocalizedString("alertCancelButton", comment: "Cancel"),
                                             buttonTarget: self, buttonSelector: #selector(cancelShareImages),
                                             inMode: .determinate)
        }
    }
    
    func imageActivityItemProvider(_ imageActivityItemProvider: UIActivityItemProvider?,
                                   preprocessingProgressDidUpdate progress: Float) {
        // Update HUD
        presentedViewController?.updateHUD(withProgress: progress)
    }
    
    func imageActivityItemProviderPreprocessingDidEnd(_ imageActivityItemProvider: UIActivityItemProvider?,
                                                      withImageId imageId: Int64) {
        // Check activity item provider
        guard let imageActivityItemProvider = imageActivityItemProvider else { return }
        
        // Close HUD
        if imageActivityItemProvider.isCancelled {
            presentedViewController?.hideHUD { }
        } else if selectedImageIds.contains(imageId) {
            // Remove image from selection
            selectedImageIds.remove(imageId)
            selectedFavoriteIds.remove(imageId)
            selectedVideosIds.remove(imageId)
            imageSelectionDelegate?.updateSelectMode(withInit: false)

            // Close HUD if last image
            if selectedImageIds.count == 0 {
                presentedViewController?.updateHUDwithSuccess { [self] in
                    self.presentedViewController?.hideHUD(afterDelay: pwgDelayHUD) { }
                }
            }
        }
    }
    
    func showError(withTitle title: String, andMessage message: String?) {
        // Cancel remaining shares
        cancelShareImages()
        
        // Close HUD if needed
        presentedViewController?.hideHUD { }
        
        // Display error alert after trying to share image
        presentedViewController?.dismissPiwigoError(withTitle: title, message: message ?? "") { [self] in
            // Close ActivityView
            self.presentedViewController?.dismiss(animated: true)
        }
    }
}

