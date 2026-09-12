//
//  UIViewController+AppTools.swift
//  piwig
//
//  Created by Eddy Lelièvre-Berna on 13/04/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import UIKit
import PwgUIKit

let kDelayPiwigoHUD = 500
let loadingViewTag = 899

extension UIViewController {

    // MARK: - View Controllers
    func topMostViewController() -> UIViewController? {
        // Look for the top most UIViewController
        var topViewController: UIViewController? = self
        while true {
            if let presented = topViewController?.presentedViewController {
                topViewController = presented
            } else if let navController = topViewController as? UINavigationController {
                topViewController = navController.topViewController
            } else if let tabBarController = topViewController as? UITabBarController {
                topViewController = tabBarController.selectedViewController
            } else {
                // Handle any other third party container in `else if` if required
                break
            }
        }
        return topViewController
    }
    
    func dismissToAlbumNavigationController(completion: (() -> Void)? = nil) {
        // Walk up the presenting chain to find the AlbumViewController
        var presenter: UIViewController? = self
        while let current = presenter {
            if current is AlbumNavigationController {
                // Dismiss everything above it
                current.presentedViewController?.dismiss(animated: false, completion: completion)
                return
            }
            presenter = current.presentingViewController
        }
        // No AlbumViewController found
        completion?()
    }
    
    
    // MARK: - Push Views
    @MainActor
    func pushView(_ viewController: UIViewController?, forButton button: UIBarButtonItem?) {
        guard let viewController = viewController
        else { return }
        
        // Help and release notes views present their own close button
        let isSelfContained = (viewController is HelpViewController) ||
                              (viewController is ReleaseNotesViewController)
        let presentedVC = isSelfContained ? viewController
                                          : UINavigationController(rootViewController: viewController)
        presentedVC.modalTransitionStyle = .coverVertical
        
        // Push album list, tag list, help view, etc.
        switch view.traitCollection.userInterfaceIdiom {
        case .phone:
            presentedVC.modalPresentationStyle = .popover
            presentedVC.popoverPresentationController?.sourceView = view
            
        case .pad:
            if #available(iOS 26.0, *) {
                // Present the view in a form sheet of the wanted size
                presentedVC.modalPresentationStyle = .formSheet
                let windowBounds = view.window?.bounds ?? .zero
                presentedVC.popoverPresentationController?.sourceRect = CGRect(
                    x: windowBounds.midX, y: windowBounds.midY,
                    width: 0, height: 0)
                presentedVC.preferredContentSize = CGSize(
                    width: pwgPadSettingsWidth,
                    height: ceil(windowBounds.height * 2 / 3))
            } else {
                // Present the view in a popover anchored to the button
                presentedVC.modalPresentationStyle = .popover
                presentedVC.popoverPresentationController?.barButtonItem = button
                presentedVC.popoverPresentationController?.permittedArrowDirections = .up
            }
            
        default:
            preconditionFailure("!!! Interface not supported !!!")
        }
        present(presentedVC, animated: true)
    }
    
    
    // MARK: - PiwigoHUD
    @MainActor
    func showHUD(withTitle title: String, detail: String? = nil, minWidth: CGFloat = 200,
                 buttonTitle: String? = nil, buttonTarget: UIViewController? = nil, buttonSelector: Selector? = nil,
                 inMode mode: pwgHudMode = .indeterminate) {
        // Remove an existing HUD if needed
        if let hud = self.view.viewWithTag(pwgTagHUD) as? PiwigoHUD {
            hud.removeFromSuperview()
        }
        // Create the HUD
        guard let hud = UINib(nibName: "PiwigoHUD", bundle: nil).instantiate(withOwner: nil)[0] as? PiwigoHUD
        else { preconditionFailure("PiwigoHUD not found/instantiated") }
        hud.show(withTitle: title, detail: detail, minWidth: minWidth,
                 buttonTitle: buttonTitle, buttonTarget: buttonTarget, buttonSelector: buttonSelector,
                 inMode: mode, view: self.view)
    }
    
    @MainActor
    func isShowingHUD() -> Bool {
        if let _ = self.view.viewWithTag(pwgTagHUD) as? PiwigoHUD {
            return true
        }
        return false
    }
    
    @MainActor
    func updateHUD(title: String? = nil, detail: String? = nil,
                   buttonTitle: String? = nil, buttonTarget: UIViewController? = nil, buttonSelector: Selector? = nil,
                   inMode mode: pwgHudMode? = nil) {
        // Retrieve the existing HUD
        if let hud = self.view.viewWithTag(pwgTagHUD) as? PiwigoHUD {
            hud.update(title: title, detail: detail,
                       buttonTitle: buttonTitle, buttonTarget: buttonTarget, buttonSelector: buttonSelector,
                       inMode: mode)
        }
    }
    
    @MainActor
    func updateHUD(withProgress progress: Float) {
        if let hud = self.view.viewWithTag(pwgTagHUD) as? PiwigoHUD {
            hud.progressView.progress = progress
        }
    }

    @MainActor
    func updateHUDwithSuccess(completion: @escaping () -> Void) {
        // Retrieve the existing HUD
        if let hud = self.view.viewWithTag(pwgTagHUD) as? PiwigoHUD {
            // Show "Complete" icon and text
            hud.update(title: String(localized: "completeHUD_label", comment: "Complete"),
                       detail: nil, inMode: .success)
        }
        completion()
    }

    @MainActor
    func hideHUD(afterDelay delay:Int, completion: @escaping () -> Void) {
        let deadlineTime = DispatchTime.now() + .milliseconds(delay)
        DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
            // Hide and remove the HUD
            self.hideHUD(completion: { completion() })
        }
    }

    @available(*, renamed: "hideHUD()")
    @MainActor
    func hideHUD(completion: @escaping () -> Void) {
        Task {
            await hideHUD()
            completion()
        }
    }
    
    @MainActor
    func hideHUD() async {
        // Hide and remove the HUD
        if let hud = self.view.viewWithTag(pwgTagHUD) as? PiwigoHUD {
            hud.hide()
        }
    }

    
    // MARK: - Dismiss Alert Views
    @MainActor
    func dismissPiwigoError(withTitle title:String, message:String = "", errorMessage:String = "",
                            completion: @escaping () -> Void) {
        // Prepare message
        var wholeMessage = message
        if errorMessage.count > 0 {
            wholeMessage.append("\n(" + errorMessage + ")")
        }
        
        // Prepare actions
        let dismissAction = UIAlertAction(title: Localized.dismiss,
                                          style: .cancel) { _ in completion() }

        // Present alert
        self.presentPiwigoAlert(withTitle: title, message: wholeMessage,
                                actions: [dismissAction])
    }

    @available(*, renamed: "cancelDismissPiwigoError(withTitle:message:errorMessage:cancel:)")
    @MainActor
    func cancelDismissPiwigoError(withTitle title:String, message:String = "", errorMessage:String = "",
                                  cancel: @escaping () -> Void, dismiss: @escaping () -> Void) {
        Task {
            await cancelDismissPiwigoError(withTitle: title, message: message, errorMessage: errorMessage, cancel: cancel)
            dismiss()
        }
    }
    
    @MainActor
    func cancelDismissPiwigoError(withTitle title:String, message:String = "", errorMessage:String = "",
                                  cancel: @escaping () -> Void) async {
        // Prepare message
        var wholeMessage = message
        if errorMessage.count > 0 {
            wholeMessage.append("\n(" + errorMessage + ")")
        }
        
        // Prepare actions
        let cancelAction = UIAlertAction(title: Localized.cancel,
                                         style: .cancel) { _ in cancel() }
        return await withCheckedContinuation { continuation in
            let dismissAction = UIAlertAction(title: Localized.dismiss,
                                              style: .default) { _ in continuation.resume(returning: ()) }
            
            // Present alert
            self.presentPiwigoAlert(withTitle: title, message: wholeMessage,
                                    actions: [cancelAction, dismissAction])
        }
    }

    @MainActor
    func dismissRetryPiwigoError(withTitle title:String, message:String = "", errorMessage:String = "",
                                 dismiss: @escaping () -> Void, retry: @escaping () -> Void) {
        // Prepare message
        var wholeMessage = message
        if errorMessage.count > 0 {
            wholeMessage.append("\n(" + errorMessage + ")")
        }
        
        // Prepare actions
        let dismissAction = UIAlertAction(title: Localized.dismiss,
                                          style: .cancel) { _ in dismiss() }
        let retryAction = UIAlertAction(title: String(localized: "alertRetryButton", comment:"Retry"),
                                        style: .default) { _ in retry() }

        // Present alert
        self.presentPiwigoAlert(withTitle: title, message: wholeMessage,
                                actions: [dismissAction, retryAction])
    }

    @MainActor
    func cancelDismissRetryPiwigoError(withTitle title:String, message:String = "", errorMessage:String = "",
                        cancel: @escaping () -> Void, dismiss: @escaping () -> Void, retry: @escaping () -> Void) {
        // Prepare message
        var wholeMessage = message
        if errorMessage.count > 0 {
            wholeMessage.append("\n(" + errorMessage + ")")
        }
        
        // Prepare actions
        let cancelAction = UIAlertAction(title: Localized.cancel,
                                         style: .cancel) { _ in cancel() }
        let dismissAction = UIAlertAction(title: Localized.dismiss,
                                          style: .default) { _ in dismiss() }
        let retryAction = UIAlertAction(title: String(localized: "alertRetryButton", comment:"Retry"),
                                        style: .default) { _ in retry() }

        // Present alert
        self.presentPiwigoAlert(withTitle: title, message: wholeMessage,
                                actions: [cancelAction, dismissAction, retryAction])
    }

    @MainActor
    func presentPiwigoAlert(withTitle title: String, message: String, actions: [UIAlertAction]) {
        // Create alert view controller
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        // Add actions
        for action in actions {
            alert.addAction(action)
        }
        
        // Present alert
        alert.view.tintColor = PwgColor.tintColor
        alert.overrideUserInterfaceStyle = UIVars.shared.isDarkPaletteActive ? .dark : .light
        self.present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = PwgColor.tintColor
        }
    }
}
