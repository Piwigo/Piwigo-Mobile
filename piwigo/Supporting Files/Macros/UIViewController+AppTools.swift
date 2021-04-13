//
//  ProgressHUD.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 13/04/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import UIKit

@objc
extension UIViewController {

    // MARK: - MBProgressHUD
    func showHUD(withTitle title:String?, andMode mode:MBProgressHUDMode) {
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

        // Set title
        hud?.label.text = title
        hud?.label.font = UIFont.piwigoFontNormal()
    }
    
    func updateHUD(withProgress progress:Float) {
        DispatchQueue.main.async {
            let hud = self.view.viewWithTag(loadingViewTag) as? MBProgressHUD
            hud?.progress = progress
        }
    }

    func hideHUDwithSuccess(_ success:Bool, completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            // Show "Completed" icon
            let hud = self.view.viewWithTag(loadingViewTag) as? MBProgressHUD
            if hud != nil {
                if success {
                    let image = UIImage(named: "completed")?.withRenderingMode(.alwaysTemplate)
                    let imageView = UIImageView(image: image)
                    hud?.customView = imageView
                    hud?.mode = MBProgressHUDMode.customView
                    hud?.label.text = NSLocalizedString("completeHUD_label", comment: "Complete")
                }
            }
            completion()
        }
    }

    func hideHUD(completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            // Hide and remove the HUD
            let hud = self.view.viewWithTag(loadingViewTag) as? MBProgressHUD
            if hud != nil {
                hud?.hide(animated: true)
            }
            completion()
        }
    }

    
    // MARK: - Dismiss Alert View
    func dismissPiwigoError(withTitle title:String, message:String = "",
                            completion: @escaping () -> Void) {
        // Present alert
        let alert = UIAlertController.init(title: title, message: message, preferredStyle: .alert)
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
}
