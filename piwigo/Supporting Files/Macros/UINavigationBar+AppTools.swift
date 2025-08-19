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
    func configAppearance(withLargeTitle: Bool) {
        // Bar style
        barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
        
        // Buttons color
        if #available(iOS 26.0, *) {
            tintColor = PwgColor.gray
        } else {
            tintColor = PwgColor.orange
        }

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
            .font: UIFont.systemFont(ofSize: 17)
        ]
        let attributesLarge: [NSAttributedString.Key : Any] = [
            .foregroundColor: titleAttributeColor,
            .font: UIFont.systemFont(ofSize: 28, weight: .black)
        ]
        barAppearance.titleTextAttributes = attributes
        barAppearance.largeTitleTextAttributes = attributesLarge
        prefersLargeTitles = withLargeTitle
        
        // Apply the appearance
        standardAppearance = barAppearance
        compactAppearance = barAppearance // For iPhone small navigation bar in landscape.
        scrollEdgeAppearance = barAppearance
        compactScrollEdgeAppearance = barAppearance
    }
}
