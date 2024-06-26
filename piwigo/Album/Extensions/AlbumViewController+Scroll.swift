//
//  AlbumViewController+Scroll.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

// MARK: - UIScrollViewDelegate
extension AlbumViewController: UIScrollViewDelegate
{
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Show/hide navigation bar border
        var topSpace = navigationController?.navigationBar.bounds.height ?? 0
        if #available(iOS 13, *) {
            topSpace += view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
        } else {
            topSpace += UIApplication.shared.statusBarFrame.height
        }
        if (scrollView.contentOffset.y + topSpace).rounded(.down) > 0 {
            // Show bar border
            if #available(iOS 13.0, *) {
                let navBar = navigationItem
                let barAppearance = navBar.standardAppearance
                let shadowColor = AppVars.shared.isDarkPaletteActive ? UIColor(white: 1.0, alpha: 0.15) : UIColor(white: 0.0, alpha: 0.3)
                if barAppearance?.shadowColor != shadowColor {
                    barAppearance?.shadowColor = shadowColor
                    navBar.scrollEdgeAppearance = barAppearance
                }
            }
        } else {
            // Hide bar border
            if #available(iOS 13.0, *) {
                let navBar = navigationItem
                let barAppearance = navBar.standardAppearance
                if barAppearance?.shadowColor != UIColor.clear {
                    barAppearance?.shadowColor = UIColor.clear
                    navBar.scrollEdgeAppearance = barAppearance
                }
            }
        }
    }
}
