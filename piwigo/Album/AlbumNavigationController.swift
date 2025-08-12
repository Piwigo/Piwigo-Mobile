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
        // Navigation bar appearance
        view.backgroundColor = UIColor.piwigoColorBackground()
        navigationBar.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
        navigationBar.tintColor = UIColor.piwigoColorOrange()
        setNeedsStatusBarAppearanceUpdate()
        
        // Toolbar appearance
        let toolbar = navigationController?.toolbar
        toolbar?.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
        toolbar?.tintColor = UIColor.piwigoColorOrange()

        // Title text attributes
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)
        ]
        let attributesLarge = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 28, weight: .black)
        ]
        navigationBar.largeTitleTextAttributes = attributesLarge
        
        // Search bar
        let searchBar = navigationItem.searchController?.searchBar
        searchBar?.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
        searchBar?.searchTextField.textColor = UIColor.piwigoColorLeftLabel()
        searchBar?.searchTextField.keyboardAppearance = AppVars.shared.isDarkPaletteActive ? .dark : .light
        
        // Navigation bar
        let barAppearance = UINavigationBarAppearance()
        barAppearance.configureWithTransparentBackground()
        barAppearance.backgroundColor = UIColor.piwigoColorBackground().withAlphaComponent(0.9)
        barAppearance.titleTextAttributes = attributes
        barAppearance.largeTitleTextAttributes = attributesLarge
        navigationItem.standardAppearance = barAppearance
        navigationItem.compactAppearance = barAppearance // For iPhone small navigation bar in landscape.
        navigationItem.scrollEdgeAppearance = barAppearance
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
