//
//  UIApplication+AppTools.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/03/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

extension UIApplication {
    
    // MARK: - Top Most View Controllers of an App
    /// One or several top view controllers if there are several scenes in the foreground.
    @objc
    func topViewControllers() -> [UIViewController] {
        var topViewControllers = [UIViewController]()
        
        if #available(iOS 13, *) {
            // Consider only scenes in the foreground and retain the first one
            let scene = connectedScenes.filter({$0.activationState == .foregroundActive})
                .compactMap({$0}).first
            if let windowScene = scene as? UIWindowScene,
               let topViewController = windowScene.topMostViewController() {
                topViewControllers.append(topViewController)
            }
        } else {
            // No scenes -> get the app key window rootViewController
            let rootViewController = keyWindow?.rootViewController
            if let topViewController = rootViewController?.topMostViewController() {
                topViewControllers.append(topViewController)
            }
        }
        return topViewControllers
    }
}
