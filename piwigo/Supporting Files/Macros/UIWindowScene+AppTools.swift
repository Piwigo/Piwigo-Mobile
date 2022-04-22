//
//  UIWindowScene+AppTools.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 21/04/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

@available(iOS 13.0, *)
extension UIWindowScene {
    func topMostViewController() -> UIViewController? {
        // Determine top most view controller of a UIWindowScene
        var rootViewController: UIViewController? = nil
        // Determine top most view controller of a UIWindowScene
        if #available(iOS 15, *) {
            // Get the key window associated with the scene
            rootViewController = self
                .keyWindow?.rootViewController
        }
        else {
            // Get the key window associated with the scene
            rootViewController = self
                .windows.first(where: {$0.isKeyWindow})?.rootViewController
        }
        return rootViewController?.topMostViewController()
    }
}
