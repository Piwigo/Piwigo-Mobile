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
    func didSelectCounter(currentCounter: Int64, format: String)
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
    
    // Actions to be modified or not
    var prefixBeforeUpload = false
    var prefixActions: RenameActionList = []
    var replaceBeforeUpload = false
    var replaceActions: RenameActionList = []
    var suffixBeforeUpload = false
    var suffixActions: RenameActionList = []
    var changeCaseBeforeUpload = false
    var caseOfFileExtension: FileExtCase = .uppercase

    // Used to display the album ID (unset by SettingsViewController)
    var categoryId: Int32 = 69

    var currentCounter: Int64 = UploadVars.shared.categoryCounterInit
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
        
        // Set colors, fonts, etc.
        applyColorPalette()
    }
    
    @MainActor
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = PwgColor.background
        
        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: PwgColor.whiteCream,
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.barTintColor = PwgColor.background
        navigationController?.navigationBar.backgroundColor = PwgColor.background
        if #available(iOS 26.0, *) {
            navigationController?.navigationBar.tintColor = PwgColor.gray
        } else {
            navigationController?.navigationBar.tintColor = PwgColor.orange
        }

        /// In iOS 15, UIKit has extended the usage of the scrollEdgeAppearance,
        /// which by default produces a transparent background, to all navigation bars.
        let barAppearance = UINavigationBarAppearance()
        barAppearance.configureWithOpaqueBackground()
        barAppearance.backgroundColor = PwgColor.background
        navigationController?.navigationBar.standardAppearance = barAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance
        
        // Header and example
        headerLabel.textColor = PwgColor.header
        exampleLabel.textColor = PwgColor.text
        
        // Table view
        tableView.separatorColor = PwgColor.separator
        tableView.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Update example shown in header
        updateExample()
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Update cell of parent view
        delegate?.didSelectCounter(currentCounter: currentCounter, format: counterFormats.asString)
    }
    
    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - Counter Format Update
    func updateExample() {
        // Look for the counter format stored in default settings
        if let index = prefixActions.firstIndex(where: { $0.type == .addCounter }) {
            var action = prefixActions[index]
            action.style = counterFormats.asString
            prefixActions[index] = action
        }
        else if let index = replaceActions.firstIndex(where: { $0.type == .addCounter }) {
            var action = replaceActions[index]
            action.style = counterFormats.asString
            replaceActions[index] = action
        }
        else if let index = suffixActions.firstIndex(where: { $0.type == .addCounter }) {
            var action = suffixActions[index]
            action.style = counterFormats.asString
            suffixActions[index] = action
        }

        // Update example shown in header
        exampleLabel?.updateExample(prefix: prefixBeforeUpload, prefixActions: prefixActions,
                                    replace: replaceBeforeUpload, replaceActions: replaceActions,
                                    suffix: suffixBeforeUpload, suffixActions: suffixActions,
                                    changeCase: changeCaseBeforeUpload, caseOfExtension: caseOfFileExtension,
                                    categoryId: categoryId, counter: currentCounter)
    }
}
