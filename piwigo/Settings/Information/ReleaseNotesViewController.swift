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
        authorsLabel.textColor = UIColor.piwigoColorText()
        versionLabel.textColor = UIColor.piwigoColorText()
        textView.textColor = UIColor.piwigoColorText()
        textView.backgroundColor = UIColor.piwigoColorBackground()
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
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette), name: name, object: nil)
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

    func updateAuthorsLabel () {
        // Piwigo authors
        let authors1 = NSLocalizedString("authors1", tableName: "About", bundle: Bundle.main, value: "", comment: "By Spencer Baker, Olaf Greck,")
        let authors2 = NSLocalizedString("authors2", tableName: "About", bundle: Bundle.main, value: "", comment: "and Eddy Lelièvre-Berna")
        
        // Change label according to orientation
        if ((UIDevice.current.userInterfaceIdiom == .phone) &&
            ((UIDevice.current.orientation != .landscapeLeft) && (UIDevice.current.orientation != .landscapeRight))) {
            // iPhone in portrait mode
            authorsLabel.text = "\(authors1)\r\(authors2)"
        }
        else {
            // iPhone in landscape mode, iPad in any orientation
            authorsLabel.text = "\(authors1) \(authors2)"
        }
    }

    @objc func quitSettings() {
        
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self)

        // Close Settings view
        dismiss(animated: true)
    }

    
// MARK: - Release Notes
    func notesAttributedString() -> NSMutableAttributedString? {
        // Release notes attributed string
        let notesAttributedString = NSMutableAttributedString(string: "")
        let spacerAttributedString = NSMutableAttributedString(string: "\n\n\n")
        let spacerRange = NSRange(location: 0, length: spacerAttributedString.length)
        spacerAttributedString.addAttribute(.font, value: UIFont.piwigoFontTiny(), range: spacerRange)

        // Release 2.5.1 — Bundle string
        let v251String = NSLocalizedString("v2.5.1_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.5.1 Release Notes text")
        let v251AttributedString = NSMutableAttributedString(string: v251String)
        var v251Range = NSRange(location: 0, length: v251String.count)
        v251AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v251Range)
        v251Range = NSRange(location: 0, length: (v251String as NSString).range(of: "\n").location)
        v251AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v251Range)
        notesAttributedString.append(v251AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.5 — Bundle string
        let v250String = NSLocalizedString("v2.5.0_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.5.0 Release Notes text")
        let v250AttributedString = NSMutableAttributedString(string: v250String)
        var v250Range = NSRange(location: 0, length: v250String.count)
        v250AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v250Range)
        v250Range = NSRange(location: 0, length: (v250String as NSString).range(of: "\n").location)
        v250AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v250Range)
        notesAttributedString.append(v250AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.4.8 — Bundle string
        let v248String = NSLocalizedString("v2.4.8_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.4.8 Release Notes text")
        let v248AttributedString = NSMutableAttributedString(string: v248String)
        var v248Range = NSRange(location: 0, length: v248String.count)
        v248AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v248Range)
        v248Range = NSRange(location: 0, length: (v248String as NSString).range(of: "\n").location)
        v248AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v248Range)
        notesAttributedString.append(v248AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.4.7 — Bundle string
        let v247String = NSLocalizedString("v2.4.7_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.4.7 Release Notes text")
        let v247AttributedString = NSMutableAttributedString(string: v247String)
        var v247Range = NSRange(location: 0, length: v247String.count)
        v247AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v247Range)
        v247Range = NSRange(location: 0, length: (v247String as NSString).range(of: "\n").location)
        v247AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v247Range)
        notesAttributedString.append(v247AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.4.6 — Bundle string
        let v246String = NSLocalizedString("v2.4.6_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.4.6 Release Notes text")
        let v246AttributedString = NSMutableAttributedString(string: v246String)
        var v246Range = NSRange(location: 0, length: v246String.count)
        v246AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v246Range)
        v246Range = NSRange(location: 0, length: (v246String as NSString).range(of: "\n").location)
        v246AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v246Range)
        notesAttributedString.append(v246AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.4.5 — Bundle string
        let v245String = NSLocalizedString("v2.4.5_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.4.5 Release Notes text")
        let v245AttributedString = NSMutableAttributedString(string: v245String)
        var v245Range = NSRange(location: 0, length: v245String.count)
        v245AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v245Range)
        v245Range = NSRange(location: 0, length: (v245String as NSString).range(of: "\n").location)
        v245AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v245Range)
        notesAttributedString.append(v245AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.4.4 — Bundle string
        let v244String = NSLocalizedString("v2.4.4_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.4.4 Release Notes text")
        let v244AttributedString = NSMutableAttributedString(string: v244String)
        var v244Range = NSRange(location: 0, length: v244String.count)
        v244AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v244Range)
        v244Range = NSRange(location: 0, length: (v244String as NSString).range(of: "\n").location)
        v244AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v244Range)
        notesAttributedString.append(v244AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.4.3 — Bundle string
        let v243String = NSLocalizedString("v2.4.3_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.4.3 Release Notes text")
        let v243AttributedString = NSMutableAttributedString(string: v243String)
        var v243Range = NSRange(location: 0, length: v243String.count)
        v243AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v243Range)
        v243Range = NSRange(location: 0, length: (v243String as NSString).range(of: "\n").location)
        v243AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v243Range)
        notesAttributedString.append(v243AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.4.2 — Bundle string
        let v242String = NSLocalizedString("v2.4.2_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.4.2 Release Notes text")
        let v242AttributedString = NSMutableAttributedString(string: v242String)
        var v242Range = NSRange(location: 0, length: v242String.count)
        v242AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v242Range)
        v242Range = NSRange(location: 0, length: (v242String as NSString).range(of: "\n").location)
        v242AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v242Range)
        notesAttributedString.append(v242AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.4.1 — Bundle string
        let v241String = NSLocalizedString("v2.4.1_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.4.1 Release Notes text")
        let v241AttributedString = NSMutableAttributedString(string: v241String)
        var v241Range = NSRange(location: 0, length: v241String.count)
        v241AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v241Range)
        v241Range = NSRange(location: 0, length: (v241String as NSString).range(of: "\n").location)
        v241AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v241Range)
        notesAttributedString.append(v241AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.4 — Bundle string
        let v240String = NSLocalizedString("v2.4.0_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.4.0 Release Notes text")
        let v240AttributedString = NSMutableAttributedString(string: v240String)
        var v240Range = NSRange(location: 0, length: v240String.count)
        v240AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v240Range)
        v240Range = NSRange(location: 0, length: (v240String as NSString).range(of: "\n").location)
        v240AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v240Range)
        notesAttributedString.append(v240AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.3.5 — Bundle string
        let v235String = NSLocalizedString("v2.3.5_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.3.5 Release Notes text")
        let v235AttributedString = NSMutableAttributedString(string: v235String)
        var v235Range = NSRange(location: 0, length: v235String.count)
        v235AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v235Range)
        v235Range = NSRange(location: 0, length: (v235String as NSString).range(of: "\n").location)
        v235AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v235Range)
        notesAttributedString.append(v235AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.3.4 — Bundle string
        let v234String = NSLocalizedString("v2.3.4_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.3.4 Release Notes text")
        let v234AttributedString = NSMutableAttributedString(string: v234String)
        var v234Range = NSRange(location: 0, length: v234String.count)
        v234AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v234Range)
        v234Range = NSRange(location: 0, length: (v234String as NSString).range(of: "\n").location)
        v234AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v234Range)
        notesAttributedString.append(v234AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.3.3 — Bundle string
        let v233String = NSLocalizedString("v2.3.3_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.3.3 Release Notes text")
        let v233AttributedString = NSMutableAttributedString(string: v233String)
        var v233Range = NSRange(location: 0, length: v233String.count)
        v233AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v233Range)
        v233Range = NSRange(location: 0, length: (v233String as NSString).range(of: "\n").location)
        v233AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v233Range)
        notesAttributedString.append(v233AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.3.2 — Bundle string
        let v232String = NSLocalizedString("v2.3.2_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.3.2 Release Notes text")
        let v232AttributedString = NSMutableAttributedString(string: v232String)
        var v232Range = NSRange(location: 0, length: v232String.count)
        v232AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v232Range)
        v232Range = NSRange(location: 0, length: (v232String as NSString).range(of: "\n").location)
        v232AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v232Range)
        notesAttributedString.append(v232AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.3.1 — Bundle string
        let v231String = NSLocalizedString("v2.3.1_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.3.1 Release Notes text")
        let v231AttributedString = NSMutableAttributedString(string: v231String)
        var v231Range = NSRange(location: 0, length: v231String.count)
        v231AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v231Range)
        v231Range = NSRange(location: 0, length: (v231String as NSString).range(of: "\n").location)
        v231AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v231Range)
        notesAttributedString.append(v231AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.3 — Bundle string
        let v230String = NSLocalizedString("v2.3.0_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.3.0 Release Notes text")
        let v230AttributedString = NSMutableAttributedString(string: v230String)
        var v230Range = NSRange(location: 0, length: v230String.count)
        v230AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v230Range)
        v230Range = NSRange(location: 0, length: (v230String as NSString).range(of: "\n").location)
        v230AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v230Range)
        notesAttributedString.append(v230AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.2.7 — Bundle string
        let v227String = NSLocalizedString("v2.2.7_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.2.7 Release Notes text")
        let v227AttributedString = NSMutableAttributedString(string: v227String)
        var v227Range = NSRange(location: 0, length: v227String.count)
        v227AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v227Range)
        v227Range = NSRange(location: 0, length: (v227String as NSString).range(of: "\n").location)
        v227AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v227Range)
        notesAttributedString.append(v227AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.2.6 — Bundle string
        let v226String = NSLocalizedString("v2.2.6_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.2.6 Release Notes text")
        let v226AttributedString = NSMutableAttributedString(string: v226String)
        var v226Range = NSRange(location: 0, length: v226String.count)
        v226AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v226Range)
        v226Range = NSRange(location: 0, length: (v226String as NSString).range(of: "\n").location)
        v226AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v226Range)
        notesAttributedString.append(v226AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.2.5 — Bundle string
        let v225String = NSLocalizedString("v2.2.5_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.2.5 Release Notes text")
        let v225AttributedString = NSMutableAttributedString(string: v225String)
        var v225Range = NSRange(location: 0, length: v225String.count)
        v225AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v225Range)
        v225Range = NSRange(location: 0, length: (v225String as NSString).range(of: "\n").location)
        v225AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v225Range)
        notesAttributedString.append(v225AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.2.4 — Bundle string
        let v224String = NSLocalizedString("v2.2.4_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.2.4 Release Notes text")
        let v224AttributedString = NSMutableAttributedString(string: v224String)
        var v224Range = NSRange(location: 0, length: v224String.count)
        v224AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v224Range)
        v224Range = NSRange(location: 0, length: (v224String as NSString).range(of: "\n").location)
        v224AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v224Range)
        notesAttributedString.append(v224AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.2.3 — Bundle string
        let v223String = NSLocalizedString("v2.2.3_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.2.3 Release Notes text")
        let v223AttributedString = NSMutableAttributedString(string: v223String)
        var v223Range = NSRange(location: 0, length: v223String.count)
        v223AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v223Range)
        v223Range = NSRange(location: 0, length: (v223String as NSString).range(of: "\n").location)
        v223AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v223Range)
        notesAttributedString.append(v223AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.2.2 — Bundle string
        let v222String = NSLocalizedString("v2.2.2_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.2.2 Release Notes text")
        let v222AttributedString = NSMutableAttributedString(string: v222String)
        var v222Range = NSRange(location: 0, length: v222String.count)
        v222AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v222Range)
        v222Range = NSRange(location: 0, length: (v222String as NSString).range(of: "\n").location)
        v222AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v222Range)
        notesAttributedString.append(v222AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.2.1 — Bundle string
        let v221String = NSLocalizedString("v2.2.1_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.2.1 Release Notes text")
        let v221AttributedString = NSMutableAttributedString(string: v221String)
        var v221Range = NSRange(location: 0, length: v221String.count)
        v221AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v221Range)
        v221Range = NSRange(location: 0, length: (v221String as NSString).range(of: "\n").location)
        v221AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v221Range)
        notesAttributedString.append(v221AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.2.0 — Bundle string
        let v220String = NSLocalizedString("v2.2.0_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.2.0 Release Notes text")
        let v220AttributedString = NSMutableAttributedString(string: v220String)
        var v220Range = NSRange(location: 0, length: v220String.count)
        v220AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v220Range)
        v220Range = NSRange(location: 0, length: (v220String as NSString).range(of: "\n").location)
        v220AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v220Range)
        notesAttributedString.append(v220AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.1.9 — Bundle string
        let v219String = NSLocalizedString("v2.1.9_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.1.9 Release Notes text")
        let v219AttributedString = NSMutableAttributedString(string: v219String)
        var v219Range = NSRange(location: 0, length: v219String.count)
        v219AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v219Range)
        v219Range = NSRange(location: 0, length: (v219String as NSString).range(of: "\n").location)
        v219AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v219Range)
        notesAttributedString.append(v219AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.1.8 — Bundle string
        let v218String = NSLocalizedString("v2.1.8_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.1.8 Release Notes text")
        let v218AttributedString = NSMutableAttributedString(string: v218String)
        var v218Range = NSRange(location: 0, length: v218String.count)
        v218AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v218Range)
        v218Range = NSRange(location: 0, length: (v218String as NSString).range(of: "\n").location)
        v218AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v218Range)
        notesAttributedString.append(v218AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.1.7 — Bundle string
        let v217String = NSLocalizedString("v2.1.7_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.1.7 Release Notes text")
        let v217AttributedString = NSMutableAttributedString(string: v217String)
        var v217Range = NSRange(location: 0, length: v217String.count)
        v217AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v217Range)
        v217Range = NSRange(location: 0, length: (v217String as NSString).range(of: "\n").location)
        v217AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v217Range)
        notesAttributedString.append(v217AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.1.6 — Bundle string
        let v216String = NSLocalizedString("v2.1.6_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.1.6 Release Notes text")
        let v216AttributedString = NSMutableAttributedString(string: v216String)
        var v216Range = NSRange(location: 0, length: v216String.count)
        v216AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v216Range)
        v216Range = NSRange(location: 0, length: (v216String as NSString).range(of: "\n").location)
        v216AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v216Range)
        notesAttributedString.append(v216AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.1.5 — Bundle string
        let v215String = NSLocalizedString("v2.1.5_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.1.5 Release Notes text")
        let v215AttributedString = NSMutableAttributedString(string: v215String)
        var v215Range = NSRange(location: 0, length: v215String.count)
        v215AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v215Range)
        v215Range = NSRange(location: 0, length: (v215String as NSString).range(of: "\n").location)
        v215AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v215Range)
        notesAttributedString.append(v215AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.1.4 — Bundle string
        let v214String = NSLocalizedString("v2.1.4_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.1.4 Release Notes text")
        let v214AttributedString = NSMutableAttributedString(string: v214String)
        var v214Range = NSRange(location: 0, length: v214String.count)
        v214AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v214Range)
        v214Range = NSRange(location: 0, length: (v214String as NSString).range(of: "\n").location)
        v214AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v214Range)
        notesAttributedString.append(v214AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.1.3 — Bundle string
        let v213String = NSLocalizedString("v2.1.3_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.1.3 Release Notes text")
        let v213AttributedString = NSMutableAttributedString(string: v213String)
        var v213Range = NSRange(location: 0, length: v213String.count)
        v213AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v213Range)
        v213Range = NSRange(location: 0, length: (v213String as NSString).range(of: "\n").location)
        v213AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v213Range)
        notesAttributedString.append(v213AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.1.2 — Bundle string
        let v212String = NSLocalizedString("v2.1.2_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.1.2 Release Notes text")
        let v212AttributedString = NSMutableAttributedString(string: v212String)
        var v212Range = NSRange(location: 0, length: v212String.count)
        v212AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v212Range)
        v212Range = NSRange(location: 0, length: (v212String as NSString).range(of: "\n").location)
        v212AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v212Range)
        notesAttributedString.append(v212AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.1.1 — Bundle string
        let v211String = NSLocalizedString("v2.1.1_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.1.1 Release Notes text")
        let v211AttributedString = NSMutableAttributedString(string: v211String)
        var v211Range = NSRange(location: 0, length: v211String.count)
        v211AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v211Range)
        v211Range = NSRange(location: 0, length: (v211String as NSString).range(of: "\n").location)
        v211AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v211Range)
        notesAttributedString.append(v211AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.1.0 — Bundle string
        let v210String = NSLocalizedString("v2.1.0_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.1.0 Release Notes text")
        let v210AttributedString = NSMutableAttributedString(string: v210String)
        var v210Range = NSRange(location: 0, length: v210String.count)
        v210AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v210Range)
        v210Range = NSRange(location: 0, length: (v210String as NSString).range(of: "\n").location)
        v210AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v210Range)
        notesAttributedString.append(v210AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.0.4 — Bundle string
        let v204String = NSLocalizedString("v2.0.4_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.0.4 Release Notes text")
        let v204AttributedString = NSMutableAttributedString(string: v204String)
        var v204Range = NSRange(location: 0, length: v204String.count)
        v204AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v204Range)
        v204Range = NSRange(location: 0, length: (v204String as NSString).range(of: "\n").location)
        v204AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v204Range)
        notesAttributedString.append(v204AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.0.3 — Bundle string
        let v203String = NSLocalizedString("v2.0.3_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.0.3 Release Notes text")
        let v203AttributedString = NSMutableAttributedString(string: v203String)
        var v203Range = NSRange(location: 0, length: v203String.count)
        v203AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v203Range)
        v203Range = NSRange(location: 0, length: (v203String as NSString).range(of: "\n").location)
        v203AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v203Range)
        notesAttributedString.append(v203AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.0.2 — Bundle string
        let v202String = NSLocalizedString("v2.0.2_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.0.2 Release Notes text")
        let v202AttributedString = NSMutableAttributedString(string: v202String)
        var v202Range = NSRange(location: 0, length: v202String.count)
        v202AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v202Range)
        v202Range = NSRange(location: 0, length: (v202String as NSString).range(of: "\n").location)
        v202AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v202Range)
        notesAttributedString.append(v202AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.0.1 — Bundle string
        let v201String = NSLocalizedString("v2.0.1_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.0.1 Release Notes text")
        let v201AttributedString = NSMutableAttributedString(string: v201String)
        var v201Range = NSRange(location: 0, length: v201String.count)
        v201AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v201Range)
        v201Range = NSRange(location: 0, length: (v201String as NSString).range(of: "\n").location)
        v201AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v201Range)
        notesAttributedString.append(v201AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 2.0.0 — Bundle string
        let v200String = NSLocalizedString("v2.0.0_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v2.0.0 Release Notes text")
        let v200AttributedString = NSMutableAttributedString(string: v200String)
        var v200Range = NSRange(location: 0, length: v200String.count)
        v200AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v200Range)
        v200Range = NSRange(location: 0, length: (v200String as NSString).range(of: "\n").location)
        v200AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v200Range)
        notesAttributedString.append(v200AttributedString)
        notesAttributedString.append(spacerAttributedString)

        // Release 1.0.0 — Bundle string
        let v100String = NSLocalizedString("v1.0.0_text", tableName: "ReleaseNotes", bundle: Bundle.main, value: "", comment: "v1.0.0 Release Notes text")
        let v100AttributedString = NSMutableAttributedString(string: v100String)
        var v100Range = NSRange(location: 0, length: v100String.count)
        v100AttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: v100Range)
        v100Range = NSRange(location: 0, length: (v100String as NSString).range(of: "\n").location)
        v100AttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: v100Range)
        notesAttributedString.append(v100AttributedString)

        return notesAttributedString
    }
}
