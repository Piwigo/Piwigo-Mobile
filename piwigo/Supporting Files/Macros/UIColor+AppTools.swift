//
//  UIColor+AppTools.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 13/12/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

// MARK: App Colors
struct PwgColor {
    
    // MARK: - Text Color
    static var text: UIColor {
        AppVars.shared.isDarkPaletteActive
        ? UIColor.lightText
        : UIColor.darkText
    }
    
    
    // MARK: - Color of Views
    static var background: UIColor {
        AppVars.shared.isDarkPaletteActive
        ? UIColor(red: 23 / 255.0, green: 23 / 255.0, blue: 23 / 255.0, alpha: 1.0)
        : UIColor(red: 239 / 255.0, green: 239 / 255.0, blue: 244 / 255.0, alpha: 1.0)
    }

    static var tintColor: UIColor {
        if #available(iOS 26.0, *) {
            return .label
        } else {
            return PwgColor.orange
        }
    }
    
    
    // MARK: - Shadow Color of Buttons
    static var shadow: UIColor {
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
    static var header: UIColor {
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
    
    static var separator: UIColor {
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
    
    static var cellBackground: UIColor {
        AppVars.shared.isDarkPaletteActive
        ? UIColor(red: 42 / 255.0, green: 42 / 255.0, blue: 45 / 255.0, alpha: 1.0)
        : UIColor(red: 255 / 255.0, green: 255 / 255.0, blue: 255 / 255.0, alpha: 1.0)
    }
    
    static var leftLabel: UIColor {
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
    
    static var rightLabel: UIColor {
        if #available(iOS 26.0, *) {
            AppVars.shared.isDarkPaletteActive
            ? UIColor(red: 128 / 255.0, green: 128 / 255.0, blue: 128 / 255.0, alpha: 1.0)
            : UIColor(red: 109 / 255.0, green: 109 / 255.0, blue: 109 / 255.0, alpha: 1.0)
        } else {
            AppVars.shared.isDarkPaletteActive
            ? UIColor(red: 128 / 255.0, green: 128 / 255.0, blue: 128 / 255.0, alpha: 1.0)
            : UIColor(red: 109 / 255.0, green: 109 / 255.0, blue: 109 / 255.0, alpha: 1.0)
        }
    }
    
    static var placeHolder: UIColor {
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
    
    static var thumb: UIColor {
        AppVars.shared.isDarkPaletteActive
        ? UIColor(red: 200 / 255.0, green: 200 / 255.0, blue: 200 / 255.0, alpha: 1)
        : UIColor(red: 239 / 255.0, green: 239 / 255.0, blue: 244 / 255.0, alpha: 1.0)
    }
    
    
    // MARK: - Colors for numkeys
    static var numkey: UIColor {
        AppVars.shared.isDarkPaletteActive
        ? UIColor.black
        : UIColor.white
    }
    
    
    // MARK: - Other colors
    static var gray: UIColor {
        AppVars.shared.isDarkPaletteActive
        ? UIColor(red: 243 / 255.0, green: 243 / 255.0, blue: 243 / 255.0, alpha: 1.0)
        : UIColor(red: 23 / 255.0, green: 23 / 255.0, blue: 23 / 255.0, alpha: 1.0)
    }
    
    static var whiteCream: UIColor {
        AppVars.shared.isDarkPaletteActive
        ? UIColor(red: 200 / 255.0, green: 200 / 255.0, blue: 200 / 255.0, alpha: 1.0)
        : UIColor(red: 51 / 255.0, green: 51 / 255.0, blue: 53 / 255.0, alpha: 1.0)
    }
}


// MARK: - Extension
extension UIColor {
    
    // Calculate relative luminance
    fileprivate var luminance: CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        func adjust(component: CGFloat) -> CGFloat {
            return component <= 0.03928
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
        
        let r = adjust(component: red)
        let g = adjust(component: green)
        let b = adjust(component: blue)
        
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
    
    // Get contrast ratio between two colors
    func contrastRatio(with color: UIColor) -> CGFloat {
        let lum1 = self.luminance
        let lum2 = color.luminance
        let lighter = max(lum1, lum2)
        let darker = min(lum1, lum2)
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    // Get optimal text color (black or white)
    var contrastingTextColor: UIColor {
        let whiteContrast = self.contrastRatio(with: .white)
        let blackContrast = self.contrastRatio(with: .black)
        return whiteContrast > blackContrast ? .white : .black
    }
    
    // Adjust color to meet minimum contrast ratio
    func adjustedForContrast(against backgroundColor: UIColor, minimumRatio: CGFloat = 4.5) -> UIColor {
        
        let currentRatio = self.contrastRatio(with: backgroundColor)
        
        // If already meets requirements, return as is
        if currentRatio >= minimumRatio {
            return self
        }
        
        // Determine if we need to lighten or darken
        let bgLuminance = backgroundColor.luminance
        
        // Try to preserve hue and saturation, adjust brightness
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Binary search for the right brightness level
        var minBrightness: CGFloat = 0
        var maxBrightness: CGFloat = 1
        var testBrightness = brightness
        var iterations = 0
        let maxIterations = 20
        
        while iterations < maxIterations {
            let testColor = UIColor(
                hue: hue,
                saturation: saturation,
                brightness: testBrightness,
                alpha: alpha
            )
            
            let testRatio = testColor.contrastRatio(with: backgroundColor)
            
            if abs(testRatio - minimumRatio) < 0.1 {
                return testColor
            }
            
            if testRatio < minimumRatio {
                // Need more contrast
                if bgLuminance > 0.5 {
                    maxBrightness = testBrightness
                    testBrightness = (minBrightness + testBrightness) / 2
                } else {
                    minBrightness = testBrightness
                    testBrightness = (testBrightness + maxBrightness) / 2
                }
            } else {
                // Has enough contrast
                return testColor
            }
            
            iterations += 1
        }
        
        // Fallback to simple black or white
        return backgroundColor.contrastingTextColor
    }
}
