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
