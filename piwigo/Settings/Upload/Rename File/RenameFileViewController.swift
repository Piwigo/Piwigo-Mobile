//
//  RenameFileViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/03/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit
import uploadKit

protocol MofifyFilenameDelegate: NSObjectProtocol {
    func didChangeRenameFileSettings(prefix: Bool, prefixActions: RenameActionList,
                                     replace: Bool, replaceActions: RenameActionList,
                                     suffix: Bool, suffixActions: RenameActionList,
                                     changeCase: Bool, caseOfExtension: FileExtCase,
                                     currentCounter: Int64)
}

enum RenameSection: Int {
    case prefix
    case replace
    case suffix
    case fileExtension
    case count
}
    
class RenameFileViewController: UIViewController {
    
    weak var delegate: MofifyFilenameDelegate?
    
    // Default actions
    var currentCounter: Int64 = UploadVars.shared.categoryCounterInit
    var prefixBeforeUpload: Bool = UploadVars.shared.prefixFileNameBeforeUpload
    var prefixActions: RenameActionList = UploadVars.shared.prefixFileNameActionList.actions
    var replaceBeforeUpload: Bool = UploadVars.shared.replaceFileNameBeforeUpload
    var replaceActions: RenameActionList = UploadVars.shared.replaceFileNameActionList.actions
    var suffixBeforeUpload: Bool = UploadVars.shared.suffixFileNameBeforeUpload
    var suffixActions: RenameActionList = UploadVars.shared.suffixFileNameActionList.actions
    var changeCaseBeforeUpload: Bool = UploadVars.shared.changeCaseOfFileExtension
    var caseOfFileExtension: FileExtCase = FileExtCase(rawValue: UploadVars.shared.caseOfFileExtension) ?? .keep
    
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var exampleLabel: RenameFileInfoLabel!
    @IBOutlet weak var tableView: UITableView!
    
    // Used to display the album ID (unset by SettingsViewController)
    var categoryId: Int32 = 66
    // Tell which cell triggered the keyboard appearance
    var editedRow: IndexPath?
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Title
        title = NSLocalizedString("tabBar_upload", comment: "Upload")
        
        // Header
        let headerAttributedString = NSMutableAttributedString(string: "")
        let title = String(format: "%@\n", NSLocalizedString("settings_renameFileLong", comment: "Rename File Before Upload"))
        let titleAttributedString = NSMutableAttributedString(string: title)
        titleAttributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 17, weight: .bold),
                                           range: NSRange(location: 0, length: title.count))
        headerAttributedString.append(titleAttributedString)
        let text = NSLocalizedString("settings_renameFile_info", comment: "Please define how file names should be modified before uploading.")
        let textAttributedString = NSMutableAttributedString(string: text)
        textAttributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 13),
                                          range: NSRange(location: 0, length: text.count))
        headerAttributedString.append(textAttributedString)
        headerLabel.attributedText = headerAttributedString
        headerLabel.sizeToFit()

        // Enable/disable drag and delete interactions
        navigationItem.rightBarButtonItem = editButtonItem

        // Register the Add Action footer view
        tableView?.register(AddActionTableViewFooterView.self, forHeaderFooterViewReuseIdentifier: "addActionFooter")
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
        tableView?.separatorColor = PwgColor.separator
        tableView?.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        tableView?.reloadData()
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
        
        // Register keyboard appearance/disappearance
        NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardWillShow(_:)),
                                               name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardWillHide(_:)),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        // Enable/disable edit mode
        tableView?.setEditing(editing, animated: animated)
        
        // Hide/show options and separator section
        var rowsToInsertOrDelete: [IndexPath] = []
        for section in 0..<(RenameSection.count.rawValue - 1) {
            let indexPath = IndexPath(row: 0, section: section)
            switch RenameSection(rawValue: section) {
            case .prefix:
                // Hide/show switch
                if let cell = tableView?.cellForRow(at: indexPath) as? SwitchTableViewCell {
                    cell.cellSwitch.isHidden = editing
                    cell.isUserInteractionEnabled = !editing
                    if editing == false, cell.cellSwitch.isOn != prefixBeforeUpload {
                        cell.cellSwitch.setOn(prefixBeforeUpload, animated: false)
                    }
                }
                // Collect indexPaths of action to show/hide if needed
                if prefixBeforeUpload == false {
                    for (index, _) in prefixActions.enumerated() {
                        rowsToInsertOrDelete.append(IndexPath(row: index + 1, section: section))
                    }
                }
            case .replace:
                // Hide/show switch
                if let cell = tableView?.cellForRow(at: indexPath) as? SwitchTableViewCell {
                    cell.cellSwitch.isHidden = editing
                    cell.isUserInteractionEnabled = !editing
                    if editing == false, cell.cellSwitch.isOn != replaceBeforeUpload {
                        cell.cellSwitch.setOn(replaceBeforeUpload, animated: false)
                    }
                }
                // Collect indexPaths of action to show/hide if needed
                if replaceBeforeUpload == false {
                    for (index, _) in replaceActions.enumerated() {
                        rowsToInsertOrDelete.append(IndexPath(row: index + 1, section: section))
                    }
                }
            case .suffix:
                // Hide/show switch
                if let cell = tableView?.cellForRow(at: indexPath) as? SwitchTableViewCell {
                    cell.cellSwitch.isHidden = editing
                    cell.isUserInteractionEnabled = !editing
                    if editing == false, cell.cellSwitch.isOn != suffixBeforeUpload {
                        cell.cellSwitch.setOn(suffixBeforeUpload, animated: false)
                    }
                }
                // Collect indexPaths of action to show/hide if needed
                if suffixBeforeUpload == false {
                    for (index, _) in suffixActions.enumerated() {
                        rowsToInsertOrDelete.append(IndexPath(row: index + 1, section: section))
                    }
                }
            default:
                break
            }
        }
        if editing {
            tableView?.performBatchUpdates {
                tableView?.insertRows(at: rowsToInsertOrDelete, with: .automatic)
                tableView?.deleteSections(IndexSet(integer: RenameSection.fileExtension.rawValue), with: .automatic)
            }
        } else {
            tableView?.performBatchUpdates {
                tableView?.deleteRows(at: rowsToInsertOrDelete, with: .automatic)
                tableView?.insertSections(IndexSet(integer: RenameSection.fileExtension.rawValue), with: .automatic)
            }
        }

        // Enable/disable switches
        for section in 0..<(RenameSection.count.rawValue - 1) {
            // Show/hide reorder controls
            let nberOfActions = tableView?.numberOfRows(inSection: section) ?? 0
            for row in 1..<nberOfActions {
                let indexPath = IndexPath(row: row, section: section)
                tableView?.cellForRow(at: IndexPath(row: row, section: section))?.showsReorderControl = editing
                if let cell = tableView?.cellForRow(at: indexPath) as? TextFieldTableViewCell {
                    cell.rightTextField.isHidden = editing
                }
            }
            
            // Show/hide the Add Action button
            if let footerView = self.tableView?.footerView(forSection: section) as? AddActionTableViewFooterView {
                switch RenameSection(rawValue: section) {
                case .prefix:
                    footerView.setEnabled(editing == false && prefixBeforeUpload
                                          && availablePrefixActions().isEmpty == false)
                case .replace:
                    footerView.setEnabled(editing == false && replaceBeforeUpload
                                          && availableReplaceActions().isEmpty == false)
                case .suffix:
                    footerView.setEnabled(editing == false && suffixBeforeUpload
                                          && availableSuffixActions().isEmpty == false)
                default:
                    break
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super .viewDidDisappear(animated)
        
        // Inform parent view
        delegate?.didChangeRenameFileSettings(prefix: prefixBeforeUpload, prefixActions: prefixActions,
                                              replace: replaceBeforeUpload, replaceActions: replaceActions,
                                              suffix: suffixBeforeUpload, suffixActions: suffixActions,
                                              changeCase: changeCaseBeforeUpload, caseOfExtension: caseOfFileExtension,
                                              currentCounter: currentCounter)
    }
    
    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - All Actions
    func unusedActions() -> Set<RenameAction.ActionType> {
        let usedActions = Set((prefixActions + replaceActions + suffixActions).map(\.self.type))
        let allActions: Set<RenameAction.ActionType> = Set(RenameAction.ActionType.allCases)
        return allActions.subtracting(usedActions)
    }

    func updateExample() {
        exampleLabel?.updateExample(prefix: prefixBeforeUpload, prefixActions: prefixActions,
                                    replace: replaceBeforeUpload, replaceActions: replaceActions,
                                    suffix: suffixBeforeUpload, suffixActions: suffixActions,
                                    changeCase: changeCaseBeforeUpload, caseOfExtension: caseOfFileExtension,
                                    categoryId: categoryId, counter: currentCounter)
    }
    

    // MARK: - Prefix Actions
    // Returns actions which can still be added to one of the 3 sections
    func availablePrefixActions() -> [RenameAction.ActionType] {
        // Get action types that are not already used
        var remainingActions: Set<RenameAction.ActionType> = unusedActions()
        
        // Allow appropriate number of addText actions
        let prefixTypes = self.prefixActions.map(\.type)
        let nberOfAddText: Int = prefixTypes.filter({ $0 == .addText}).count
        let maxNberOfAddText: Int = 1 + prefixTypes.filter({ $0 != .addText}).count
        if nberOfAddText < maxNberOfAddText, prefixTypes.last != .addText {
            remainingActions.insert(.addText)
        }
        return Array(remainingActions).sorted()
    }

    @objc func suggestToAddPrefixAction() {
        // Can we suggest more actions?
        let availableActionTypes = availablePrefixActions()
        if availableActionTypes.isEmpty { return }
        
        // Create alert
        let section = RenameSection.prefix.rawValue
        let alert = UIAlertController(title: "", message: NSLocalizedString("settings_addActionMsg", comment: "Please select the action to add"), preferredStyle: .actionSheet)
        
        // Loop over all unused actions
        for actionType in availableActionTypes {
            alert.addAction(UIAlertAction(title: actionType.name, style: .default, handler: { [weak self] _ in
                guard let self = self else { return }
                // Add action and corresponding row
                self.prefixActions.append(RenameAction(type: actionType))
                let indexPath = IndexPath(row: self.prefixActions.count, section: section)
                self.tableView?.insertRows(at: [indexPath], with: .automatic)
                
                // Update example, settings and section
                self.updateExample()
                self.updatePrefixSettingsAndSection()
            }))
        }
        
        // Add Cancel option
        alert.addAction(UIAlertAction(title: NSLocalizedString("alertDismissButton", comment: "Dismiss"), style: .cancel, handler: { [weak self] _ in
            guard let self = self else { return }
            self.updatePrefixSettingsAndSection()
        }))
        
        // Present list of actions
        alert.view.tintColor = PwgColor.orange
        alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        alert.popoverPresentationController?.sourceView = tableView
        alert.popoverPresentationController?.permittedArrowDirections = [.up, .down]
        alert.popoverPresentationController?.sourceRect = tableView?.rectForFooter(inSection: section) ?? CGRect.zero
        present(alert, animated: true, completion: {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = PwgColor.orange
        })
    }

    func updatePrefixSettingsAndSection() {
        let section = RenameSection.prefix.rawValue
        let indexPath = IndexPath(row: 0, section: section)

        if self.prefixActions.isEmpty {
            // Update settings
            prefixBeforeUpload = false
            
            // Disable Add Before Name
            if let cell = tableView?.cellForRow(at: indexPath) as? SwitchTableViewCell {
                cell.cellSwitch.setOn(false, animated: (tableView?.isEditing ?? false) == false)
            }
            
            // Hide the Add Action button
            if let footerView = self.tableView?.footerView(forSection: section) as? AddActionTableViewFooterView {
                footerView.setEnabled(false)
            }
        } else {
            // Update settings
            prefixBeforeUpload = true
            
            // Enable Add Before Name
            if let cell = tableView?.cellForRow(at: indexPath) as? SwitchTableViewCell {
                cell.cellSwitch.setOn(true, animated: (tableView?.isEditing ?? false) == false)
            }

            // Show/hide the Add Action button
            if let footerView = self.tableView?.footerView(forSection: section) as? AddActionTableViewFooterView {
                footerView.setEnabled(tableView?.isEditing == false && availablePrefixActions().isEmpty == false)
            }
        }
    }


    // MARK: - Replace Actions
    func availableReplaceActions() -> [RenameAction.ActionType] {
        // Get action types that are not already used
        var remainingActions: Set<RenameAction.ActionType> = unusedActions()
        remainingActions.remove(.addText)

        // Allow appropriate number of addText actions
        let replaceTypes = self.replaceActions.map(\.type)
        let nberOfAddText: Int = replaceTypes.filter({ $0 == .addText}).count
        let maxNberOfAddText: Int = replaceTypes.filter({ $0 != .addText}).count - 1
        if nberOfAddText < maxNberOfAddText {
            remainingActions.insert(.addText)
        }
        return Array(remainingActions).sorted()
    }

    @objc func suggestToAddReplaceAction() {
        // Can we suggest more actions?
        let availableActionTypes = availableReplaceActions()
        if availableActionTypes.isEmpty { return }
        
        // Create alert
        let section = RenameSection.replace.rawValue
        let alert = UIAlertController(title: "", message: NSLocalizedString("settings_addActionMsg", comment: "Please select the action to add"), preferredStyle: .actionSheet)
        
        // Loop over all unused actions
        for actionType in availableActionTypes {
            alert.addAction(UIAlertAction(title: actionType.name, style: .default, handler: { [weak self] _ in
                guard let self = self else { return }
                // Add action and corresponding row
                self.replaceActions.append(RenameAction(type: actionType))
                let indexPath = IndexPath(row: self.replaceActions.count, section: section)
                self.tableView?.insertRows(at: [indexPath], with: .automatic)
                
                // Update example, settings and section
                self.updateExample()
                self.updateReplaceSettingsAndSection()
            }))
        }
        
        // Add Cancel option
        alert.addAction(UIAlertAction(title: NSLocalizedString("alertDismissButton", comment: "Dismiss"), style: .cancel, handler: { [weak self] _ in
            guard let self = self else { return }
            self.updateReplaceSettingsAndSection()
        }))
        
        // Present list of actions
        alert.view.tintColor = PwgColor.orange
        alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        alert.popoverPresentationController?.sourceView = tableView
        alert.popoverPresentationController?.permittedArrowDirections = [.up, .down]
        alert.popoverPresentationController?.sourceRect = tableView?.rectForFooter(inSection: section) ?? CGRect.zero
        present(alert, animated: true, completion: {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = PwgColor.orange
        })
    }
    
    func updateReplaceSettingsAndSection() {
        let section = RenameSection.replace.rawValue
        let indexPath = IndexPath(row: 0, section: section)

        if self.replaceActions.isEmpty {
            // Update settings
            replaceBeforeUpload = false

            // Disable Replace Name
            if let cell = tableView?.cellForRow(at: indexPath) as? SwitchTableViewCell {
                cell.cellSwitch.setOn(false, animated: (tableView?.isEditing ?? false) == false)
            }

            // Hide the Add Action button
            if let footerView = self.tableView?.footerView(forSection: section) as? AddActionTableViewFooterView {
                footerView.setEnabled(false)
            }
        } else {
            // Update settings
            replaceBeforeUpload = true

            // Enable Replace Name
            if let cell = tableView?.cellForRow(at: indexPath) as? SwitchTableViewCell {
                cell.cellSwitch.setOn(true, animated: (tableView?.isEditing ?? false) == false)
            }

            // Show/hide the Add Action button
            if let footerView = self.tableView?.footerView(forSection: section) as? AddActionTableViewFooterView {
                footerView.setEnabled(tableView?.isEditing == false && availableReplaceActions().isEmpty == false)
            }
        }
    }

    
    // MARK: - Suffix Actions
    func availableSuffixActions() -> [RenameAction.ActionType] {
        // Get action types that are not already used
        var remainingActions: Set<RenameAction.ActionType> = unusedActions()

        // Allow appropriate number of addText actions
        let suffixTypes = self.suffixActions.map(\.type)
        let nberOfAddText: Int = suffixTypes.filter({ $0 == .addText}).count
        let maxNberOfAddText: Int = 1 + suffixTypes.filter({ $0 != .addText}).count
        if nberOfAddText < maxNberOfAddText, suffixTypes.first != .addText {
            remainingActions.insert(.addText)
        }
        return Array(remainingActions).sorted()
    }

    @objc func suggestToAddSuffixAction() {
        // Can we suggest more actions?
        let availableActionTypes = availableSuffixActions()
        if availableActionTypes.isEmpty { return }

        // Create alert
        let section = RenameSection.suffix.rawValue
        let alert = UIAlertController(title: "", message: NSLocalizedString("settings_addActionMsg", comment: "Please select the action to add"), preferredStyle: .actionSheet)
        
        // Loop over all unused actions
        for actionType in availableActionTypes {
            alert.addAction(UIAlertAction(title: actionType.name, style: .default, handler: { [weak self] _ in
                guard let self = self else { return }
                // Add action and corresponding row
                self.suffixActions.append(RenameAction(type: actionType))
                let indexPath = IndexPath(row: self.suffixActions.count, section: section)
                self.tableView?.insertRows(at: [indexPath], with: .automatic)
                
                // Update example, settings and section
                self.updateExample()
                self.updateSuffixSettingsAndSection()
            }))
        }
        
        // Add Cancel option
        alert.addAction(UIAlertAction(title: NSLocalizedString("alertDismissButton", comment: "Dismiss"), style: .cancel, handler: { [weak self] _ in
            guard let self = self else { return }
            self.updateSuffixSettingsAndSection()
        }))
        
        // Present list of actions
        alert.view.tintColor = PwgColor.orange
        alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        alert.popoverPresentationController?.sourceView = tableView
        alert.popoverPresentationController?.permittedArrowDirections = [.up, .down]
        alert.popoverPresentationController?.sourceRect = tableView?.rectForFooter(inSection: section) ?? CGRect.zero
        present(alert, animated: true, completion: {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = PwgColor.orange
        })
    }
    
    func updateSuffixSettingsAndSection() {
        let section = RenameSection.suffix.rawValue
        let indexPath = IndexPath(row: 0, section: section)

        if self.suffixActions.isEmpty {
            // Update settings
            suffixBeforeUpload = false
            
            // Disable Add After Name
            if let cell = tableView?.cellForRow(at: indexPath) as? SwitchTableViewCell {
                cell.cellSwitch.setOn(false, animated: (tableView?.isEditing ?? false) == false)
            }

            // Hide the Add Action button
            if let footerView = self.tableView?.footerView(forSection: section) as? AddActionTableViewFooterView {
                footerView.setEnabled(false)
            }
        } else {
            // Update settings
            suffixBeforeUpload = true
            
            // Enable Add After Name
            if let cell = tableView?.cellForRow(at: indexPath) as? SwitchTableViewCell {
                cell.cellSwitch.setOn(true, animated: (tableView?.isEditing ?? false) == false)
            }

            // Show/hide the Add Action button
            if let footerView = self.tableView?.footerView(forSection: section) as? AddActionTableViewFooterView {
                footerView.setEnabled(tableView?.isEditing == false && availableSuffixActions().isEmpty == false)
            }
        }
    }
}
