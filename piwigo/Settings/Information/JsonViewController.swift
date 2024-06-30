//
//  JsonViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 30/06/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import MessageUI
import UIKit
import piwigoKit

class JsonViewController: UIViewController {
    
    @IBOutlet weak var method: UILabel!
    @IBOutlet weak var dateTime: UILabel!
    @IBOutlet weak var fileContent: UITextView!
    var fileURL: URL?
    private var fixTextPositionAfterLoadingViewOnPad: Bool!
    private var mailBarButton: UIBarButtonItem?

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("error_logs", comment: "Error Logs")
        
        // Initialise content
        guard let fileURL = fileURL else { return }
        let prefixCount = JSONprefix.count
        let suffixCount = JSONextension.count
        let fileName = String(fileURL.lastPathComponent.dropFirst(prefixCount).dropLast(suffixCount))
        if let pos = fileName.lastIndex(of: " ") {
            method?.text = String(fileName[pos...].dropFirst())
            dateTime?.text = String(fileName[...pos]) + " | " + fileURL.fileSizeString
        } else {
            method?.text = fileName
            dateTime?.text = fileURL.fileSizeString
        }
        let content = try? Data(contentsOf: fileURL, options: .alwaysMapped)
        fileContent.text = String(decoding: content ?? Data(), as: UTF8.self)

        // Button for sending file content by mail
        mailBarButton = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(mailFile))
        mailBarButton?.accessibilityIdentifier = "mailFile"
    }
    
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = .piwigoColorBackground()
        
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
        method.textColor = .piwigoColorText()
        dateTime.textColor = .piwigoColorText()
        fileContent.textColor = .piwigoColorText()
        fileContent.backgroundColor = .piwigoColorBackground()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Release notes
        fixTextPositionAfterLoadingViewOnPad = true
        fileContent.scrollsToTop = true
        fileContent.contentInsetAdjustmentBehavior = .never
        
        // Set colors, fonts, etc.
        applyColorPalette()
        
        // Set navigation buttons
        navigationItem.setRightBarButtonItems([mailBarButton].compactMap { $0 }, animated: true)
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }
    
    override func viewDidLayoutSubviews() {
        if (fixTextPositionAfterLoadingViewOnPad) {
            // Scroll text to where it is expected to be after loading view
            fixTextPositionAfterLoadingViewOnPad = false
            fileContent.setContentOffset(.zero, animated: false)
        }
    }
    
    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - Mail File
    @objc private func mailFile() {
        if MFMailComposeViewController.canSendMail() {
            let composeVC = MFMailComposeViewController()
            composeVC.mailComposeDelegate = self

            // Collect version and build numbers
            let appVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            let appBuildString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

            // Set subject
            var subject = "[" + NSLocalizedString("settings_appName", comment: "Piwigo Mobile") + "]: "
            subject += method.text ?? "?"
            composeVC.setSubject(subject)

            // Collect system and device data
            let deviceModel = UIDevice.current.modelName
            let deviceOS = UIDevice.current.systemName
            let deviceOSversion = UIDevice.current.systemVersion

            // Set message body
            var content = NSLocalizedString("settings_appName", comment: "Piwigo Mobile")
            content += " " + (appVersionString ?? "") + " (" + (appBuildString ?? "") + ")\n"
            content += deviceModel + " — " + deviceOS + " " + deviceOSversion + "\n"
            content += (dateTime.text ?? "?") + "\n"
            content += "\n"
            content += fileContent.text ?? ""
            composeVC.setMessageBody(content, isHTML: false)

            // Present the view controller modally.
            present(composeVC, animated: true)
        }
    }
}


// MARK: - MFMailComposeViewControllerDelegate
extension JsonViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        // Check the result or perform other tasks.

        // Dismiss the mail compose view controller.
        dismiss(animated: true)
    }
}
