//
//  UIToolbar+AppTools.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/08/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

extension UIToolbar {
    
    @MainActor
    func configAppearance() {
        // Style
        barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
        
        // Buttons
        tintColor = PwgColor.tintColor
        
        // Bar
        if #available(iOS 26.0, *) {
            barTintColor = .clear
        } else {
            barTintColor = PwgColor.background
        }
    }
}
