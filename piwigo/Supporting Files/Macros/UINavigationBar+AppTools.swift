//
//  UINavigationBar+AppTools.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/08/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

extension UINavigationBar {
    
    @MainActor
    func configAppearance(withLargeTitles: Bool) {
        // Buttons color
        tintColor = PwgColor.tintColor

        // Create appearance object
        let barAppearance = UINavigationBarAppearance()
        barAppearance.configureWithTransparentBackground()
        barAppearance.shadowColor = .clear
        if #available(iOS 26.0, *) {
            barAppearance.backgroundColor = .clear
        } else {
            barAppearance.backgroundColor = PwgColor.background.withAlphaComponent(0.9)
        }
        
        // Title text attributes
        var titleAttributeColor: UIColor
        if #available(iOS 26.0, *) {
            titleAttributeColor = PwgColor.gray
        } else {
            titleAttributeColor = PwgColor.whiteCream
        }
        let attributes: [NSAttributedString.Key : Any] = [
            .foregroundColor: titleAttributeColor,
            .font: UIFont.preferredFont(forTextStyle: .headline)
        ]
        barAppearance.titleTextAttributes = attributes

        // Large title text attributes
        if withLargeTitles {
            let attributesLarge: [NSAttributedString.Key : Any] = [
                .foregroundColor: titleAttributeColor,
                .font: largeTitleFontForPreferredContenSizeCategory()
            ]
            barAppearance.largeTitleTextAttributes = attributesLarge
        }
        prefersLargeTitles = withLargeTitles

        // Apply the appearance
        standardAppearance = barAppearance
        compactAppearance = barAppearance // For iPhone small navigation bar in landscape.
        scrollEdgeAppearance = barAppearance
        compactScrollEdgeAppearance = barAppearance
    }
    
    @MainActor
    private func largeTitleFontForPreferredContenSizeCategory() -> UIFont {
        let contentSizeCategory = UIApplication.shared.preferredContentSizeCategory
        
        // Set font size according to the selected category
        /// https://developer.apple.com/design/human-interface-guidelines/typography#Specifications
        switch contentSizeCategory {
        case .extraSmall:
            return UIFont.systemFont(ofSize: 28, weight: .bold)
        case .small:
            return UIFont.systemFont(ofSize: 28, weight: .bold)
        case .medium:
            return UIFont.systemFont(ofSize: 30, weight: .bold)
        case .large:    // default style
            return UIFont.systemFont(ofSize: 34, weight: .bold)
        case .extraLarge:
            return UIFont.systemFont(ofSize: 34, weight: .bold)
        case .extraExtraLarge:
            return UIFont.systemFont(ofSize: 36, weight: .bold)
        case .extraExtraExtraLarge:
            return UIFont.systemFont(ofSize: 36, weight: .bold)
        case .accessibilityMedium:
            return UIFont.systemFont(ofSize: 40, weight: .bold)
        case .accessibilityLarge:
            return UIFont.systemFont(ofSize: 40, weight: .bold)
        case .accessibilityExtraLarge:
            return UIFont.systemFont(ofSize: 44, weight: .bold)
        case .accessibilityExtraExtraLarge:
            return UIFont.systemFont(ofSize: 44, weight: .bold)
        case .accessibilityExtraExtraExtraLarge:
            return UIFont.systemFont(ofSize: 44, weight: .bold)
        case .unspecified:
            return UIFont.systemFont(ofSize: 34, weight: .bold)
        default:
            return UIFont.systemFont(ofSize: 34, weight: .bold)
        }
    }
}
