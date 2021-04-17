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
                       buttonTitle:String = "", buttonSelector:Selector? = nil,
                       inMode mode:MBProgressHUDMode = .indeterminate) {
        DispatchQueue.main.async {
            // Create the login HUD if needed
            var hud = self.view.viewWithTag(loadingViewTag) as? MBProgressHUD
            if hud == nil {
                // Create the HUD
                hud = MBProgressHUD.showAdded(to: self.view, animated: true)
                hud?.tag = loadingViewTag

                // Change the background view shape, style and color.
                hud?.mode = mode
                hud?.isSquare = false
                hud?.animationType = MBProgressHUDAnimation.fade
                hud?.backgroundView.style = MBProgressHUDBackgroundStyle.solidColor
                hud?.backgroundView.color = UIColor(white: 0.0, alpha: 0.5)
                hud?.contentColor = UIColor.piwigoColorText()
                hud?.bezelView.color = UIColor.piwigoColorText()
                hud?.bezelView.style = MBProgressHUDBackgroundStyle.solidColor
                hud?.bezelView.backgroundColor = UIColor.piwigoColorCellBackground()

                // Will look best, if we set a minimum size.
                hud?.minSize = CGSize(width: 200.0, height: 100.0)
            }

            // Set title if needed
            if title.count > 0 {
                hud?.label.text = title
                hud?.label.font = UIFont.piwigoFontNormal()
            }
            
            // Set details label if needed
            if detail.count > 0 {
                hud?.detailsLabel.text = detail
                hud?.detailsLabel.font = UIFont.piwigoFontSmall()
            }
            
            // Set button if needed
            if buttonTitle.count > 0, let selector = buttonSelector {
                hud?.button.setTitle(buttonTitle, for: .normal)
                hud?.button.addTarget(self, action: selector, for: .touchUpInside)
            }
        }
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
                let image = UIImage(named: "completed")?.withRenderingMode(.alwaysTemplate)
                let imageView = UIImageView(image: image)
                hud.customView = imageView
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

    
    // MARK: - Dismiss Alert View
    func dismissPiwigoError(withTitle title:String, message:String = "", errorMessage:String = "",
                            completion: @escaping () -> Void) {
        // Prepare message
        var wholeMessage = message
        if errorMessage.count > 0 {
            wholeMessage.append("\n(" + errorMessage + ")")
        }
        
        // Present alert
        let alert = UIAlertController.init(title: title, message: wholeMessage, preferredStyle: .alert)
        let dismissAction = UIAlertAction.init(title: NSLocalizedString("alertDismissButton", comment:"Dismiss"),
                                               style: .cancel) { _ in completion() }
        alert.addAction(dismissAction)
        alert.view.tintColor = UIColor.piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange()
        }
    }

    func cancelRetryPiwigoError(withTitle title:String, message:String = "", errorMessage:String = "",
                                cancel: @escaping () -> Void, retry: @escaping () -> Void) {
        // Prepare message
        var wholeMessage = message
        if errorMessage.count > 0 {
            wholeMessage.append("\n(" + errorMessage + ")")
        }
        
        // Present alert
        let alert = UIAlertController.init(title: title, message: wholeMessage, preferredStyle: .alert)
        let dismissAction = UIAlertAction.init(title: NSLocalizedString("alertDismissButton", comment:"Dismiss"),
                                               style: .cancel) { _ in cancel() }
        let retryAction = UIAlertAction.init(title: NSLocalizedString("alertRetryButton", comment:"Retry"),
                                               style: .cancel) { _ in retry() }
        alert.addAction(dismissAction)
        alert.addAction(retryAction)
        alert.view.tintColor = UIColor.piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange()
        }
    }
}
