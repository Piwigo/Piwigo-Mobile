//
//  UIViewController+AppTools.swift
//  piwig
//
//  Created by Eddy Lelièvre-Berna on 13/04/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import UIKit

let kDelayPiwigoHUD = 500
let loadingViewTag = 899

extension UIViewController {

    // MARK: - Top Most View Controller
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

    
    // MARK: - PiwigoHUD
    func showHUD(withTitle title: String, detail: String? = nil, minWidth: CGFloat = 200,
                 buttonTitle: String? = nil, buttonTarget: UIViewController? = nil, buttonSelector: Selector? = nil,
                 inMode mode: pwgHudMode = .indeterminate) {
        DispatchQueue.main.async {
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
    }
    
    func isShowingHUD() -> Bool {
        if let _ = self.view.viewWithTag(pwgTagHUD) as? PiwigoHUD {
            return true
        }
        return false
    }
    
    func updateHUD(title: String? = nil, detail: String? = nil,
                   buttonTitle: String? = nil, buttonTarget: UIViewController? = nil, buttonSelector: Selector? = nil,
                   inMode mode: pwgHudMode? = nil) {
        DispatchQueue.main.async {
            // Retrieve the existing HUD
            if let hud = self.view.viewWithTag(pwgTagHUD) as? PiwigoHUD {
                hud.update(title: title, detail: detail,
                           buttonTitle: buttonTitle, buttonTarget: buttonTarget, buttonSelector: buttonSelector,
                           inMode: mode)
            }
        }
    }
    
    func updateHUD(withProgress progress: Float) {
        DispatchQueue.main.async {
            if let hud = self.view.viewWithTag(pwgTagHUD) as? PiwigoHUD {
                hud.progressView.progress = progress
            }
        }
    }

    func updateHUDwithSuccess(completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            // Retrieve the existing HUD
            if let hud = self.view.viewWithTag(pwgTagHUD) as? PiwigoHUD {
                // Show "Complete" icon and text
                hud.update(title: NSLocalizedString("completeHUD_label", comment: "Complete"),
                           detail: nil, inMode: .success)
            }
            completion()
        }
    }

    func hideHUD(afterDelay delay:Int, completion: @escaping () -> Void) {
        let deadlineTime = DispatchTime.now() + .milliseconds(delay)
        DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
            // Hide and remove the HUD
            self.hideHUD(completion: { completion() })
        }
    }

    func hideHUD(completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            // Hide and remove the HUD
            if let hud = self.view.viewWithTag(pwgTagHUD) as? PiwigoHUD {
                hud.hide()
                completion()
            }
        }
    }

    
    // MARK: - Dismiss Alert Views
    func dismissPiwigoError(withTitle title:String, message:String = "", errorMessage:String = "",
                            completion: @escaping () -> Void) {
        // Prepare message
        var wholeMessage = message
        if errorMessage.count > 0 {
            wholeMessage.append("\n(" + errorMessage + ")")
        }
        
        // Prepare actions
        let dismissAction = UIAlertAction(title: NSLocalizedString("alertDismissButton", comment:"Dismiss"),
                                          style: .cancel) { _ in completion() }

        // Present alert
        self.presentPiwigoAlert(withTitle: title, message: wholeMessage,
                                actions: [dismissAction])
    }

    func cancelDismissPiwigoError(withTitle title:String, message:String = "", errorMessage:String = "",
                                  cancel: @escaping () -> Void, dismiss: @escaping () -> Void) {
        // Prepare message
        var wholeMessage = message
        if errorMessage.count > 0 {
            wholeMessage.append("\n(" + errorMessage + ")")
        }
        
        // Prepare actions
        let cancelAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment:"Cancel"),
                                         style: .cancel) { _ in cancel() }
        let dismissAction = UIAlertAction(title: NSLocalizedString("alertDismissButton", comment:"Dismiss"),
                                          style: .default) { _ in dismiss() }

        // Present alert
        self.presentPiwigoAlert(withTitle: title, message: wholeMessage,
                                actions: [cancelAction, dismissAction])
    }

    func dismissRetryPiwigoError(withTitle title:String, message:String = "", errorMessage:String = "",
                                 dismiss: @escaping () -> Void, retry: @escaping () -> Void) {
        // Prepare message
        var wholeMessage = message
        if errorMessage.count > 0 {
            wholeMessage.append("\n(" + errorMessage + ")")
        }
        
        // Prepare actions
        let dismissAction = UIAlertAction(title: NSLocalizedString("alertDismissButton", comment:"Dismiss"),
                                          style: .cancel) { _ in dismiss() }
        let retryAction = UIAlertAction(title: NSLocalizedString("alertRetryButton", comment:"Retry"),
                                        style: .default) { _ in retry() }

        // Present alert
        self.presentPiwigoAlert(withTitle: title, message: wholeMessage,
                                actions: [dismissAction, retryAction])
    }

    func cancelDismissRetryPiwigoError(withTitle title:String, message:String = "", errorMessage:String = "",
                        cancel: @escaping () -> Void, dismiss: @escaping () -> Void, retry: @escaping () -> Void) {
        // Prepare message
        var wholeMessage = message
        if errorMessage.count > 0 {
            wholeMessage.append("\n(" + errorMessage + ")")
        }
        
        // Prepare actions
        let cancelAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment:"Cancel"),
                                         style: .cancel) { _ in cancel() }
        let dismissAction = UIAlertAction(title: NSLocalizedString("alertDismissButton", comment:"Dismiss"),
                                          style: .default) { _ in dismiss() }
        let retryAction = UIAlertAction(title: NSLocalizedString("alertRetryButton", comment:"Retry"),
                                        style: .default) { _ in retry() }

        // Present alert
        self.presentPiwigoAlert(withTitle: title, message: wholeMessage,
                                actions: [cancelAction, dismissAction, retryAction])
    }

    func presentPiwigoAlert(withTitle title:String, message:String, actions:[UIAlertAction]) {
        DispatchQueue.main.async {
            // Create alert view controller
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

            // Add actions
            for action in actions {
                alert.addAction(action)
            }
            
            // Present alert
            alert.view.tintColor = .piwigoColorOrange()
            if #available(iOS 13.0, *) {
                alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
            } else {
                // Fallback on earlier versions
            }
            self.present(alert, animated: true) {
                // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                alert.view.tintColor = .piwigoColorOrange()
            }
        }
    }
}
