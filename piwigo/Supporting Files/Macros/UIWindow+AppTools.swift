//
//  UIWindow+AppTools.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 20/04/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

extension UIWindow {
    
    // MARK: - Top Most View Controller
    func topMostViewController() -> UIViewController? {
        return self.windowScene?.topMostViewController()
    }
}
