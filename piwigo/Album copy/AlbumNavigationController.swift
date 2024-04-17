//
//  AlbumNavigationController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 01/05/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import UIKit

class AlbumNavigationController: UINavigationController {
    // For managing the status bar
    override var preferredStatusBarStyle: UIStatusBarStyle {
        if #available(iOS 13.0, *) {
            return AppVars.shared.isDarkPaletteActive ? .lightContent : .darkContent
        } else {
            // Fallback on earlier versions
            return .lightContent
        }
    }
}
