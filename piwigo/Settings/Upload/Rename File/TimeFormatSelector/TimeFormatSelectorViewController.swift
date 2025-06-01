//
//  TimeFormatSelectorViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

protocol SelectTimeFormatDelegate: NSObjectProtocol {
    func didSelectTimeFormat(_ format: String)
}

class TimeFormatSelectorViewController: UIViewController {
    
    enum TimeSection: Int {
        case hour
        case minute
        case second
        case separator
        case count
    }
    
    weak var delegate: SelectTimeFormatDelegate?
    
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var exampleLabel: RenameFileInfoLabel!
    @IBOutlet weak var tableView: UITableView!
    
    // Actions to be modified or not
    var startValue: Int = 1
    var prefixBeforeUpload = false
    var prefixActions: RenameActionList = []
    var replaceBeforeUpload = false
    var replaceActions: RenameActionList = []
    var suffixBeforeUpload = false
    var suffixActions: RenameActionList = []
    var changeCaseBeforeUpload = false
    var caseOfFileExtension: FileExtCase = .uppercase

    var timeFormats: [pwgTimeFormat] = []       // Should always contain all formats (hour, minute, second and separator)

    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Title, header and example
        title = NSLocalizedString("tabBar_upload", comment: "Upload")
        
        // Header
        let headerAttributedString = NSMutableAttributedString(string: "")
        let title = String(format: "%@\n", NSLocalizedString("editImageDetails_timeCreation", comment: "Creation Time"))
        let titleAttributedString = NSMutableAttributedString(string: title)
        titleAttributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 17, weight: .bold),
                                           range: NSRange(location: 0, length: title.count))
        headerAttributedString.append(titleAttributedString)
        let text = NSLocalizedString("settings_renameTimeHeader", comment: "Please select a time format…")
        let textAttributedString = NSMutableAttributedString(string: text)
        textAttributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 13),
                                          range: NSRange(location: 0, length: text.count))
        headerAttributedString.append(textAttributedString)
        headerLabel.attributedText = headerAttributedString
        headerLabel.sizeToFit()
        
        // Set colors, fonts, etc.
        applyColorPalette()
        
        // Enable/disable drag interactions
        navigationItem.rightBarButtonItem = editButtonItem
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
        
        // Update example shown in header
        updateExample()
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Update cell of parent view
        delegate?.didSelectTimeFormat(timeFormats.asString)
    }
    
    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - Time Format Utilities
    func indexPathsOfOptions(in section: Int) -> [IndexPath] {
        // Determine the current number of displayed options
        var nberOfOptions: Int = 0
        switch TimeSection(rawValue: section) {
        case .hour:
            nberOfOptions = pwgTimeFormat.Hour.allCases.count
        case .minute:
            nberOfOptions = pwgTimeFormat.Minute.allCases.count
        case .second:
            nberOfOptions = pwgTimeFormat.Second.allCases.count
        default:
            break
        }
        // Append indexPaths of rows showing options
        var indexPathsOfOptions: [IndexPath] = []
        for row in 1..<nberOfOptions {
            indexPathsOfOptions.append(IndexPath(row: row, section: section))
        }
        return indexPathsOfOptions
    }


    // MARK: - Time Format Update
    func updateExample() {
        // Look for the time format stored in default settings
        if let index = prefixActions.firstIndex(where: { $0.type == .addTime }) {
            var action = prefixActions[index]
            action.style = timeFormats.asString
            prefixActions[index] = action
        }
        else if let index = replaceActions.firstIndex(where: { $0.type == .addTime }) {
            var action = replaceActions[index]
            action.style = timeFormats.asString
            replaceActions[index] = action
        }
        else if let index = suffixActions.firstIndex(where: { $0.type == .addTime }) {
            var action = suffixActions[index]
            action.style = timeFormats.asString
            suffixActions[index] = action
        }

        // Update example shown in header
        exampleLabel?.updateExample(prefix: prefixBeforeUpload, prefixActions: prefixActions,
                                    replace: replaceBeforeUpload, replaceActions: replaceActions,
                                    suffix: suffixBeforeUpload, suffixActions: suffixActions,
                                    changeCase: changeCaseBeforeUpload, caseOfExtension: caseOfFileExtension,
                                    counter: startValue)
    }
}
