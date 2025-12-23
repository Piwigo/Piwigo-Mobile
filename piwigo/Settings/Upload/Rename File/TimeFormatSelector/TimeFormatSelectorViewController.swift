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
    
    weak var delegate: (any SelectTimeFormatDelegate)?
    
    @IBOutlet weak var tableView: UITableView!
    
    // Actions to be modified or not
    var currentCounter: Int64 = UploadVars.shared.categoryCounterInit
    var prefixBeforeUpload = false
    var prefixActions: RenameActionList = []
    var replaceBeforeUpload = false
    var replaceActions: RenameActionList = []
    var suffixBeforeUpload = false
    var suffixActions: RenameActionList = []
    var changeCaseBeforeUpload = false
    var caseOfFileExtension: FileExtCase = .keep

    // Used to display the album ID (unset by SettingsViewController)
    var categoryId: Int32 = 69

    var timeFormats: [pwgTimeFormat] = []       // Should always contain all formats (hour, minute, second and separator)

    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Title, header and example
        title = NSLocalizedString("tabBar_upload", comment: "Upload")

        // Table view
        tableView?.accessibilityIdentifier = "Time Format Settings"
        tableView?.rowHeight = UITableView.automaticDimension
        tableView?.estimatedRowHeight = TableViewUtilities.rowHeight

        // Header
        setTableViewMainHeader()

        // Enable/disable drag interactions
        navigationItem.rightBarButtonItem = editButtonItem
    }
    
    @MainActor
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = PwgColor.background
        
        // Navigation bar
        navigationController?.navigationBar.configAppearance(withLargeTitles: false)

        // Header and example
        if let headerView = tableView?.tableHeaderView as? RenameFileTableHeaderView {
            headerView.applyColorPalette()
        }

        // Table view
        tableView.separatorColor = PwgColor.separator
        tableView.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Update example shown in header
        updateExample()
        
        // Set colors, fonts, etc.
        applyColorPalette()
        
       // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
        
        // Register font changes
        NotificationCenter.default.addObserver(self, selector: #selector(didChangeContentSizeCategory),
                                               name: UIContentSizeCategory.didChangeNotification, object: nil)
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
    
    
    // MARK: - Content Sizes
    @objc func didChangeContentSizeCategory(_ notification: NSNotification) {
        // Update content sizes
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Update header
            self.setTableViewMainHeader()
            
            // Animated update for smoother experience
            self.tableView?.beginUpdates()
            self.tableView?.endUpdates()

            // Update navigation bar
            self.navigationController?.navigationBar.configAppearance(withLargeTitles: false)
        }
    }
    
    @MainActor
    private func setTableViewMainHeader() {
        let headerView = RenameFileTableHeaderView(frame: CGRect.zero)
        let title = RenameAction.ActionType.addTime.name
        let text = NSLocalizedString("settings_renameTimeHeader", comment: "Please select a time format…")
        headerView.config(with: title, text: text, forWidth: view.bounds.width)
        headerView.updateExample(prefix: prefixBeforeUpload, prefixActions: prefixActions,
                                 replace: replaceBeforeUpload, replaceActions: replaceActions,
                                 suffix: suffixBeforeUpload, suffixActions: suffixActions,
                                 changeCase: changeCaseBeforeUpload, caseOfExtension: caseOfFileExtension,
                                 categoryId: categoryId, counter: currentCounter)
        tableView?.tableHeaderView = headerView
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
        if let headerView = tableView?.tableHeaderView as? RenameFileTableHeaderView {
            headerView.updateExample(prefix: prefixBeforeUpload, prefixActions: prefixActions,
                                     replace: replaceBeforeUpload, replaceActions: replaceActions,
                                     suffix: suffixBeforeUpload, suffixActions: suffixActions,
                                     changeCase: changeCaseBeforeUpload, caseOfExtension: caseOfFileExtension,
                                     categoryId: categoryId, counter: currentCounter)
        }
    }
}
