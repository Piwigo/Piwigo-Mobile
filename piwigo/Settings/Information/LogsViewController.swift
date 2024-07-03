//
//  LogsViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 30/06/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import OSLog
import UIKit
import piwigoKit

@available(iOS 15.0, *)
class LogsViewController: UIViewController {
    
    @IBOutlet weak var category: UILabel!
    @IBOutlet weak var dateTime: UILabel!
    @IBOutlet weak var messages: UITextView!
    
    var logEntries = [OSLogEntryLog]()
    private var fixTextPositionAfterLoadingViewOnPad: Bool!
    private var shareBarButton: UIBarButtonItem?
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("settings_logs", comment: "Logs")
        
        // Initialise content
        if logEntries.isEmpty { return }
        category?.text = logEntries.first?.category
        dateTime?.text = DateUtilities.dateFormatter.string(from: logEntries.first?.date ?? Date())
        messages?.text = logEntries.map({"•" + $0.composedMessage + "\n"}).reduce("", +)
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
        
        /// In iOS 15, UIKit has extended the usage of the scrollEdgeAppearance,
        /// which by default produces a transparent background, to all navigation bars.
        let barAppearance = UINavigationBarAppearance()
        barAppearance.configureWithOpaqueBackground()
        barAppearance.backgroundColor = .piwigoColorBackground()
        navigationController?.navigationBar.standardAppearance = barAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance
        
        // Text color depdending on background color
        category?.textColor = .piwigoColorText()
        dateTime?.textColor = .piwigoColorText()
        messages?.textColor = .piwigoColorText()
        messages?.backgroundColor = .piwigoColorBackground()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Release notes
        fixTextPositionAfterLoadingViewOnPad = true
        messages?.scrollsToTop = true
        messages?.contentInsetAdjustmentBehavior = .never
        
        // Set colors, fonts, etc.
        applyColorPalette()
        
        // Set navigation buttons
        shareBarButton = UIBarButtonItem.shareImageButton(self, action: #selector(shareLogs))
        navigationItem.setRightBarButtonItems([shareBarButton].compactMap { $0 }, animated: true)
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }
    
    override func viewDidLayoutSubviews() {
        if (fixTextPositionAfterLoadingViewOnPad) {
            // Scroll text to where it is expected to be after loading view
            fixTextPositionAfterLoadingViewOnPad = false
            messages?.setContentOffset(.zero, animated: false)
        }
    }
    
    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - Share Logs
    @objc func shareLogs() {
        // Disable buttons during action
        shareBarButton?.isEnabled = false
        
        // Share logs
        let items = [self]
        let ac = UIActivityViewController(activityItems: items, applicationActivities: nil)
        present(ac, animated: true) {
            self.shareBarButton?.isEnabled = true
        }
    }
}


// MARK: - UIActivityItemSource
@available(iOS 15.0, *)
extension LogsViewController: UIActivityItemSource
{
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        // No needd to put a long string here, only to determine that we want to share a string.
        return "A string"
    }

    func activityViewController(_ activityViewController: UIActivityViewController, 
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        switch activityType {
        case .airDrop, .copyToPasteboard, .message:
            return messages?.text ?? ""
        case .mail, .print:
            fallthrough
        default:
            // Collect version and build numbers
            let appVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            let appBuildString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

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
            content += messages?.text ?? ""
            return content
        }
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, 
                                subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        var subject = NSLocalizedString("settings_appName", comment: "Piwigo Mobile")
        subject += " - " + NSLocalizedString("settings_logs", comment: "Logs")
        return subject
    }
}

