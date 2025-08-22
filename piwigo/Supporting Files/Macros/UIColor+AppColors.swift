//
//  UIColor+AppColors.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 23/02/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit

enum PwgColor {
    
    // MARK: - Text Color
    static let text = UIColor { _ in
        AppVars.shared.isDarkPaletteActive
        ? UIColor.lightText
        : UIColor.darkText
    }
    
    
    // MARK: - Background Color of Views
    static let background = UIColor { _ in
        AppVars.shared.isDarkPaletteActive
        ? UIColor(red: 23 / 255.0, green: 23 / 255.0, blue: 23 / 255.0, alpha: 1.0)
        : UIColor(red: 239 / 255.0, green: 239 / 255.0, blue: 244 / 255.0, alpha: 1.0)
    }
    
    
    // MARK: - Shadow Color of Buttons
    static let shadow = UIColor { _ in
        AppVars.shared.isDarkPaletteActive
        ? UIColor.white
        : UIColor.black
    }
    
    
    // MARK: - Piwigo Logo Colors
    static let brown = UIColor { _ in
        return UIColor(red: 60 / 255.0, green: 60 / 255.0, blue: 60 / 255.0, alpha: 1.0)
    }
    
    static let orange = UIColor { _ in
        return UIColor(red: 255 / 255.0, green: 119 / 255.0, blue: 1 / 255.0, alpha: 1.0)
    }
    
    static let orangeLight = UIColor { _ in
        return UIColor(red: 251 / 255.0, green: 97 / 255.0, blue: 11 / 255.0, alpha: 1.0)
    }
    
    static let orangeSelected = UIColor { _ in
        return UIColor(red: 198 / 255.0, green: 92 / 255.0, blue: 0 / 255.0, alpha: 1.0)
    }
    
    
    // MARK: - Colors for Table Views
    static let header = UIColor { _ in
        if #available(iOS 26.0, *) {
            AppVars.shared.isDarkPaletteActive
            ? UIColor(red: 141 / 255.0, green: 141 / 255.0, blue: 147 / 255.0, alpha: 1.0)
            : UIColor(red: 133 / 255.0, green: 133 / 255.0, blue: 139 / 255.0, alpha: 1.0)
        } else {
            AppVars.shared.isDarkPaletteActive
            ? UIColor(red: 200 / 255.0, green: 200 / 255.0, blue: 200 / 255.0, alpha: 1.0)
            : UIColor(red: 28 / 255.0, green: 28 / 255.0, blue: 30 / 255.0, alpha: 1.0)
        }
    }
    
    static let separator = UIColor { _ in
        if #available(iOS 26.0, *) {
            AppVars.shared.isDarkPaletteActive
            ? UIColor(red: 56 / 255.0, green: 56 / 255.0, blue: 59 / 255.0, alpha: 1.0)
            : UIColor(red: 232 / 255.0, green: 232 / 255.0, blue: 232 / 255.0, alpha: 1.0)
        } else {
            AppVars.shared.isDarkPaletteActive
            ? UIColor(red: 62 / 255.0, green: 62 / 255.0, blue: 65 / 255.0, alpha: 1.0)
            : UIColor(red: 198 / 255.0, green: 197 / 255.0, blue: 202 / 255.0, alpha: 1.0)
        }
    }
    
    static let cellBackground  = UIColor { _ in
        if #available(iOS 26.0, *) {
            AppVars.shared.isDarkPaletteActive
            ? UIColor(red: 28 / 255.0, green: 28 / 255.0, blue: 30 / 255.0, alpha: 1.0)
            : UIColor(red: 255 / 255.0, green: 255 / 255.0, blue: 255 / 255.0, alpha: 1.0)
        } else {
            AppVars.shared.isDarkPaletteActive
            ? UIColor(red: 42 / 255.0, green: 42 / 255.0, blue: 45 / 255.0, alpha: 1.0)
            : UIColor(red: 255 / 255.0, green: 255 / 255.0, blue: 255 / 255.0, alpha: 1.0)
        }
    }
    
    static let leftLabel = UIColor { _ in
        if #available(iOS 26.0, *) {
            AppVars.shared.isDarkPaletteActive
            ? UIColor(red: 255 / 255.0, green: 255 / 255.0, blue: 255 / 255.0, alpha: 1)
            : UIColor.darkText
        } else {
            AppVars.shared.isDarkPaletteActive
            ? UIColor(red: 200 / 255.0, green: 200 / 255.0, blue: 200 / 255.0, alpha: 1)
            : UIColor.darkText
        }
    }
    
    static let rightLabel = UIColor { _ in
        if #available(iOS 26.0, *) {
            AppVars.shared.isDarkPaletteActive
            ? UIColor(red: 128 / 255.0, green: 128 / 255.0, blue: 128 / 255.0, alpha: 1.0)
            : UIColor(red: 152 / 255.0, green: 152 / 255.0, blue: 159 / 255.0, alpha: 1.0)
        } else {
            AppVars.shared.isDarkPaletteActive
            ? UIColor(red: 128 / 255.0, green: 128 / 255.0, blue: 128 / 255.0, alpha: 1.0)
            : UIColor(red: 128 / 255.0, green: 128 / 255.0, blue: 128 / 255.0, alpha: 1.0)
        }
    }
    
    static let placeHolder = UIColor { _ in
        if #available(iOS 26.0, *) {
            AppVars.shared.isDarkPaletteActive
            ? UIColor(red: 101 / 255.0, green: 101 / 255.0, blue: 105 / 255.0, alpha: 1.0)
            : UIColor(red: 197 / 255.0, green: 197 / 255.0, blue: 199 / 255.0, alpha: 1.0)
        } else {
            AppVars.shared.isDarkPaletteActive
            ? UIColor(red: 80 / 255.0, green: 80 / 255.0, blue: 80 / 255.0, alpha: 1.0)
            : UIColor(red: 195 / 255.0, green: 195 / 255.0, blue: 195 / 255.0, alpha: 1.0)
        }
    }
    
    static let thumb = UIColor { _ in
        AppVars.shared.isDarkPaletteActive
        ? UIColor(red: 200 / 255.0, green: 200 / 255.0, blue: 200 / 255.0, alpha: 1)
        : UIColor(red: 239 / 255.0, green: 239 / 255.0, blue: 244 / 255.0, alpha: 1.0)
    }
    
    
    // MARK: - Colors for numkeys
    static let numkey = UIColor { _ in
        AppVars.shared.isDarkPaletteActive
        ? UIColor.black
        : UIColor.white
    }
    
    
    // MARK: - Other colors
    static let gray = UIColor { _ in
        AppVars.shared.isDarkPaletteActive
        ? UIColor(red: 243 / 255.0, green: 243 / 255.0, blue: 243 / 255.0, alpha: 1.0)
        : UIColor(red: 23 / 255.0, green: 23 / 255.0, blue: 23 / 255.0, alpha: 1.0)
    }
    
    static let whiteCream = UIColor { _ in
        AppVars.shared.isDarkPaletteActive
        ? UIColor(red: 200 / 255.0, green: 200 / 255.0, blue: 200 / 255.0, alpha: 1.0)
        : UIColor(red: 51 / 255.0, green: 51 / 255.0, blue: 53 / 255.0, alpha: 1.0)
    }
}
