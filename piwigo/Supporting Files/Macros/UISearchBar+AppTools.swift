//
//  UISearchBar+AppTools.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/08/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import PwgUIKit

extension UISearchBar {
    
    @MainActor
    func configAppearance() {
        barStyle = UIVars.shared.isDarkPaletteActive ? .black : .default
        searchTextField.textColor = PwgColor.leftLabel
        searchTextField.keyboardAppearance = UIVars.shared.isDarkPaletteActive ? .dark : .light
        tintColor = PwgColor.tintColor
    }
}
