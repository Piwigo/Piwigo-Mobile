//
//  DataMigrationViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 01/06/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import UIKit

class DataMigrationViewController: UIViewController {
    
    @IBOutlet var piwigoLogo: UIImageView!
    @IBOutlet var migrationLabel: UILabel!
    @IBOutlet var pleaseWaitLabel: UILabel!
    @IBOutlet var piwigoUrlLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        migrationLabel.text = NSLocalizedString("CoreData_MigrationProgress", comment: "Migration in progress...")
        pleaseWaitLabel.text = NSLocalizedString("Coredata_MigrationPleaseWait", comment: "We are currently migrating some of your data. Please wait until it is complete. Do not kill the application.")
    }

    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = .piwigoColorBackground()

        // Change text colour according to palette colour
        if #available(iOS 13.0, *) {
            piwigoLogo?.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        }

        // Text color depdending on background color
        migrationLabel.textColor = .piwigoColorText()
        pleaseWaitLabel.textColor = .piwigoColorText()
        piwigoUrlLabel.textColor = .piwigoColorText()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set colors, fonts, etc.
        applyColorPalette()
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
        // Register progress
        NotificationCenter.default.addObserver(self, selector: #selector(updateProgress),
                                               name: Notification.Name.pwgMigrationProgressUpdated, object: nil)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: { _ in
        }, completion: nil)
    }

    @objc func updateProgress(_ notification: Notification) {
        guard let progressString = notification.userInfo?["progress"] as? Float else { return }
        progressView.progress = Float(progressString)
    }
    
    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
}
