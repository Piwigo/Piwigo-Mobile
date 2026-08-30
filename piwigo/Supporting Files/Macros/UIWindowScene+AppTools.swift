//
//  UIWindowScene+AppTools.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 21/04/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

extension UIWindowScene {
    /// The scene the app is currently showing, used when a view is not in the window
    /// hierarchy yet and therefore cannot reach its own scene.
    @MainActor
    static var current: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
    }
    
    func rootViewController() -> UIViewController? {
        // Determine top most view controller of a UIWindowScene
        var rootViewController: UIViewController? = nil
        // Get the key window associated with the scene
        rootViewController = self
            .keyWindow?.rootViewController
        return rootViewController
    }
    
    func topMostViewController() -> UIViewController? {
        return rootViewController()?.topMostViewController()
    }
}
