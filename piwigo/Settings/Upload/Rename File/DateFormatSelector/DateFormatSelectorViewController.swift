//
//  DateFormatSelectorViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 05/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

protocol SelectDateFormatDelegate: NSObjectProtocol {
    func didSelectDateFormat(_ format: String)
}

class DateFormatSelectorViewController: UIViewController {
    
    enum DateSection: Int {
        case year
        case month
        case day
        case separator
        case count
    }
    
    weak var delegate: SelectDateFormatDelegate?
    
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var exampleLabel: RenameFileInfoLabel!
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

    var dateSections: [DateSection] = []    // To order date fomats as user wishes
    var dateFormats: [pwgDateFormat] = []   // Should always contain all formats (year, month, day and separator)
    var isDragEnabled: Bool = false


    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Title, header and example
        title = NSLocalizedString("tabBar_upload", comment: "Upload")

        // Table view
        tableView?.accessibilityIdentifier = "Date Format Settings"
        tableView?.rowHeight = UITableView.automaticDimension
        tableView?.estimatedRowHeight = TableViewUtilities.rowHeight

        // Header
        setMainHeader()

        // Initialise section in appropriate order
        dateSections = []
        for dateFormat in dateFormats {
            switch dateFormat {
            case .year(format: _):
                dateSections.append(.year)
            case .month(format: _):
                dateSections.append(.month)
            case .day(format: _):
                dateSections.append(.day)
            case .separator:
                continue
            }
        }
        dateSections.append(.separator)

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
        delegate?.didSelectDateFormat(dateFormats.asString)
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
            self.setMainHeader()
            self.updateExample()
            
            // Animated update for smoother experience
            self.tableView?.beginUpdates()
            self.tableView?.endUpdates()

            // Update navigation bar
            self.navigationController?.navigationBar.configAppearance(withLargeTitles: false)
        }
    }
    
    private func setMainHeader() {
        let headerAttributedString = NSMutableAttributedString(string: "")
        let title = String(format: "%@\n", RenameAction.ActionType.addDate.name)
        let titleAttributedString = NSMutableAttributedString(string: title)
        titleAttributedString.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .headline),
                                           range: NSRange(location: 0, length: title.count))
        headerAttributedString.append(titleAttributedString)
        let text = NSLocalizedString("settings_renameDateHeader", comment: "Please select a date format…")
        let textAttributedString = NSMutableAttributedString(string: text)
        textAttributedString.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .footnote),
                                          range: NSRange(location: 0, length: text.count))
        headerAttributedString.append(textAttributedString)
        headerLabel.attributedText = headerAttributedString
        headerLabel.sizeToFit()
    }


    // MARK: - Date Format Utilities
    func indexPathsOfOptions(in section: Int) -> [IndexPath] {
        // Determine the current number of displayed options
        var nberOfOptions: Int = 0
        switch dateSections[section] {
        case DateSection.year:
            nberOfOptions = pwgDateFormat.Year.allCases.count
        case DateSection.month:
            nberOfOptions = pwgDateFormat.Month.allCases.count
        case DateSection.day:
            nberOfOptions = pwgDateFormat.Day.allCases.count
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

    func updateExample() {
        // Look for the date format stored in default settings
        if let index = prefixActions.firstIndex(where: { $0.type == .addDate }) {
            var action = prefixActions[index]
            action.style = dateFormats.asString
            prefixActions[index] = action
        }
        else if let index = replaceActions.firstIndex(where: { $0.type == .addDate }) {
            var action = replaceActions[index]
            action.style = dateFormats.asString
            replaceActions[index] = action
        }
        else if let index = suffixActions.firstIndex(where: { $0.type == .addDate }) {
            var action = suffixActions[index]
            action.style = dateFormats.asString
            suffixActions[index] = action
        }

        // Update example shown in header
        exampleLabel?.updateExample(prefix: prefixBeforeUpload, prefixActions: prefixActions,
                                    replace: replaceBeforeUpload, replaceActions: replaceActions,
                                    suffix: suffixBeforeUpload, suffixActions: suffixActions,
                                    changeCase: changeCaseBeforeUpload, caseOfExtension: caseOfFileExtension,
                                    categoryId: categoryId, counter: currentCounter)
    }

    
    // MARK: - Year/Month/Day Reordering
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        // Enable/disable drag mode
        isDragEnabled = editing
        
        // Hide/show options and separator section
        var rowsToDeleteOrInsert: [IndexPath] = []
        for section in 0..<(DateSection.count.rawValue - 1) {
            // Hide/show switches
            let indexPath = IndexPath(row: 0, section: section)
            if let cell = tableView?.cellForRow(at: indexPath) as? SwitchTableViewCell {
                cell.cellSwitch.isHidden = editing
            }
            // Collect indexPaths of displayed options
            switch dateSections[section] {
            case .year:
                if dateFormats[section] != .year(format: .none) {
                    rowsToDeleteOrInsert.append(contentsOf: indexPathsOfOptions(in: section))
                }
            case .month:
                if dateFormats[section] != .month(format: .none) {
                    rowsToDeleteOrInsert.append(contentsOf: indexPathsOfOptions(in: section))
                }
            case .day:
                if dateFormats[section] != .day(format: .none) {
                    rowsToDeleteOrInsert.append(contentsOf: indexPathsOfOptions(in: section))
                }
            default :
                break
            }
        }
        if editing {
            tableView?.performBatchUpdates {
                tableView?.deleteRows(at: rowsToDeleteOrInsert, with: .automatic)
                tableView?.deleteSections(IndexSet(integer: DateSection.separator.rawValue), with: .automatic)
            }
        } else {
            tableView?.performBatchUpdates {
                tableView?.insertRows(at: rowsToDeleteOrInsert, with: .automatic)
                tableView?.insertSections(IndexSet(integer: DateSection.separator.rawValue), with: .automatic)
            }
        }
        
        // Show/hide reorder controls
        for section in 0..<(DateSection.count.rawValue - 1) {
            tableView?.cellForRow(at: IndexPath(row: 0, section: section))?.showsReorderControl = editing
        }
    }
}
