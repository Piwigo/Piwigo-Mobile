//
//  UIApplication+AppTools.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/03/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

extension UIApplication {
    
    // MARK: - Top Most View Controller of an App
    /// One of a few top view controllers is there ae several scenes in the foreground.
    @objc
    func appTopViewController() -> UIViewController? {
        var rootViewController: UIViewController? = nil
        
        if #available(iOS 13, *) {
            // Consider only scenes in the foreground and retain the first one
            let scene = connectedScenes.filter({$0.activationState == .foregroundActive})
                .compactMap({$0}).first
            if let windowScene = scene as? UIWindowScene {
                return windowScene.topMostViewController()
            }
        } else {
            // No scenes -> get the app key window rootViewController
            rootViewController = keyWindow?.rootViewController
            return rootViewController?.topMostViewController()
        }
        return nil
    }
}
