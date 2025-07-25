//
//  ImageViewController+Share.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

extension ImageViewController
{
    // MARK: - Share Image Bar Button
    func getShareButton() -> UIBarButtonItem? {
        // Since Piwigo 14, pwg.categories.getImages method returns download_url if the user has download rights
        // For previous versions, we assume that all only registered users have download rights
        if user.canDownloadImages() {
            return UIBarButtonItem.shareImageButton(self, action: #selector(ImageViewController.shareImage))
        } else {
            return nil
        }
    }


    // MARK: - Share Image
    @MainActor
    @objc func shareImage() {
        // Disable buttons during action
        setEnableStateOfButtons(false)

        // Check input image data
        guard let imageData = imageData, imageData.isPDF == false
        else {
            DispatchQueue.main.async { [self] in
                self.presentShareImageViewController(withCameraRollAccess: false)
            }
            return
        }

        // Check autorisation to access Photo Library (camera roll) if needed
        if #available(iOS 14, *) {
            PhotosFetch.shared.checkPhotoLibraryAuthorizationStatus(for: .addOnly, for: self,
                onAccess: { [self] in
                    // User allowed to save image in camera roll
                    DispatchQueue.main.async { [self] in
                        self.presentShareImageViewController(withCameraRollAccess: true)
                    }
            }, onDeniedAccess: { [self] in
                    // User not allowed to save image in camera roll
                    DispatchQueue.main.async { [self] in
                        self.presentShareImageViewController(withCameraRollAccess: false)
                    }
                })
        } else {
            // Fallback on earlier versions
            PhotosFetch.shared.checkPhotoLibraryAccessForViewController(nil,
                onAuthorizedAccess: { [self] in
                    // User allowed to save image in camera roll
                    DispatchQueue.main.async { [self] in
                        self.presentShareImageViewController(withCameraRollAccess: true)
                    }
            }, onDeniedAccess: { [self] in
                    // User not allowed to save image in camera roll
                    DispatchQueue.main.async { [self] in
                        self.presentShareImageViewController(withCameraRollAccess: false)
                    }
                })
        }
    }

    @MainActor
    func presentShareImageViewController(withCameraRollAccess hasCameraRollAccess: Bool) {
        // To exclude some activity types
        var excludedActivityTypes = Set<UIActivity.ActivityType>()

        // Check input image data
        guard let imageData = imageData else { return }
        
        // Create new activity provider item to pass to the activity view controller
        var itemsToShare: [AnyHashable] = []
        if imageData.isVideo {
            // Case of a video
            let videoItemProvider = ShareVideoActivityItemProvider(placeholderImage: imageData, contextually: false)

            // Use delegation to monitor the progress of the item method
            videoItemProvider.delegate = self

            // Add to list of items to share
            itemsToShare.append(videoItemProvider)

            // Exclude "assign to contact" activity
            excludedActivityTypes.insert(.assignToContact)
            if #available(iOS 16.4, *) {
                excludedActivityTypes.formUnion([.addToHomeScreen,
                                                 .collaborationCopyLink, .collaborationInviteWithLink])
            }
        }
        else if imageData.isPDF {
            // Case of a PDF file
            let pdfItemProvider = SharePdfActivityItemProvider(placeholderImage: imageData, contextually: false)

            // Use delegation to monitor the progress of the item method
            pdfItemProvider.delegate = self

            // Add to list of items to share
            itemsToShare.append(pdfItemProvider)

            // Exclude "assign to contact" activity
            excludedActivityTypes.formUnion([.assignToContact, .saveToCameraRoll,
                                             .postToFacebook, .postToTwitter, .postToWeibo,
                                             .postToVimeo, .postToTencentWeibo])
            if #available(iOS 16.4, *) {
                excludedActivityTypes.formUnion([.addToHomeScreen,
                                                 .collaborationCopyLink, .collaborationInviteWithLink])
            }
        }
        else {
            // Case of an image
            let imageItemProvider = ShareImageActivityItemProvider(placeholderImage: imageData, contextually: false)

            // Use delegation to monitor the progress of the item method
            imageItemProvider.delegate = self

            // Add to list of items to share
            itemsToShare.append(imageItemProvider)
        }

        // Create an activity view controller with the activity provider item.
        // ShareImageActivityItemProvider's superclass conforms to the UIActivityItemSource protocol
        let activityViewController = UIActivityViewController(activityItems: itemsToShare,
                                                              applicationActivities: nil)

        // Exclude some activity types if needed
        if !hasCameraRollAccess {
            // Exclude "camera roll" activity when the Photo Library is not accessible
            excludedActivityTypes.insert(.saveToCameraRoll)
        }
        activityViewController.excludedActivityTypes = Array(excludedActivityTypes)

        // Delete image/video file and remove observers after dismissing activity view controller
        activityViewController.completionWithItemsHandler = { [self] activityType, completed, returnedItems, activityError in
//            debugPrint("Activity Type selected: \(activityType)")

            // If needed, sets items so that they will be deleted after a delay
            let delay = pwgClearClipboard(rawValue: AppVars.shared.clearClipboardDelay)?.seconds ?? 0.0
            if delay > 0, activityType == .copyToPasteboard {
                let items = UIPasteboard.general.items
                let expirationDate: NSDate = NSDate.init(timeIntervalSinceNow: delay)
                let options: [UIPasteboard.OptionsKey : Any] = [.expirationDate : expirationDate]
                UIPasteboard.general.setItems(items, options: options)
            }
            
            // Enable buttons after action
            setEnableStateOfButtons(true)

            // Remove observers
            NotificationCenter.default.post(name: .pwgDidShare, object: nil)

            if !completed {
                if activityType == nil {
                    debugPrint("User dismissed the view controller without making a selection.");
                } else {
                    debugPrint("Activity was not performed.")
                    // Cancel download task
                    NotificationCenter.default.post(name: .pwgCancelDownload, object: nil)
                }
            } else {
                // Update server statistics
                logImageVisitIfNeeded(imageData.pwgID, asDownload: true)
            }
        }

        // Present share image activity view controller
        activityViewController.popoverPresentationController?.barButtonItem = shareBarButton
        present(activityViewController, animated: true)
    }

    @objc func cancelShareImage() {
        // Cancel file donwload
        NotificationCenter.default.post(name: .pwgCancelDownload, object: nil)
    }
}


// MARK: - ShareImageActivityItemProviderDelegate Methods
extension ImageViewController: ShareImageActivityItemProviderDelegate
{
    func imageActivityItemProviderPreprocessingDidBegin(_ imageActivityItemProvider: UIActivityItemProvider?, withTitle title: String) {
        // Show HUD to let the user know the image is being downloaded in the background.
        let cancelButton = NSLocalizedString("alertCancelButton", comment: "Cancel")
        presentedViewController?.showHUD(withTitle: title, buttonTitle: cancelButton, buttonTarget: self, 
                                         buttonSelector: #selector(cancelShareImage), inMode: .determinate)
    }

    func imageActivityItemProvider(_ imageActivityItemProvider: UIActivityItemProvider?, preprocessingProgressDidUpdate progress: Float) {
        // Update HUD
        presentedViewController?.updateHUD(withProgress: progress)
    }

    func imageActivityItemProviderPreprocessingDidEnd(_ imageActivityItemProvider: UIActivityItemProvider?, withImageID imageID: Int64, contextually:Bool) {
        // Close HUD
        if imageActivityItemProvider?.isCancelled ?? false {
            presentedViewController?.hideHUD { }
        } else {
            presentedViewController?.updateHUDwithSuccess(completion: { [self] in
                presentedViewController?.hideHUD(completion: { })
            })
        }
    }

    func showError(withTitle title: String, andMessage message: String?) {
        // Display error alert after trying to share image
        presentedViewController?.dismissPiwigoError(withTitle: title, message: message ?? "") { [self] in
            // Closes ActivityView
            presentedViewController?.dismiss(animated: true)
        }
    }
}
