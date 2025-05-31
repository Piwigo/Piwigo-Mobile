//
//  CounterFormatSelectorViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 30/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

protocol SelectCounterFormatDelegate: NSObjectProtocol {
    func didSelectCounterFormat(_ format: String)
}

class CounterFormatSelectorViewController: UIViewController {
    
    enum CounterSection: Int {
        case start
        case prefix
        case digits
        case suffix
        case count
    }
    
    weak var delegate: SelectCounterFormatDelegate?
    
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var exampleLabel: RenameFileInfoLabel!
    @IBOutlet weak var tableView: UITableView!
    
    var renameSection: RenameSection!               // To remember which section to update
    var counterFormats: [pwgCounterFormat] = []     // Should always contain all formats (prefix, digits and suffix)
    
    // Tell which cell triggered the keyboard appearance
    var editedRow: IndexPath?

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Title, header and example
        title = NSLocalizedString("tabBar_upload", comment: "Upload")
        
        // Header
        let headerAttributedString = NSMutableAttributedString(string: "")
        let title = String(format: "%@\n", NSLocalizedString("Counter", comment: "Counter"))
        let titleAttributedString = NSMutableAttributedString(string: title)
        titleAttributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 17, weight: .bold),
                                           range: NSRange(location: 0, length: title.count))
        headerAttributedString.append(titleAttributedString)
        let text = NSLocalizedString("settings_renameCounterHeader", comment: "Please select a counter format…")
        let textAttributedString = NSMutableAttributedString(string: text)
        textAttributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 13),
                                          range: NSRange(location: 0, length: text.count))
        headerAttributedString.append(textAttributedString)
        headerLabel.attributedText = headerAttributedString
        headerLabel.sizeToFit()
        
        // Example
        exampleLabel.updateExample()
        
        // Set colors, fonts, etc.
        applyColorPalette()
    }
    
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = .piwigoColorBackground()
        
        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes
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
        
        // Header and example
        headerLabel.textColor = .piwigoColorHeader()
        exampleLabel.textColor = .piwigoColorText()
        
        // Table view
        tableView.separatorColor = .piwigoColorSeparator()
        tableView.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super .viewDidDisappear(animated)
        
        // Update cell of parent view
        delegate?.didSelectCounterFormat(counterFormats.asString)
    }
    
    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - Counter Format Update
    func updateSettings() {
        // Update settings
        switch renameSection {
        case .prefix:
            var prefixActions = UploadVars.shared.prefixFileNameActionList.actions
            if let index = prefixActions.firstIndex(where: { $0.type == .addCounter }) {
                prefixActions[index].style = counterFormats.asString
                UploadVars.shared.prefixFileNameActionList = prefixActions.encodedString
            }
        case .replace:
            var replaceActions = UploadVars.shared.replaceFileNameActionList.actions
            if let index = replaceActions.firstIndex(where: { $0.type == .addCounter }) {
                replaceActions[index].style = counterFormats.asString
                UploadVars.shared.replaceFileNameActionList = replaceActions.encodedString
            }
        case .suffix:
            var suffixActions = UploadVars.shared.suffixFileNameActionList.actions
            if let index = suffixActions.firstIndex(where: { $0.type == .addCounter }) {
                suffixActions[index].style = counterFormats.asString
                UploadVars.shared.suffixFileNameActionList = suffixActions.encodedString
            }
        default:
            break
        }
        
        // Update example
        updateExample()
    }

    func updateExample() {
        exampleLabel.updateExample()
    }
}
