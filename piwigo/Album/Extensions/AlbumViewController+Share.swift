//
//  AlbumViewController+Share.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import Photos
import UIKit
import piwigoKit

extension AlbumViewController
{
    // MARK: Share Bar Button
    func getShareBarButton() -> UIBarButtonItem? {
        // Since Piwigo 14, pwg.categories.getImages method returns download_url if the user has download rights
        // For previous versions, we assume that all only registered users have download rights
        if user.canDownloadImages() {
            let button = UIBarButtonItem(barButtonSystemItem: .action, target: self,
                                         action: #selector(shareSelection))
            button.tintColor = UIColor.piwigoColorOrange()
            return button
        } else {
            return nil
        }
    }


    // MARK: Share Images
    @objc func shareSelection() {
        initSelection(ofImagesWithIDs: selectedImageIDs, beforeAction: .share, contextually: false)
    }

    func checkPhotoLibraryAccessBeforeSharing(imagesWithID imageIDs: Set<Int64>, contextually: Bool) {
        // Check autorisation to access Photo Library (camera roll)
        if #available(iOS 14, *) {
            PhotosFetch.shared.checkPhotoLibraryAuthorizationStatus(
                for: PHAccessLevel.addOnly, for: self,
                onAccess: { [self] in
                    // User allowed to save image in camera roll
                    DispatchQueue.main.async {
                        self.shareImages(withID: imageIDs, withCameraRollAccess: true, contextually: contextually)
                    }
                },
                onDeniedAccess: { [self] in
                    // User not allowed to save image in camera roll
                    DispatchQueue.main.async {
                        self.shareImages(withID: imageIDs, withCameraRollAccess: false, contextually: contextually)
                    }
                })
        } else {
            // Fallback on earlier versions
            PhotosFetch.shared.checkPhotoLibraryAccessForViewController(nil) { [self] in
                // User allowed to save image in camera roll
                DispatchQueue.main.async {
                    self.shareImages(withID: imageIDs, withCameraRollAccess: true, contextually: contextually)
                }
            } onDeniedAccess: { [self] in
                // User not allowed to save image in camera roll
                DispatchQueue.main.async {
                    self.shareImages(withID: imageIDs, withCameraRollAccess: false, contextually: contextually)
                }
            }
        }
    }

    @MainActor
    func shareImages(withID imageIDs: Set<Int64>, withCameraRollAccess hasCameraRollAccess: Bool, contextually: Bool) {

        // Create new activity provider items to pass to the activity view controller
        var itemsToShare: [UIActivityItemProvider] = []

        // To exclude some activity types
        var totalSize = Int64.zero
        var excludedActivityTypes = Set<UIActivity.ActivityType>()
        if !hasCameraRollAccess {
            excludedActivityTypes.insert(.saveToCameraRoll)
        }

        // Loop over images
//        timeCounter = CFAbsoluteTimeGetCurrent()
        for imageID in imageIDs {
            autoreleasepool {
                if let image = (images.fetchedObjects ?? []).first(where: {$0.pwgID == imageID}) {
                    if image.isVideo {
                        // Case of a video
                        let videoItemProvider = ShareVideoActivityItemProvider(placeholderImage: image, contextually: contextually)
                        
                        // Use delegation to monitor the progress of the item method
                        videoItemProvider.delegate = self
                        
                        // Add to list of items to share
                        itemsToShare.append(videoItemProvider)
                        
                        // Exclude some activities
                        excludedActivityTypes.insert(.assignToContact)
                        if #available(iOS 16.4, *) {
                            excludedActivityTypes.formUnion([.addToHomeScreen,
                                                             .collaborationCopyLink, .collaborationInviteWithLink])
                        }
                        totalSize += image.fileSize
                    }
                    else if image.isPDF {
                        // Case of a PDF file
                        let pdfItemProvider = SharePdfActivityItemProvider(placeholderImage: image, contextually: contextually)
                        
                        // Use delegation to monitor the progress of the item method
                        pdfItemProvider.delegate = self
                        
                        // Add to list of items to share
                        itemsToShare.append(pdfItemProvider)
                        
                        // Exclude some activities
                        excludedActivityTypes.formUnion([.assignToContact, .saveToCameraRoll,
                                                         .postToFacebook, .postToTwitter, .postToWeibo,
                                                         .postToVimeo, .postToTencentWeibo])
                        if #available(iOS 16.4, *) {
                            excludedActivityTypes.formUnion([.addToHomeScreen,
                                                             .collaborationCopyLink, .collaborationInviteWithLink])
                        }
                        totalSize += image.fileSize
                    }
                    else {
                        // Case of an image
                        let imageItemProvider = ShareImageActivityItemProvider(placeholderImage: image, contextually: contextually)
                        
                        // Use delegation to monitor the progress of the item method
                        imageItemProvider.delegate = self
                        
                        // Add to list of items to share
                        itemsToShare.append(imageItemProvider)
                        
                        // To exclude some activities
                        totalSize += image.fileSize
                    }
                }
            }
        }
//        let duration = (CFAbsoluteTimeGetCurrent() - timeCounter)*1000
//        debugPrint("••> completed in \(duration.rounded()) ms")

        // Close HUD if needed
        DispatchQueue.main.async { [self] in
            self.navigationController?.hideHUD { [self] in
                // Check that the items size is acceptable for the device
                let count = itemsToShare.count
                let deviceMemory = UIDevice.current.modelMemorySize * 1024 * 1024
                if totalSize * 5 > deviceMemory {  // i.e. 20% of available memory
                    let title = NSLocalizedString("shareFailError_title", comment: "Share Fail")
                    let message = NSLocalizedString("shareFailError_tooLarge", comment: "Selection too large to share")
                    let error = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
                    self.navigationController?.dismissPiwigoError(withTitle: title, message: message, errorMessage: error ) { }
                    return
                }
                
                // Create an activity view controller with the activity provider item.
                // ShareImageActivityItemProvider's superclass conforms to the UIActivityItemSource protocol
                let activityViewController = UIActivityViewController(activityItems: itemsToShare, applicationActivities: nil)

                // Exclude some activities if needed
                if count > 1 {
                    excludedActivityTypes.insert(.assignToContact)
                    if #available(iOS 16.4, *) {
                        excludedActivityTypes.insert(.addToHomeScreen)
                    }
                }
                if totalSize * 10 > deviceMemory {  // i.e. 10% of available memory
                    excludedActivityTypes.insert(.copyToPasteboard)
                }
                activityViewController.excludedActivityTypes = Array(excludedActivityTypes)
                
                // Delete image/video files and remove observers after dismissing activity view controller
                activityViewController.completionWithItemsHandler = { [self] activityType, completed, returnedItems, activityError in
                    //        NSLog(@"Activity Type selected: %@", activityType);
                    if completed {
                        //            NSLog(@"Selected activity was performed and returned error:%ld", (long)activityError.code);
                        // Delete shared files & remove observers
                        NotificationCenter.default.post(name: .pwgDidShare, object: nil)

                        // Deselect images if needed
                        if contextually {
                            setEnableStateOfButtons(true)
                        } else {
                            cancelSelect()
                        }

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
                            setEnableStateOfButtons(true)
                        } else {
                            // Check what to do with selection
                            if contextually {
                                setEnableStateOfButtons(true)
                            } else {
                                if selectedImageIDs.isEmpty {
                                    cancelSelect()
                                } else {
                                    setEnableStateOfButtons(true)
                                }
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
                activityViewController.view.tag = count
                if inSelectionMode, contextually == false {
                    activityViewController.popoverPresentationController?.barButtonItem = shareBarButton
                } else if let imageID = imageIDs.first,
                          let visibleCells = collectionView?.visibleCells,
                          let cell = visibleCells.first(where: { ($0 as? ImageCollectionViewCell)?.imageData.pwgID == imageID}) {
                    activityViewController.popoverPresentationController?.sourceView = cell.contentView
                }
                present(activityViewController, animated: true)
            }
        }
    }

    @objc func cancelShareImages() {
        // Cancel image file download and remaining activity shares if any
        NotificationCenter.default.post(name: .pwgCancelDownload, object: nil)
    }
}


// MARK: - ShareImageActivityItemProviderDelegate Methods
extension AlbumViewController: @preconcurrency ShareImageActivityItemProviderDelegate
{
    @MainActor
    func imageActivityItemProviderPreprocessingDidBegin(_ imageActivityItemProvider: UIActivityItemProvider?,
                                                        withTitle title: String) {
        // Show HUD to let the user know the image is being downloaded in the background.
        let total = presentedViewController?.view.tag ?? 1
        let detail = total > 1 ? String(format: "%d / %d", total - selectedImageIDs.count + 1, total) : nil
        if presentedViewController?.isShowingHUD() ?? false {
            presentedViewController?.updateHUD(title: title, detail: detail)
        } else {
            presentedViewController?.showHUD(withTitle: title, detail: detail,
                                             buttonTitle: NSLocalizedString("alertCancelButton", comment: "Cancel"),
                                             buttonTarget: self, buttonSelector: #selector(cancelShareImages),
                                             inMode: .determinate)
        }
    }
    
    @MainActor
    func imageActivityItemProvider(_ imageActivityItemProvider: UIActivityItemProvider?,
                                   preprocessingProgressDidUpdate progress: Float) {
        // Update HUD
        presentedViewController?.updateHUD(withProgress: progress)
    }
    
    func imageActivityItemProviderPreprocessingDidEnd(_ imageActivityItemProvider: UIActivityItemProvider?,
                                                      withImageID imageID: Int64, contextually: Bool) {
        // Check activity item provider
        guard let imageActivityItemProvider = imageActivityItemProvider else { return }
        
        // Close HUD
        if imageActivityItemProvider.isCancelled {
            presentedViewController?.hideHUD { }
        } else if contextually == false, selectedImageIDs.contains(imageID) {
            // Remove image from selection
            deselectImages(withIDs: Set([imageID]))
            updateBarsInSelectMode()

            // Close HUD if last image
            if selectedImageIDs.count == 0 {
                presentedViewController?.updateHUDwithSuccess { [self] in
                    self.presentedViewController?.hideHUD(afterDelay: pwgDelayHUD) { }
                }
            }
        } else if contextually {
            presentedViewController?.updateHUDwithSuccess { [self] in
                self.presentedViewController?.hideHUD(afterDelay: pwgDelayHUD) { }
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
