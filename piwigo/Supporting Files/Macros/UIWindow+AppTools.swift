//
//  UIWindow+AppTools.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 20/04/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

extension UIWindow {
    
    // MARK: - Top Most View Controller
    func topMostViewController() -> UIViewController? {
        // Get the rootViewController of the associated window
        var rootViewController: UIViewController? = nil
        if #available(iOS 13, *) {
            return self.windowScene?.topMostViewController()
        }
        else {
            // Get the app's key window
            rootViewController = UIApplication.shared.keyWindow?.rootViewController
            return rootViewController?.topMostViewController()
        }
    }
}
