//
//  UISearchBar+AppTools.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/08/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

extension UISearchBar {
    
    @MainActor
    func configAppearance() {
        barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
        searchTextField.textColor = PwgColor.leftLabel
        searchTextField.keyboardAppearance = AppVars.shared.isDarkPaletteActive ? .dark : .light
        if #available(iOS 26.0, *) {
            tintColor = PwgColor.gray
        } else {
            tintColor = PwgColor.orange
        }
    }
}
