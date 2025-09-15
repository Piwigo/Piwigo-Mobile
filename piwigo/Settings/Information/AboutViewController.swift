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

    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Title
        title = NSLocalizedString("settings_acknowledgements", comment: "Acknowledgements")
    }

    @MainActor
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = PwgColor.background

        // Change text colour according to palette colour
        piwigoLogo?.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light

        // Navigation bar
        navigationController?.navigationBar.configAppearance(withLargeTitles: false)

        // Text color depdending on background color
        authorsLabel.textColor = PwgColor.text
        versionLabel.textColor = PwgColor.text
        textView.textColor = PwgColor.text
        textView.backgroundColor = PwgColor.background
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
        // Scroll text to where it is expected to be after loading view
        if (fixTextPositionAfterLoadingViewOnPad) {
            fixTextPositionAfterLoadingViewOnPad = false
            textView.setContentOffset(.zero, animated: false)
        }
        
        // Navigation bar
        navigationController?.navigationBar.prefersLargeTitles = false
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
        spacerAttributedString.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .footnote), range: spacerRange)

        // Translators — Bundle string
        let translatorsString = NSLocalizedString("translators_text", tableName: "About", bundle: Bundle.main, value: "", comment: "Translators text")
        let translatorsAttributedString = NSMutableAttributedString(string: translatorsString)
        let translatorsRange = NSRange(location: 0, length: translatorsString.count)
        translatorsAttributedString.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .footnote), range: translatorsRange)
        aboutAttributedString.append(translatorsAttributedString)
        aboutAttributedString.append(spacerAttributedString)

        // MIT Licence — Bundle string
        let mitString = NSLocalizedString("licenceMIT_text", tableName: "About", bundle: Bundle.main, value: "", comment: "AFNetworking licence text")
        let mitAttributedString = NSMutableAttributedString(string: mitString)
        var mitTitleRange = NSRange(location: 0, length: mitString.count)
        mitAttributedString.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .footnote), range: mitTitleRange)
        mitTitleRange = NSRange(location: 0, length: (mitString as NSString).range(of: "\n").location)
        mitAttributedString.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .headline), range: mitTitleRange)
        aboutAttributedString.append(mitAttributedString)

        return aboutAttributedString
    }
}
