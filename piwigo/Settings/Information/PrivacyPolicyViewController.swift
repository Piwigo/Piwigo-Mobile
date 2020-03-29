//
//  PrivacyPolicyViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 26/10/2018.
//  Copyright © 2018 Piwigo.org. All rights reserved.
//

import UIKit

class PrivacyPolicyViewController: UIViewController, UITextViewDelegate {
    
    @IBOutlet var textView: UITextView!
    private var fixTextPositionAfterLoadingViewOnPad: Bool!
    private var doneBarButton: UIBarButtonItem?


    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("settings_privacy", comment: "Policy Privacy")
        
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
        textView.textColor = UIColor.piwigoColorText()
        textView.backgroundColor = UIColor.piwigoColorBackground()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set textView
        fixTextPositionAfterLoadingViewOnPad = true
        textView.attributedText = privacyPolicy()
        textView.scrollsToTop = true
        if #available(iOS 11.0, *) {
            textView?.contentInsetAdjustmentBehavior = .never
        } else {
            // Fallback on earlier versions
            automaticallyAdjustsScrollViewInsets = false
        }

        // Set colors, fonts, etc.
        applyColorPalette()

        // Set navigation buttons
        navigationItem.setRightBarButtonItems([doneBarButton].compactMap { $0 }, animated: true)
        
        // Register palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette), name: name, object: nil)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: { (context) in
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

        // Unregister palette changes
        NotificationCenter.default.removeObserver(self)

        // Close Settings view
        dismiss(animated: true)
    }
    
    
    // MARK: - Pricay Policy

    func privacyPolicy() -> NSAttributedString {
        // Privacy policy attributed string
        let privacyAttributedString = NSMutableAttributedString(string: "\n")
        let spacerAttributedString = NSMutableAttributedString(string: "\n\n", attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()!
        ])

        // Privcy policy string — Bundle string
        let firstString = NSLocalizedString("privacy_text", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "Privacy policy text")
        let firstAttributedString = NSMutableAttributedString(string: firstString, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()!
        ])
        privacyAttributedString.append(firstAttributedString)
        privacyAttributedString.append(spacerAttributedString)

        // Introduction — Bundle string
        let introTitle = NSLocalizedString("intro_title", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "Introduction title")
        let introAttributedTitle = NSMutableAttributedString(string: introTitle, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontBold()!
        ])
        privacyAttributedString.append(introAttributedTitle)
        privacyAttributedString.append(spacerAttributedString)

        let introString1 = NSLocalizedString("intro_text1", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "Introduction text1")
        let introAttributedString1 = NSMutableAttributedString(string: introString1, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()!
        ])
        privacyAttributedString.append(introAttributedString1)
        privacyAttributedString.append(spacerAttributedString)

        let introString2 = NSLocalizedString("intro_text2", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "Introduction text2")
        let introAttributedString2 = NSMutableAttributedString(string: introString2, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()!
        ])
        privacyAttributedString.append(introAttributedString2)
        privacyAttributedString.append(spacerAttributedString)

        let introString3 = NSLocalizedString("intro_text3", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "Introduction text3")
        let introAttributedString3 = NSMutableAttributedString(string: introString3, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()!
        ])
        privacyAttributedString.append(introAttributedString3)
        privacyAttributedString.append(spacerAttributedString)

        let introString4 = NSLocalizedString("intro_text4", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "Introduction text4")
        let introAttributedString4 = NSMutableAttributedString(string: introString4, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()!
        ])
        privacyAttributedString.append(introAttributedString4)
        privacyAttributedString.append(spacerAttributedString)

        let introString5 = NSLocalizedString("intro_text5", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "Introduction text5")
        let introAttributedString5 = NSMutableAttributedString(string: introString5, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()!
        ])
        privacyAttributedString.append(introAttributedString5)
        privacyAttributedString.append(spacerAttributedString)

        // What data is processed and stored? — Bundle string
        let whatTitle = NSLocalizedString("what_title", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "What title")
        let whatAttributedTitle = NSMutableAttributedString(string: whatTitle, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontBold()!
        ])
        privacyAttributedString.append(whatAttributedTitle)
        privacyAttributedString.append(spacerAttributedString)

        let whatSubtitle1 = NSLocalizedString("what_subTitle1", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "What sub-title1")
        let whatAttributedSubtitle1 = NSMutableAttributedString(string: whatSubtitle1, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontLight()!
        ])
        privacyAttributedString.append(whatAttributedSubtitle1)
        privacyAttributedString.append(spacerAttributedString)

        let whatString1a = NSLocalizedString("what_subText1a", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "what sub-text1a")
        let whatAttributedString1a = NSMutableAttributedString(string: whatString1a, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()!
        ])
        privacyAttributedString.append(whatAttributedString1a)
        privacyAttributedString.append(spacerAttributedString)

        let whatSubtitle2 = NSLocalizedString("what_subTitle2", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "What sub-title2")
        let whatAttributedSubtitle2 = NSMutableAttributedString(string: whatSubtitle2, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontLight()!
        ])
        privacyAttributedString.append(whatAttributedSubtitle2)
        privacyAttributedString.append(spacerAttributedString)

        let whatString2a = NSLocalizedString("what_subText2a", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "what sub-text2a")
        let whatAttributedString2a = NSMutableAttributedString(string: whatString2a, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()!
        ])
        privacyAttributedString.append(whatAttributedString2a)
        privacyAttributedString.append(spacerAttributedString)

        let whatSubtitle3 = NSLocalizedString("what_subTitle3", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "What sub-title3")
        let whatAttributedSubtitle3 = NSMutableAttributedString(string: whatSubtitle3, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontLight()!
        ])
        privacyAttributedString.append(whatAttributedSubtitle3)
        privacyAttributedString.append(spacerAttributedString)

        let whatString3a = NSLocalizedString("what_subText3a", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "what sub-text3a")
        let whatAttributedString3a = NSMutableAttributedString(string: whatString3a, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()!
        ])
        privacyAttributedString.append(whatAttributedString3a)
        privacyAttributedString.append(spacerAttributedString)

        let whatSubtitle4 = NSLocalizedString("what_subTitle4", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "What sub-title4")
        let whatAttributedSubtitle4 = NSMutableAttributedString(string: whatSubtitle4, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontLight()!
        ])
        privacyAttributedString.append(whatAttributedSubtitle4)
        privacyAttributedString.append(spacerAttributedString)

        let whatString4a = NSLocalizedString("what_subText4a", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "what sub-text4a")
        let whatAttributedString4a = NSMutableAttributedString(string: whatString4a, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()!
        ])
        privacyAttributedString.append(whatAttributedString4a)
        privacyAttributedString.append(spacerAttributedString)

        // Why does the mobile app store data? — Bundle string
        let whyTitle = NSLocalizedString("why_title", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "Why title")
        let whyAttributedTitle = NSMutableAttributedString(string: whyTitle, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontBold()!
        ])
        privacyAttributedString.append(whyAttributedTitle)
        privacyAttributedString.append(spacerAttributedString)

        let whyString1 = NSLocalizedString("why_text1", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "Why text1")
        let whyAttributedString1 = NSMutableAttributedString(string: whyString1, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()!
        ])
        privacyAttributedString.append(whyAttributedString1)
        privacyAttributedString.append(spacerAttributedString)

        let whyString2 = NSLocalizedString("why_text2", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "Why text2")
        let whyAttributedString2 = NSMutableAttributedString(string: whyString2, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()!
        ])
        privacyAttributedString.append(whyAttributedString2)
        privacyAttributedString.append(spacerAttributedString)

        // How is the data protected? — Bundle string
        let howTitle = NSLocalizedString("how_title", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "How title")
        let howAttributedTitle = NSMutableAttributedString(string: howTitle, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontBold()!
        ])
        privacyAttributedString.append(howAttributedTitle)
        privacyAttributedString.append(spacerAttributedString)

        let howString1 = NSLocalizedString("how_text1", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "How text1")
        let howAttributedString1 = NSMutableAttributedString(string: howString1, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()!
        ])
        privacyAttributedString.append(howAttributedString1)
        privacyAttributedString.append(spacerAttributedString)

        let howString2 = NSLocalizedString("how_text2", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "How text2")
        let howAttributedString2 = NSMutableAttributedString(string: howString2, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()!
        ])
        privacyAttributedString.append(howAttributedString2)
        privacyAttributedString.append(spacerAttributedString)

        // Security of your information — Bundle string
        let securityTitle = NSLocalizedString("security_title", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "Security title")
        let securityAttributedTitle = NSMutableAttributedString(string: securityTitle, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontBold()!
        ])
        privacyAttributedString.append(securityAttributedTitle)
        privacyAttributedString.append(spacerAttributedString)

        let securityString1 = NSLocalizedString("security_text", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "Security text")
        let securityAttributedString1 = NSMutableAttributedString(string: securityString1, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()!
        ])
        privacyAttributedString.append(securityAttributedString1)
        privacyAttributedString.append(spacerAttributedString)

        // Contact Us — Bundle string
        let contactTitle = NSLocalizedString("contact_title", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "Contact title")
        let contactAttributedTitle = NSMutableAttributedString(string: contactTitle, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontBold()!
        ])
        privacyAttributedString.append(contactAttributedTitle)
        privacyAttributedString.append(spacerAttributedString)

        let contactString1 = NSLocalizedString("contact_text", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "Contact text")
        let contactAttributedString1 = NSMutableAttributedString(string: contactString1, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()!
        ])
        privacyAttributedString.append(contactAttributedString1)
        privacyAttributedString.append(spacerAttributedString)

        let contactString2 = NSLocalizedString("contact_address", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "Contact address")
        let contactAttributedString2 = NSMutableAttributedString(string: contactString2, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()!
        ])
        privacyAttributedString.append(contactAttributedString2)
        privacyAttributedString.append(spacerAttributedString)

        let contactString3 = NSLocalizedString("contact_email", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "Contact email")
        let appVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let appBuildString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let subject = "\(NSLocalizedString("settings_appName", comment: "Piwigo Mobile")) \(appVersionString ?? "") (\(appBuildString ?? "")) — \(NSLocalizedString("settings_privacy", comment: "Policy Privacy"))".addingPercentEncoding(withAllowedCharacters: CharacterSet.urlPathAllowed)
        let mailTo = "mailto:\(contactString3)?subject=\(subject ?? "")"
        var contactAttributedString3: NSMutableAttributedString? = nil
        if let url = URL(string: mailTo) {
            contactAttributedString3 = NSMutableAttributedString(string: contactString3, attributes: [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()!,
            NSAttributedString.Key.link: url
        ])
        }
        if let contactAttributedString3 = contactAttributedString3 {
            privacyAttributedString.append(contactAttributedString3)
        }
        privacyAttributedString.append(spacerAttributedString)

        // Piwigo-Mobile URLs
        let noRange = NSRange.init(location: NSNotFound, length: 0)
        let iOS_URL = URL(string: "https://github.com/Piwigo/Piwigo-Mobile")
        var iOS_Range = (privacyAttributedString.string as NSString).range(of: "Piwigo-Mobile")
        while !NSEqualRanges(iOS_Range, noRange) {
            privacyAttributedString.addAttribute(.link, value: iOS_URL!, range: iOS_Range)
            let nextCharPos = iOS_Range.location + iOS_Range.length
            if nextCharPos >= privacyAttributedString.string.count {
                break
            }
            iOS_Range = (privacyAttributedString.string as NSString).range(of: "Piwigo-Mobile", options: .literal, range: NSRange(location: nextCharPos, length: privacyAttributedString.string.count - nextCharPos))
        }

        // Piwigo-Android URLs
        let Android_URL = URL(string: "https://github.com/Piwigo/Piwigo-Android")
        var Android_Range = (privacyAttributedString.string as NSString).range(of: "Piwigo-Android")
        while !NSEqualRanges(Android_Range, noRange) {
            privacyAttributedString.addAttribute(.link, value: Android_URL!, range: Android_Range)
            let nextCharPos = Android_Range.location + Android_Range.length
            if nextCharPos >= privacyAttributedString.string.count {
                break
            }
            Android_Range = (privacyAttributedString.string as NSString).range(of: "Piwigo-Android", options: .literal, range: NSRange(location: nextCharPos, length: privacyAttributedString.string.count - nextCharPos))
        }
        
        return privacyAttributedString
    }
}
