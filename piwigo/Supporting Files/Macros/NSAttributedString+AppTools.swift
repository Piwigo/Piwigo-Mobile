//
//  NSAttributedString+AppTools.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 13/12/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

extension NSAttributedString {
    
    // Apply adaptive text color based on background
//    func adaptingTextColor(to backgroundColor: UIColor) -> NSAttributedString {
//        let mutableString = NSMutableAttributedString(attributedString: self)
//        let range = NSRange(location: 0, length: mutableString.length)
//        
//        // Enumerate through all existing foreground colors
//        mutableString.enumerateAttribute(.foregroundColor, in: range, options: []) { value, range, _ in
//            
//            // Get the adaptive color
//            let adaptiveColor = backgroundColor.adjustedForContrast(against: backgroundColor)
//            
//            // Replace or set the foreground color
//            mutableString.addAttribute(.foregroundColor, value: adaptiveColor, range: range)
//        }
//        return mutableString
//    }
    
    // More sophisticated: preserve color hue but adjust brightness
    func adaptingTextColorPreservingHue(to backgroundColor: UIColor, defaultColor: UIColor) -> NSAttributedString {
        let mutableString = NSMutableAttributedString(attributedString: self)
        let range = NSRange(location: 0, length: mutableString.length)
        
        mutableString.enumerateAttribute(.foregroundColor, in: range, options: []) { value, range, _ in
            
            if let originalColor = value as? UIColor {
                // Adjust the original color for better contrast
                let adjustedColor = originalColor.adjustedForContrast(against: backgroundColor, minimumRatio: 3.0)
                mutableString.addAttribute(.foregroundColor, value: adjustedColor, range: range)
            }
            else {
                // No color set, use default adaptive color
                mutableString.addAttribute(.foregroundColor, value: defaultColor, range: range)
            }
        }
        return mutableString
    }
    
    // Check if current text meets contrast requirements
//    func meetsContrastRequirements(against backgroundColor: UIColor, minimumRatio: CGFloat = 4.5) -> Bool {
//        let range = NSRange(location: 0, length: self.length)
//        var meetsRequirements = true
//        
//        self.enumerateAttribute(.foregroundColor, in: range, options: []) { value, _, stop in
//            
//            if let textColor = value as? UIColor {
//                let ratio = textColor.contrastRatio(with: backgroundColor)
//                if ratio < minimumRatio {
//                    meetsRequirements = false
//                    stop.pointee = true
//                }
//            }
//        }
//        return meetsRequirements
//    }
}

