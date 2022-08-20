//
//  ReleaseNotesViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/07/2017.
//  Copyright © 2017 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5 by Eddy Lelièvre-Berna on 28/03/2020
//

import UIKit
import piwigoKit

class ReleaseNotesViewController: UIViewController {
    
    @IBOutlet private weak var piwigoTitle: UILabel!
    @IBOutlet private weak var authorsLabel: UILabel!
    @IBOutlet private weak var versionLabel: UILabel!
    @IBOutlet private weak var textView: UITextView!
    private var fixTextPositionAfterLoadingViewOnPad: Bool!
    private var doneBarButton: UIBarButtonItem?

    
// MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("settings_releaseNotes", comment: "Release Notes")

        // Button for returning to albums/images
        doneBarButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(quitSettings))
        doneBarButton?.accessibilityIdentifier = "Done"
    }

    @objc
    func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = .piwigoColorBackground()

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes as [NSAttributedString.Key : Any]
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = false
        }
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

        // Piwigo app
        piwigoTitle.text = NSLocalizedString("settings_appName", comment: "Piwigo Mobile")

        // Piwigo authors
        updateAuthorsLabel()

        // Piwigo app version
        let appVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let appBuildString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        versionLabel.text = "— \(NSLocalizedString("version", tableName: "About", bundle: Bundle.main, value: "", comment: "Version:")) \(appVersionString ?? "") (\(appBuildString ?? "")) —"

        // Release notes
        fixTextPositionAfterLoadingViewOnPad = true
        textView.attributedText = notesAttributedString()
        textView.scrollsToTop = true
        if #available(iOS 11.0, *) {
            textView.contentInsetAdjustmentBehavior = .never
        } else {
            // Fallback on earlier versions
            automaticallyAdjustsScrollViewInsets = false
        }

        // Set colors, fonts, etc.
        applyColorPalette()

        // Set navigation buttons
        navigationItem.setRightBarButtonItems([doneBarButton].compactMap { $0 }, animated: true)
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: .pwgPaletteChanged, object: nil)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Update Piwigo authors label
        coordinator.animate(alongsideTransition: { (context) in
            // Piwigo authors
            self.updateAuthorsLabel()
        }, completion: nil)
    }
    
    override func viewDidLayoutSubviews() {

        if (fixTextPositionAfterLoadingViewOnPad) {
            // Scroll text to where it is expected to be after loading view
            fixTextPositionAfterLoadingViewOnPad = false
            textView.setContentOffset(.zero, animated: false)
        }
    }

    private func updateAuthorsLabel () {
        // Piwigo authors
        let authors1 = NSLocalizedString("authors1", tableName: "About", bundle: Bundle.main, value: "", comment: "By Spencer Baker, Olaf Greck,")
        let authors2 = NSLocalizedString("authors2", tableName: "About", bundle: Bundle.main, value: "", comment: "and Eddy Lelièvre-Berna")
        
        // Change label according to orientation
        var orientation: UIInterfaceOrientation = .portrait
        if #available(iOS 13.0, *) {
            orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? .portrait
        } else {
            orientation = UIApplication.shared.statusBarOrientation
        }
        if (UIDevice.current.userInterfaceIdiom == .phone) && orientation.isPortrait {
            // iPhone in portrait mode
            authorsLabel.text = "\(authors1)\r\(authors2)"
        }
        else {
            // iPhone in landscape mode, iPad in any orientation
            authorsLabel.text = "\(authors1) \(authors2)"
        }
    }

    @objc func quitSettings() {
        // Close Settings view
        dismiss(animated: true)
    }

    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: .pwgPaletteChanged, object: nil)
    }

    
    // MARK: - Release Notes
    private func notesAttributedString() -> NSMutableAttributedString? {
        // Release notes attributed string
        let notesAttributedString = NSMutableAttributedString(string: "")

        // Release 2.12.x — Bundle string
        notesAttributedString.append(releaseNotes("v2.12.5_text", comment: "v2.12.5 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.12.4_text", comment: "v2.12.4 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.12.3_text", comment: "v2.12.3 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.12.2_text", comment: "v2.12.2 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.12.1_text", comment: "v2.12.1 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.12.0_text", comment: "v2.12.0 Release Notes text"))

        // Release 2.11.x — Bundle string
        notesAttributedString.append(releaseNotes("v2.11.2_text", comment: "v2.11.2 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.11.1_text", comment: "v2.11.1 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.11.0_text", comment: "v2.11.0 Release Notes text"))

        // Release 2.10.x — Bundle string
        notesAttributedString.append(releaseNotes("v2.10.0_text", comment: "v2.10.0 Release Notes text"))

        // Release 2.9.x — Bundle string
        notesAttributedString.append(releaseNotes("v2.9.5_text", comment: "v2.9.5 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.9.4_text", comment: "v2.9.4 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.9.3_text", comment: "v2.9.3 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.9.2_text", comment: "v2.9.2 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.9.1_text", comment: "v2.9.1 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.9.0_text", comment: "v2.9.0 Release Notes text"))

         // Release 2.8.x — Bundle string
        notesAttributedString.append(releaseNotes("v2.8.2_text", comment: "v2.8.2 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.8.1_text", comment: "v2.8.1 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.8.0_text", comment: "v2.8.0 Release Notes text"))

        // Release 2.7.x — Bundle string
        notesAttributedString.append(releaseNotes("v2.7.2_text", comment: "v2.7.2 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.7.1_text", comment: "v2.7.1 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.7.0_text", comment: "v2.7.0 Release Notes text"))

        // Release 2.6.x — Bundle string
        notesAttributedString.append(releaseNotes("v2.6.4_text", comment: "v2.6.4 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.6.3_text", comment: "v2.6.3 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.6.2_text", comment: "v2.6.2 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.6.1_text", comment: "v2.6.1 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.6.0_text", comment: "v2.6.0 Release Notes text"))

        // Release 2.5.x — Bundle string
        notesAttributedString.append(releaseNotes("v2.5.4_text", comment: "v2.5.4 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.5.3_text", comment: "v2.5.3 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.5.2_text", comment: "v2.5.2 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.5.1_text", comment: "v2.5.1 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.5.0_text", comment: "v2.5.0 Release Notes text"))

        // Release 2.4.x — Bundle string
        notesAttributedString.append(releaseNotes("v2.4.8_text", comment: "v2.4.8 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.4.7_text", comment: "v2.4.7 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.4.6_text", comment: "v2.4.6 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.4.5_text", comment: "v2.4.5 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.4.4_text", comment: "v2.4.4 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.4.3_text", comment: "v2.4.3 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.4.2_text", comment: "v2.4.2 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.4.1_text", comment: "v2.4.1 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.4.0_text", comment: "v2.4.0 Release Notes text"))

        // Release 2.3.x — Bundle string
        notesAttributedString.append(releaseNotes("v2.3.5_text", comment: "v2.3.5 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.3.4_text", comment: "v2.3.4 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.3.3_text", comment: "v2.3.3 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.3.2_text", comment: "v2.3.2 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.3.1_text", comment: "v2.3.1 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.3.0_text", comment: "v2.3.0 Release Notes text"))

        // Release 2.2.x — Bundle string
        notesAttributedString.append(releaseNotes("v2.2.7_text", comment: "v2.2.7 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.2.6_text", comment: "v2.2.6 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.2.5_text", comment: "v2.2.5 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.2.4_text", comment: "v2.2.4 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.2.3_text", comment: "v2.2.3 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.2.2_text", comment: "v2.2.2 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.2.1_text", comment: "v2.2.1 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.2.0_text", comment: "v2.2.0 Release Notes text"))

        // Release 2.1.x — Bundle string
        notesAttributedString.append(releaseNotes("v2.1.9_text", comment: "v2.1.9 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.1.8_text", comment: "v2.1.8 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.1.7_text", comment: "v2.1.7 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.1.6_text", comment: "v2.1.6 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.1.5_text", comment: "v2.1.5 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.1.4_text", comment: "v2.1.4 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.1.3_text", comment: "v2.1.3 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.1.2_text", comment: "v2.1.2 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.1.1_text", comment: "v2.1.1 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.1.0_text", comment: "v2.1.0 Release Notes text"))

        // Release 2.0.x — Bundle string
        notesAttributedString.append(releaseNotes("v2.0.4_text", comment: "v2.0.4 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.0.3_text", comment: "v2.0.3 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.0.2_text", comment: "v2.0.2 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.0.1_text", comment: "v2.0.1 Release Notes text"))
        notesAttributedString.append(releaseNotes("v2.0.0_text", comment: "v2.0.0 Release Notes text"))

        // Release 1.x.x — Bundle string
        notesAttributedString.append(releaseNotes("v1.0.0_text", comment: "v1.0.0 Release Notes text",
                                                  lineFeed: false))
        return notesAttributedString
    }

    private func releaseNotes(_ version: String, comment: String, lineFeed: Bool = true) -> NSAttributedString {
        let vString = NSLocalizedString(version, tableName: "ReleaseNotes",
                                        bundle: Bundle.main, value: "", comment: comment)
        let vAttributedString = NSMutableAttributedString(string: vString)
        var vRange = NSRange(location: 0, length: vString.count)
        vAttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: vRange)
        vRange = NSRange(location: 0, length: (vString as NSString).range(of: "\n").location)
        vAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: vRange)
        if lineFeed {
            let spacerAttributedString = NSMutableAttributedString(string: "\n\n\n")
            let spacerRange = NSRange(location: 0, length: spacerAttributedString.length)
            spacerAttributedString.addAttribute(.font, value: UIFont.piwigoFontTiny(), range: spacerRange)
            vAttributedString.append(spacerAttributedString)
        }
        return vAttributedString
    }
}
