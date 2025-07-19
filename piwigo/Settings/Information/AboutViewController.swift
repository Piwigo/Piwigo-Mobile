//
//  AboutViewController.swift
//  piwigo
//
//  Created by Spencer Baker on 2/19/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5 by Eddy Lelièvre-Berna on 28/03/2020
//

import UIKit
import piwigoKit

class AboutViewController: UIViewController, UITextViewDelegate {
    
    @IBOutlet private weak var piwigoLogo: UIImageView!
    @IBOutlet private weak var authorsLabel: UILabel!
    @IBOutlet private weak var versionLabel: UILabel!
    @IBOutlet private weak var textView: UITextView!
    private var fixTextPositionAfterLoadingViewOnPad: Bool!
    private var doneBarButton: UIBarButtonItem?

    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("settings_acknowledgements", comment: "Acknowledgements")

        // Button for returning to albums/images
        doneBarButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(quitSettings))
        doneBarButton?.accessibilityIdentifier = "Done"
    }

    @MainActor
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = .piwigoColorBackground()

        // Change text colour according to palette colour
        if #available(iOS 13.0, *) {
            piwigoLogo?.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        }

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes as [NSAttributedString.Key : Any]
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.tintColor = .piwigoColorOrange()
        navigationController?.navigationBar.barTintColor = .piwigoColorBackground()
        navigationController?.navigationBar.backgroundColor = .piwigoColorBackground()

        if #available(iOS 15.0, *) {
            /// In iOS 15, UIKit has extended the usage of the scrollEdgeAppearance,
            /// which by default produces a transparent background, to all navigation bars.
            let barAppearance = UINavigationBarAppearance()
            barAppearance.configureWithOpaqueBackground()
            barAppearance.backgroundColor = .piwigoColorBackground()
            navigationController?.navigationBar.standardAppearance = barAppearance
            navigationController?.navigationBar.scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance
        }

        // Text color depdending on background color
        authorsLabel.textColor = .piwigoColorText()
        versionLabel.textColor = .piwigoColorText()
        textView.textColor = .piwigoColorText()
        textView.backgroundColor = .piwigoColorBackground()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Piwigo authors and app version
        authorsLabel.text = SettingsUtilities.getAuthors(forView: view)
        versionLabel.text = SettingsUtilities.getAppVersion()

        // Thanks and licenses
        fixTextPositionAfterLoadingViewOnPad = true
        textView.attributedText = aboutAttributedString()
        textView.scrollsToTop = true
        textView.contentInsetAdjustmentBehavior = .never

        // Set colors, fonts, etc.
        applyColorPalette()

        // Set navigation buttons
        navigationItem.setRightBarButtonItems([doneBarButton].compactMap { $0 }, animated: true)

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Update Piwigo authors label
        coordinator.animate(alongsideTransition: { [self] _ in
            // Piwigo authors
            self.authorsLabel.text = SettingsUtilities.getAuthors(forView: self.view)
        }, completion: nil)
    }
    
    override func viewDidLayoutSubviews() {
        if (fixTextPositionAfterLoadingViewOnPad) {
            // Scroll text to where it is expected to be after loading view
            fixTextPositionAfterLoadingViewOnPad = false
            textView.setContentOffset(.zero, animated: false)
        }
    }

    @objc func quitSettings() {
        // Close Settings view
        dismiss(animated: true)
    }

    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }

    
    // MARK: - Acknowledgements
    func aboutAttributedString() -> NSMutableAttributedString? {
        // Release notes attributed string
        let aboutAttributedString = NSMutableAttributedString(string: "")
        let spacerAttributedString = NSMutableAttributedString(string: "\n\n\n")
        let spacerRange = NSRange(location: 0, length: spacerAttributedString.length)
        spacerAttributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 13), range: spacerRange)

        // Translators — Bundle string
        let translatorsString = NSLocalizedString("translators_text", tableName: "About", bundle: Bundle.main, value: "", comment: "Translators text")
        let translatorsAttributedString = NSMutableAttributedString(string: translatorsString)
        let translatorsRange = NSRange(location: 0, length: translatorsString.count)
        translatorsAttributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 13), range: translatorsRange)
        aboutAttributedString.append(translatorsAttributedString)
        aboutAttributedString.append(spacerAttributedString)

        // MIT Licence — Bundle string
        let mitString = NSLocalizedString("licenceMIT_text", tableName: "About", bundle: Bundle.main, value: "", comment: "AFNetworking licence text")
        let mitAttributedString = NSMutableAttributedString(string: mitString)
        var mitTitleRange = NSRange(location: 0, length: mitString.count)
        mitAttributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 13), range: mitTitleRange)
        mitTitleRange = NSRange(location: 0, length: (mitString as NSString).range(of: "\n").location)
        mitAttributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 17, weight: .bold), range: mitTitleRange)
        aboutAttributedString.append(mitAttributedString)

        return aboutAttributedString
    }
}
