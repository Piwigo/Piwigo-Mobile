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
            // Get adopted size category
            let contentSizeCategory = UIApplication.shared.preferredContentSizeCategory

            // Title
            let largeTitleTextAttributes: [NSAttributedString.Key : Any] = [
                .foregroundColor: titleAttributeColor,
                .font: largeTitleFontForPreferredContenSizeCategory(contentSizeCategory)
            ]
            barAppearance.largeTitleTextAttributes = largeTitleTextAttributes
        }
        prefersLargeTitles = withLargeTitles
        
        // Subtitle
        if #available(iOS 26.0, *) {
            let subtitleAttributeColor: UIColor = PwgColor.rightLabel
            let subtitleAttributes: [NSAttributedString.Key : Any] = [
                .foregroundColor: subtitleAttributeColor,
                .font: UIFont.preferredFont(forTextStyle: .caption2)
            ]
            barAppearance.subtitleTextAttributes = subtitleAttributes
            
            if withLargeTitles {
                let subtitleLargeAttributes: [NSAttributedString.Key : Any] = [
                    .foregroundColor: PwgColor.rightLabel,
                    .font: UIFont.preferredFont(forTextStyle: .subheadline)
                ]
                barAppearance.largeSubtitleTextAttributes = subtitleLargeAttributes
            }
        }
        
        // Apply the appearance
        standardAppearance = barAppearance
        compactAppearance = barAppearance // For iPhone small navigation bar in landscape.
        scrollEdgeAppearance = barAppearance
        compactScrollEdgeAppearance = barAppearance
    }
    
    @MainActor
    private func largeTitleFontForPreferredContenSizeCategory(_ contentSizeCategory: UIContentSizeCategory) -> UIFont {
        // Set font size according to the selected category
        /// https://developer.apple.com/design/human-interface-guidelines/typography#Specifications
        switch contentSizeCategory {
        case .extraSmall:
            return UIFont.systemFont(ofSize: 31, weight: .bold)
        case .small:
            return UIFont.systemFont(ofSize: 32, weight: .bold)
        case .medium:
            return UIFont.systemFont(ofSize: 33, weight: .bold)
        case .large:    // default style
            return UIFont.systemFont(ofSize: 34, weight: .bold)
        case .extraLarge:
            return UIFont.systemFont(ofSize: 36, weight: .bold)
        case .extraExtraLarge:
            return UIFont.systemFont(ofSize: 38, weight: .bold)
        case .extraExtraExtraLarge:
            return UIFont.systemFont(ofSize: 40, weight: .bold)
        case .accessibilityMedium:
            return UIFont.systemFont(ofSize: 44, weight: .bold)
        case .accessibilityLarge:
            return UIFont.systemFont(ofSize: 48, weight: .bold)
        case .accessibilityExtraLarge:
            return UIFont.systemFont(ofSize: 52, weight: .bold)
        case .accessibilityExtraExtraLarge:
            return UIFont.systemFont(ofSize: 56, weight: .bold)
        case .accessibilityExtraExtraExtraLarge:
            return UIFont.systemFont(ofSize: 60, weight: .bold)
        case .unspecified:
            fallthrough
        default:
            return UIFont.systemFont(ofSize: 34, weight: .bold)
        }
    }
}
