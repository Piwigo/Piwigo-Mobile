//
//  AboutViewController.swift
//  piwigo
//
//  Created by Spencer Baker on 2/19/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

import UIKit

class AboutViewController: UIViewController, UITextViewDelegate {
    
    @IBOutlet private weak var piwigoTitle: UILabel!
    @IBOutlet private weak var byLabel1: UILabel!
    @IBOutlet private weak var byLabel2: UILabel!
    @IBOutlet private weak var versionLabel: UILabel!
    @IBOutlet private weak var textView: UITextView!
    private var doneBarButton: UIBarButtonItem?

    
// MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("settings_acknowledgements", comment: "Acknowledgements")

        // Title and subtitles
        piwigoTitle.text = NSLocalizedString("settings_appName", comment: "Piwigo Mobile")
        byLabel1.text = NSLocalizedString("authors1", tableName: "About", bundle: Bundle.main, value: "", comment: "By Spencer Baker, Olaf Greck,")
        byLabel2.text = NSLocalizedString("authors2", tableName: "About", bundle: Bundle.main, value: "", comment: "and Eddy Lelièvre-Berna")

        let appVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let appBuildString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        versionLabel.text = "— \(NSLocalizedString("version", tableName: "About", bundle: Bundle.main, value: "", comment: "Version:")) \(appVersionString ?? "") (\(appBuildString ?? "")) —"

        // Thanks and licenses
        textView.attributedText = aboutAttributedString()
        textView.scrollsToTop = true
        if #available(iOS 11.0, *) {
            textView.contentInsetAdjustmentBehavior = .never
        } else {
            // Fallback on earlier versions
            automaticallyAdjustsScrollViewInsets = false
        }

        // Button for returning to albums/images
        doneBarButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(quitSettings))
        doneBarButton?.accessibilityIdentifier = "Done"
    }

    @objc
    func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = UIColor.piwigoColorBackground()

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes as [NSAttributedString.Key : Any]
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = false
        }
        navigationController?.navigationBar.barStyle = Model.sharedInstance().isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.tintColor = UIColor.piwigoColorOrange()
        navigationController?.navigationBar.barTintColor = UIColor.piwigoColorBackground()
        navigationController?.navigationBar.backgroundColor = UIColor.piwigoColorBackground()

        // Text color depdending on background color
        byLabel1.textColor = UIColor.piwigoColorText()
        byLabel2.textColor = UIColor.piwigoColorText()
        versionLabel.textColor = UIColor.piwigoColorText()
        textView.textColor = UIColor.piwigoColorText()
        textView.backgroundColor = UIColor.piwigoColorBackground()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Set navigation buttons
        navigationItem.setRightBarButtonItems([doneBarButton].compactMap { $0 }, animated: true)

        // Register palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette), name: name, object: nil)
    }

    @objc func quitSettings() {
        
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self)

        // Close Settings view
        dismiss(animated: true)
    }


    // MARK: - Acknowledgements

    func aboutAttributedString() -> NSMutableAttributedString? {
        // Release notes attributed string
        let aboutAttributedString = NSMutableAttributedString(string: "")
        let spacerAttributedString = NSMutableAttributedString(string: "\n\n\n")
        let spacerRange = NSRange(location: 0, length: spacerAttributedString.length)
        spacerAttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall()!, range: spacerRange)

        // Translators — Bundle string
        let translatorsString = NSLocalizedString("translators_text", tableName: "About", bundle: Bundle.main, value: "", comment: "Translators text")
        let translatorsAttributedString = NSMutableAttributedString(string: translatorsString)
        let translatorsRange = NSRange(location: 0, length: translatorsString.count)
        translatorsAttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall()!, range: translatorsRange)
        aboutAttributedString.append(translatorsAttributedString)
        aboutAttributedString.append(spacerAttributedString)

        // Introduction string — Bundle string
        let introString = NSLocalizedString("about_text", tableName: "About", bundle: Bundle.main, value: "", comment: "Introduction text")
        let introAttributedString = NSMutableAttributedString(string: introString)
        let introRange = NSRange(location: 0, length: introString.count)
        introAttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall()!, range: introRange)
        aboutAttributedString.append(introAttributedString)

        // AFNetworking Licence — Bundle string
        let afnString = NSLocalizedString("licenceAFN_text", tableName: "About", bundle: Bundle.main, value: "", comment: "AFNetworking licence text")
        let afnAttributedString = NSMutableAttributedString(string: afnString)
        var afnTitleRange = NSRange(location: 0, length: afnString.count)
        afnAttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall()!, range: afnTitleRange)
        afnTitleRange = NSRange(location: 0, length: (afnString as NSString).range(of: "\n").location)
        afnAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold()!, range: afnTitleRange)
        aboutAttributedString.append(afnAttributedString)
        aboutAttributedString.append(spacerAttributedString)

        // IQKeyboardManager Licence — Bundle string
        let iqkmString = NSLocalizedString("licenceIQkeyboard_text", tableName: "About", bundle: Bundle.main, value: "", comment: "IQKeyboardManager licence text")
        let iqkmAttributedString = NSMutableAttributedString(string: iqkmString)
        var iqkmTitleRange = NSRange(location: 0, length: iqkmString.count)
        iqkmAttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall()!, range: iqkmTitleRange)
        iqkmTitleRange = NSRange(location: 0, length: (iqkmString as NSString).range(of: "\n").location)
        iqkmAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold()!, range: iqkmTitleRange)
        aboutAttributedString.append(iqkmAttributedString)
        aboutAttributedString.append(spacerAttributedString)

        // MBProgressHUD Licence — Bundle string
        let mbpHudString = NSLocalizedString("licenceMBProgHUD_text", tableName: "About", bundle: Bundle.main, value: "", comment: "MBProgressHUD licence text")
        let mbpHudAttributedString = NSMutableAttributedString(string: mbpHudString)
        var mbpHudRange = NSRange(location: 0, length: mbpHudString.count)
        mbpHudAttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall()!, range: mbpHudRange)
        mbpHudRange = NSRange(location: 0, length: (mbpHudString as NSString).range(of: "\n").location)
        mbpHudAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold()!, range: mbpHudRange)
        aboutAttributedString.append(mbpHudAttributedString)
        aboutAttributedString.append(spacerAttributedString)

        // MGSwipeTableCell Licence — Bundle string
        let mgstcString = NSLocalizedString("licenceMGSTC_text", tableName: "About", bundle: Bundle.main, value: "", comment: "MGSwipeTableCell licence text")
        let mgstcAttributedString = NSMutableAttributedString(string: mgstcString)
        var mgstcRange = NSRange(location: 0, length: mgstcString.count)
        mgstcAttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall()!, range: mgstcRange)
        mgstcRange = NSRange(location: 0, length: (mgstcString as NSString).range(of: "\n").location)
        mgstcAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold()!, range: mgstcRange)
        aboutAttributedString.append(mgstcAttributedString)
        aboutAttributedString.append(spacerAttributedString)

        // SAMKeychain Licence — Bundle string
        let samString = NSLocalizedString("licenceSAM_text", tableName: "About", bundle: Bundle.main, value: "", comment: "SAMKeychain licence text")
        let samAttributedString = NSMutableAttributedString(string: samString)
        var samRange = NSRange(location: 0, length: samString.count)
        samAttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall()!, range: samRange)
        samRange = NSRange(location: 0, length: (samString as NSString).range(of: "\n").location)
        samAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold()!, range: samRange)
        aboutAttributedString.append(samAttributedString)
        aboutAttributedString.append(spacerAttributedString)

        // UICountingLabel Licence — Bundle string
        let uiclString = NSLocalizedString("licenceUICL_text", tableName: "About", bundle: Bundle.main, value: "", comment: "UICountingLabel licence text")
        let uiclAttributedString = NSMutableAttributedString(string: uiclString)
        var uiclRange = NSRange(location: 0, length: uiclString.count)
        uiclAttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall()!, range: uiclRange)
        uiclRange = NSRange(location: 0, length: (uiclString as NSString).range(of: "\n").location)
        uiclAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold()!, range: uiclRange)
        aboutAttributedString.append(uiclAttributedString)
        aboutAttributedString.append(spacerAttributedString)

        // MIT Licence — Bundle string
        let mitString = NSLocalizedString("licenceMIT_text", tableName: "About", bundle: Bundle.main, value: "", comment: "AFNetworking licence text")
        let mitAttributedString = NSMutableAttributedString(string: mitString)
        var mitTitleRange = NSRange(location: 0, length: mitString.count)
        mitAttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall()!, range: mitTitleRange)
        mitTitleRange = NSRange(location: 0, length: (mitString as NSString).range(of: "\n").location)
        mitAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold()!, range: mitTitleRange)
        aboutAttributedString.append(mitAttributedString)

        return aboutAttributedString
    }
}
