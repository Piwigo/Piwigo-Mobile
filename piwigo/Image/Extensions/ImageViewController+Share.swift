//
//  ImageViewController+Share.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import PwgKit
import PwgUIKit

extension ImageViewController
{
    // MARK: - Share Image
    func getShareImageButton() -> UIBarButtonItem? {
        // Since Piwigo 14, pwg.categories.getImages method returns download_url if the user has download rights
        // For previous versions, we assume that all only registered users have download rights
        if userData.canDownloadImages() {
            return UIBarButtonItem.shareImageButton(self, action: #selector(ImageViewController.shareImage))
        } else {
            return nil
        }
    }
    
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
    }

    @MainActor
    func presentShareImageViewController(withCameraRollAccess hasCameraRollAccess: Bool) {
        // Check input image data
        guard let imageData = imageData else { return }

        // PDF, EPS and GIF files are shared as they are: no option can change anything.
        let sections = ShareUtilities.optionsToPropose(for: [imageData])
        guard sections.metadata else {
            presentActivityViewController(with: ShareOptions.lastUsed,
                                          withCameraRollAccess: hasCameraRollAccess)
            return
        }

        // Let the user choose what will be shared before presenting the share sheet.
        /// The choice cannot be proposed afterwards: the type and the size of the item
        /// decide which activities the share sheet proposes and what they receive.
        guard let optionsVC = UIStoryboard(name: "ShareOptionsViewController", bundle: nil)
            .instantiateViewController(withIdentifier: "ShareOptionsViewController") as? ShareOptionsViewController
        else { return }

        optionsVC.images = [imageData]
        optionsVC.completion = { [weak self] options in
            guard let options = options else {
                // The user gave up: enable the buttons again
                self?.setEnableStateOfButtons(true)
                return
            }
            self?.presentActivityViewController(with: options,
                                                withCameraRollAccess: hasCameraRollAccess)
        }

        let navController = UINavigationController(rootViewController: optionsVC)
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(navController, animated: true)
    }

    @MainActor
    func presentActivityViewController(with options: ShareOptions,
                                       withCameraRollAccess hasCameraRollAccess: Bool) {
        // To exclude some activity types
        var excludedActivityTypes = Set<UIActivity.ActivityType>()

        // Check input image data
        guard let imageData = imageData else { return }

        // Create new activity provider item to pass to the activity view controller
        let scale = CGFloat(fmax(1.0, self.view.traitCollection.displayScale))
        var itemsToShare: [AnyHashable] = []
        if imageData.isVideo {
            // Case of a video
            let videoItemProvider = ShareVideoActivityItemProvider(imageData: imageData, scale: scale, options: options, contextually: false)

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
            let pdfItemProvider = SharePdfActivityItemProvider(imageData: imageData, scale: scale, contextually: false)

            // Use delegation to monitor the progress of the item method
            pdfItemProvider.delegate = self

            // Add to list of items to share
            itemsToShare.append(pdfItemProvider)

            // Exclude "assign to contact" activity
            excludedActivityTypes.formUnion([.assignToContact, .saveToCameraRoll])
            if #available(iOS 16.4, *) {
                excludedActivityTypes.formUnion([.addToHomeScreen,
                                                 .collaborationCopyLink, .collaborationInviteWithLink])
            }
        }
        else {
            // Case of an image
            let imageItemProvider = ShareImageActivityItemProvider(imageData: imageData, scale: scale, options: options, contextually: false)

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
            ShareUtilities.setClipboardExpiration(forActivityType: activityType)

            // Enable buttons after action
            setEnableStateOfButtons(true)

            // Remove observers
            NotificationCenter.default.post(name: .pwgDidShare, object: nil)

            if !completed {
                if activityType == nil {
                    #if DEBUG
                    debugPrint("User dismissed the view controller without making a selection.");
                    #endif
                } else {
                    #if DEBUG
                    debugPrint("Activity was not performed.")
                    #endif
                    // Cancel download task
                    NotificationCenter.default.post(name: .pwgCancelDownload, object: nil)
                }
            } else {
                // Update server statistics
                logImageVisitIfNeeded(imageData.pwgID, asDownload: true)
            }
        }

        // Present share image activity view controller
        activityViewController.popoverPresentationController?.barButtonItem = shareImageButton
        present(activityViewController, animated: true)
    }

    @objc func cancelShareImage() {
        // Cancel file donwload
        NotificationCenter.default.post(name: .pwgCancelDownload, object: nil)
    }
    
    
    // MARK: - Share Image Page URL
    /// Menu action sharing the URL of the page presenting the image.
    /// Requires no download rights: the page redirects the recipient to a login page
    /// when access needs to be granted.
    @MainActor
    func shareLinkAction() -> UIAction {
        let action = UIAction(title: String(localized: "imageOptions_shareLink", comment: "Share Link"),
                              image: UIImage(systemName: "link"),
                              handler: { [weak self] _ in
            guard let self else { return }
            // Present the share sheet anchored to the action button
            self.shareImageLink(from: self.actionBarButton)
        })
        action.accessibilityIdentifier = "org.piwigo.image.shareLink"
        return action
    }
    
    /**
     Presents the share sheet with the URL of the image page on the Piwigo server,
     so that the user can send it with Mail, Messages, AirDrop, copy it, etc.

     Unlike sharing the image file, this neither downloads anything nor requires
     download rights: the shared page redirects the recipient to a login page when
     access needs to be granted.

     - Parameter barButton: the bar button the share sheet is anchored to on iPad.
     */
    @MainActor
    func shareImageLink(from barButton: UIBarButtonItem? = nil) {
        // Check that the page URL of the current image is known.
        guard let imageData = imageData,
              let pageUrl = imageData.pageUrl as? URL
        else { return }

        // Disable buttons during action
        setEnableStateOfButtons(false)

        // Name of the image, used as the subject by Mail and other activities.
        let subject = imageData.titleStr.isEmpty ? imageData.fileName : imageData.titleStr

        // A single URL item is provided, so the share sheet proposes the activities
        // which accept a link and nothing has to be excluded.
        let itemSource = ImageLinkActivityItemSource(pageUrl: pageUrl, subject: subject)
        let activityViewController = UIActivityViewController(activityItems: [itemSource],
                                                              applicationActivities: nil)

        activityViewController.completionWithItemsHandler = { [self] activityType, _, _, _ in
            // Honour the user's "clear clipboard" delay when the link was copied
            ShareUtilities.setClipboardExpiration(forActivityType: activityType)

            // Enable buttons after action
            setEnableStateOfButtons(true)
        }

        // Present the share sheet
        activityViewController.popoverPresentationController?.barButtonItem = barButton ?? actionBarButton
        present(activityViewController, animated: true)
    }
}


// MARK: - ShareImageActivityItemProviderDelegate Methods
extension ImageViewController: @preconcurrency ShareImageActivityItemProviderDelegate
{
    @MainActor
    func imageActivityItemProviderPreprocessingDidBegin(_ imageActivityItemProvider: UIActivityItemProvider?, withTitle title: String) {
        // Show HUD to let the user know the image is being downloaded in the background.
        presentedViewController?.showHUD(withTitle: title, buttonTitle: Localized.cancel, buttonTarget: self,
                                         buttonSelector: #selector(cancelShareImage), inMode: .determinate)
    }

    @MainActor
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


// MARK: - Image Page URL Activity Item Source
/**
 Shares the URL of an image page on the Piwigo server and provides the name of that
 image as the subject, which activities such as Mail use to pre-fill their subject field.

 A plain UIActivityItemSource is used instead of the UIActivityItemProvider subclasses
 of the other share paths: there is nothing to download or convert in the background,
 the URL is already at hand.
 */
final class ImageLinkActivityItemSource: NSObject, UIActivityItemSource {

    private let pageUrl: URL
    private let subject: String

    init(pageUrl: URL, subject: String) {
        self.pageUrl = pageUrl
        self.subject = subject
        super.init()
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        // Returning a URL is what makes the share sheet propose the activities accepting a link
        return pageUrl
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return pageUrl
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return subject
    }
}
