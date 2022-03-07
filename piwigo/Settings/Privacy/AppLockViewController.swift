//
//  AppLockViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/03/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

class AppLockViewController: UIViewController {
    
    @IBOutlet weak var infoTextView: UITextView!
    @IBOutlet weak var infoTextViewHeight: NSLayoutConstraint!
    @IBOutlet weak var infoTextViewOffset: NSLayoutConstraint!
    
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("settingsHeader_privacy", comment: "Privacy")
        
        // App Lock Info
        infoTextView.text = NSLocalizedString("settings_appLockInfo", comment: "With App Lock, ...")

        // Calculate the available width
        var safeAreaWidth = CGFloat.zero
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            safeAreaWidth = navigationController?.navigationBar.frame.width ?? CGFloat.zero
            break
        case .phone:
            guard let root = UIApplication.shared.keyWindow?.rootViewController else { return }
            safeAreaWidth = view.frame.size.width
            if #available(iOS 11.0, *) {
                safeAreaWidth -= root.view.safeAreaInsets.left + root.view.safeAreaInsets.right
            }
        default:
            break
        }
        
        // Calculate the required height of the App Lock info
        /// The minimum width of a screen is of 320 pixels.
        /// See https://developer.apple.com/design/human-interface-guidelines/ios/visual-design/adaptivity-and-layout/
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let margin: CGFloat =  15.0, minWidth: CGFloat = 320.0 - 2 * margin
        let maxWidth = CGFloat(fmax(safeAreaWidth - 2.0*margin, minWidth))
        let widthConstraint: CGSize = CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude)
        let attributes = [NSAttributedString.Key.font: infoTextView.font!]
        let height = infoTextView.text?.boundingRect(with: widthConstraint, options: .usesLineFragmentOrigin,
                                                   attributes: attributes, context: context).height
        infoTextViewHeight.constant = height ?? CGFloat(70)
        infoTextViewOffset.constant = CGFloat.zero
    }

    @objc func applyColorPalette() {
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
        
        // Infos
        infoTextView.textColor = UIColor.piwigoColorText()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: PwgNotifications.paletteChanged, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super .viewWillDisappear(animated)

        // Update cell of parent view
//        delegate?.didSelectPrivacyLevel(privacy)
    }

    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: PwgNotifications.paletteChanged, object: nil)
    }
}
