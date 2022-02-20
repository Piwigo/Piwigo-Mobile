//
//  UIViewController+AppTools.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 13/04/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import UIKit

@objc
extension UIViewController {

    // MARK: - MBProgressHUD
    func showPiwigoHUD(withTitle title:String = "", detail:String = "",
                       buttonTitle:String = "", buttonTarget:UIViewController? = nil, buttonSelector:Selector? = nil,
                       inMode mode:MBProgressHUDMode = .indeterminate) {
        DispatchQueue.main.async {
            // Create the login HUD if needed
            var hud = self.view.viewWithTag(loadingViewTag) as? MBProgressHUD
            if hud == nil {
                // Create the HUD
                hud = MBProgressHUD.showAdded(to: self.view, animated: true)
                hud?.tag = loadingViewTag

                // Change the background view shape, style and color.
                hud?.isSquare = false
                hud?.animationType = MBProgressHUDAnimation.fade
                hud?.backgroundView.style = MBProgressHUDBackgroundStyle.solidColor
                hud?.backgroundView.color = UIColor(white: 0.0, alpha: 0.5)
                hud?.contentColor = .piwigoColorText()
                hud?.bezelView.color = .piwigoColorText()
                hud?.bezelView.style = MBProgressHUDBackgroundStyle.solidColor
                hud?.bezelView.backgroundColor = .piwigoColorCellBackground()

                // Will look best, if we set a minimum size.
                hud?.minSize = CGSize(width: 200.0, height: 100.0)
            }
            
            // Change mode
            hud?.mode = mode

            // Set title if needed
            if title.count > 0 {
                hud?.label.text = title
                hud?.label.font = .piwigoFontNormal()
            }
            
            // Set details label if needed
            if detail.count > 0 {
                hud?.detailsLabel.text = detail
                hud?.detailsLabel.font = .piwigoFontSmall()
            }
            
            // Set button if needed
            if buttonTitle.count > 0, let target = buttonTarget, let selector = buttonSelector {
                hud?.button.setTitle(buttonTitle, for: .normal)
                hud?.button.addTarget(target, action:selector, for: .touchUpInside)
            }
        }
    }
    
    func isShowingPiwigoHUD() -> Bool {
        if let _ = self.view.viewWithTag(loadingViewTag) as? MBProgressHUD {
            return true
        }
        return false
    }
    
    func updatePiwigoHUD(withProgress progress:Float) {
        DispatchQueue.main.async {
            let hud = self.view.viewWithTag(loadingViewTag) as? MBProgressHUD
            hud?.progress = progress
        }
    }

    func updatePiwigoHUDwithSuccess(completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            // Show "Completed" icon
            if let hud = self.view.viewWithTag(loadingViewTag) as? MBProgressHUD {
                if #available(iOS 11, *) {
                    // An iPod on iOS 9.3 enters an infinite loop when creating imageView
                    let image = UIImage(named: "completed")?.withRenderingMode(.alwaysTemplate)
                    let imageView = UIImageView(image: image)
                    hud.customView = imageView
                }
                hud.mode = MBProgressHUDMode.customView
                hud.label.text = NSLocalizedString("completeHUD_label", comment: "Complete")
            }
            completion()
        }
    }

    func hidePiwigoHUD(afterDelay delay:Int, completion: @escaping () -> Void) {
        let deadlineTime = DispatchTime.now() + .milliseconds(delay)
        DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
            // Hide and remove the HUD
            self.hidePiwigoHUD(completion: { completion() })
        }
    }

    func hidePiwigoHUD(completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            // Hide and remove the HUD
            let hud = self.view.viewWithTag(loadingViewTag) as? MBProgressHUD
            hud?.hide(animated: true)
            completion()
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
