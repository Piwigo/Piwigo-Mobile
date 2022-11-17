//
//  ImageViewController+Share.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

extension ImageViewController
{
    // MARK: - Share Image
    @objc func shareImage() {
        // Disable buttons during action
        setEnableStateOfButtons(false)

        // Check autorisation to access Photo Library (camera roll)
        if #available(iOS 14, *) {
            PhotosFetch.shared.checkPhotoLibraryAuthorizationStatus(for: .addOnly, for: self,
                onAccess: { [unowned self] in
                    // User allowed to save image in camera roll
                    presentShareImageViewController(withCameraRollAccess: true)
                },
                onDeniedAccess: { [unowned self] in
                    // User not allowed to save image in camera roll
                    if Thread.isMainThread {
                        presentShareImageViewController(withCameraRollAccess: false)
                    } else {
                        DispatchQueue.main.async(execute: { [self] in
                            presentShareImageViewController(withCameraRollAccess: false)
                        })
                    }
                })
        } else {
            // Fallback on earlier versions
            PhotosFetch.shared.checkPhotoLibraryAccessForViewController(nil,
                onAuthorizedAccess: { [unowned self] in
                    // User allowed to save image in camera roll
                    presentShareImageViewController(withCameraRollAccess: true)
                },
                onDeniedAccess: { [unowned self] in
                    // User not allowed to save image in camera roll
                    if Thread.isMainThread {
                        presentShareImageViewController(withCameraRollAccess: false)
                    } else {
                        DispatchQueue.main.async(execute: { [self] in
                            presentShareImageViewController(withCameraRollAccess: false)
                        })
                    }
                })
        }
    }

    func presentShareImageViewController(withCameraRollAccess hasCameraRollAccess: Bool) {
        // To exclude some activity types
        var excludedActivityTypes = [UIActivity.ActivityType]()

        // Create new activity provider item to pass to the activity view controller
        var itemsToShare: [AnyHashable] = []
        if imageData.isVideo {
            // Case of a video
            let videoItemProvider = ShareVideoActivityItemProvider(placeholderImage: imageData)

            // Use delegation to monitor the progress of the item method
            videoItemProvider.delegate = self

            // Add to list of items to share
            itemsToShare.append(videoItemProvider)

            // Exclude "assign to contact" activity
            excludedActivityTypes.append(.assignToContact)
        }
        else {
            // Case of an image
            let imageItemProvider = ShareImageActivityItemProvider(placeholderImage: imageData)

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
            excludedActivityTypes.append(.saveToCameraRoll)
        }
        activityViewController.excludedActivityTypes = Array(excludedActivityTypes)

        // Delete image/video file and remove observers after dismissing activity view controller
        activityViewController.completionWithItemsHandler = { [self] activityType, completed, returnedItems, activityError in
//            debugPrint("Activity Type selected: \(activityType)")

            // If needed, sets items so that they will be deleted after a delay
            if #available(iOS 10.0, *) {
                let delay = pwgClearClipboard(rawValue: AppVars.shared.clearClipboardDelay)?.seconds ?? 0.0
                if delay > 0, activityType == .copyToPasteboard {
                    let items = UIPasteboard.general.items
                    let expirationDate: NSDate = NSDate.init(timeIntervalSinceNow: delay)
                    let options: [UIPasteboard.OptionsKey : Any] = [.expirationDate : expirationDate]
                    UIPasteboard.general.setItems(items, options: options)
                }
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
        presentedViewController?.showPiwigoHUD(withTitle: title, detail: "", buttonTitle: NSLocalizedString("alertCancelButton", comment: "Cancel"), buttonTarget: self, buttonSelector: #selector(cancelShareImage), inMode: .annularDeterminate)
    }

    func imageActivityItemProvider(_ imageActivityItemProvider: UIActivityItemProvider?, preprocessingProgressDidUpdate progress: Float) {
        // Update HUD
        presentedViewController?.updatePiwigoHUD(withProgress: progress)
    }

    func imageActivityItemProviderPreprocessingDidEnd(_ imageActivityItemProvider: UIActivityItemProvider?, withImageId imageId: Int64) {
        // Close HUD
        if imageActivityItemProvider?.isCancelled ?? false {
            presentedViewController?.hidePiwigoHUD(completion: {
            })
        } else {
            presentedViewController?.updatePiwigoHUDwithSuccess(completion: { [self] in
                presentedViewController?.hidePiwigoHUD(completion: {
                })
            })
        }
    }

    func showError(withTitle title: String, andMessage message: String?) {
        // Display error alert after trying to share image
        presentedViewController?.dismissPiwigoError(withTitle: title, message: message ?? "") { [unowned self] in
            // Closes ActivityView
            presentedViewController?.dismiss(animated: true)
        }
    }
}
