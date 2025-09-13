//
//  JsonViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 30/06/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

class JsonViewController: UIViewController {
    
    @IBOutlet weak var method: UILabel!
    @IBOutlet weak var dateTime: UILabel!
    @IBOutlet weak var fileContent: UITextView!
    var fileURL: URL?
    private var fixTextPositionAfterLoadingViewOnPad: Bool!
    private var shareBarButton: UIBarButtonItem?

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Title
        title = NSLocalizedString("settings_JSONinvalid", comment: "Invalid JSON data")

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
        let msg = String(decoding: content ?? Data(), as: UTF8.self)
        let attributedMsg = NSMutableAttributedString(string: msg)
        let wholeRange = NSRange(location: 0, length: msg.count)
        let style = NSMutableParagraphStyle()
        style.alignment = NSTextAlignment.left
        style.lineSpacing = 0
        style.paragraphSpacing = 9
        let attributes = [
            NSAttributedString.Key.foregroundColor: PwgColor.header,
            NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .footnote),
            NSAttributedString.Key.paragraphStyle: style
        ]
        attributedMsg.addAttributes(attributes, range: wholeRange)
        fileContent?.attributedText = attributedMsg
    }
    
    @MainActor
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = PwgColor.background
        
        // Navigation bar
        navigationController?.navigationBar.configAppearance(withLargeTitles: false)

        // Text color depdending on background color
        method?.textColor = PwgColor.text
        dateTime?.textColor = PwgColor.text
        fileContent?.textColor = PwgColor.text
        fileContent?.backgroundColor = PwgColor.background
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Release notes
        fixTextPositionAfterLoadingViewOnPad = true
        fileContent?.scrollsToTop = true
        fileContent?.contentInsetAdjustmentBehavior = .never
        
        // Set colors, fonts, etc.
        applyColorPalette()
        
        // Set navigation buttons
        shareBarButton = UIBarButtonItem.shareImageButton(self, action: #selector(shareJSONdata))
        navigationItem.setRightBarButtonItems([shareBarButton].compactMap { $0 }, animated: true)

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }
    
    override func viewDidLayoutSubviews() {
        // Scroll text to where it is expected to be after loading view
        if (fixTextPositionAfterLoadingViewOnPad) {
            fixTextPositionAfterLoadingViewOnPad = false
            fileContent?.setContentOffset(.zero, animated: false)
        }

        // Navigation bar
        navigationController?.navigationBar.prefersLargeTitles = false
    }
    
    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - Mail File
    @objc private func shareJSONdata() {
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
extension JsonViewController: UIActivityItemSource
{
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        // No needd to put a long string here, only to determine that we want to share a string.
        return "A string"
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        switch activityType {
        case .airDrop, .copyToPasteboard, .message:
            return fileContent?.text ?? ""
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
            content += fileContent?.text ?? ""
            return content
        }
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController,
                                subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        var subject = NSLocalizedString("settings_appName", comment: "Piwigo Mobile")
        subject += " - " + (method?.text ?? "?")
        return subject
    }
}
