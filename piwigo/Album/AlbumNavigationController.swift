//
//  AlbumNavigationController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 04/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

class AlbumNavigationController: UINavigationController
{
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    override init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        debugPrint("============================================")
        debugPrint("••> viewDidLoad in AlbumNavigationController")

        // Navigation bar
        navigationBar.accessibilityIdentifier = "AlbumImagesNav"
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }
    
    @MainActor
    @objc func applyColorPalette() {
        // Background color
        view.backgroundColor = PwgColor.background

        // Status bar
        setNeedsStatusBarAppearanceUpdate()

        // Navigation bar
        navigationBar.configAppearance(withLargeTitle: false)
        
        // Toolbar
        toolbar.configAppearance()
        
        // Search bar
        navigationItem.searchController?.searchBar.configAppearance()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        debugPrint("••> viewWillAppear in AlbumNavigationController")
        
        // Set colors, fonts, etc.
        applyColorPalette()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return AppVars.shared.isDarkPaletteActive ? .lightContent : .darkContent
    }
}
