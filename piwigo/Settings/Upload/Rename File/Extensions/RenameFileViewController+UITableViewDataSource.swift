//
//  RenameFileViewController+UITableViewDataSource.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 29/03/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit
import uploadKit

// MARK: - UITableViewDataSource Methods
extension RenameFileViewController: UITableViewDataSource
{
    // MARK: - Cells
    private func addTextCellForRow(at indexPath: IndexPath) -> TextFieldTableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "TextFieldTableViewCell", for: indexPath) as? TextFieldTableViewCell
        else { preconditionFailure("Could not load TextFieldTableViewCell") }
        
        let title = NSLocalizedString("Text", comment: "Text")
        switch RenameSection(rawValue: indexPath.section) {
        case .prefix:
            cell.configure(with: title, input: prefixActions[indexPath.row - 1].style,
                           placeHolder: NSLocalizedString("settings_prefixPlaceholder", comment: "Prefix_"))
            cell.accessibilityIdentifier = "prefixFileName"
            
        case .replace:
            cell.configure(with: title, input: replaceActions[indexPath.row - 1].style,
                           placeHolder: "_")
            cell.accessibilityIdentifier = "addSeparatorToFileName"
            
        case .suffix:
            cell.configure(with: title, input: suffixActions[indexPath.row - 1].style,
                           placeHolder: NSLocalizedString("settings_suffixPlaceholder", comment: "_suffix"))
            cell.accessibilityIdentifier = "suffixFileName"
            
        default:
            break
        }
        cell.rightTextField.delegate = self
        return cell
    }
    
    private func addAlbumNameCellForRow(at indexPath: IndexPath) -> LabelTableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
        else { preconditionFailure("Could not load LabelTableViewCell") }
        
        cell.configure(with: NSLocalizedString("createNewAlbum_placeholder", comment: "Album Name"), detail: "")
        cell.accessoryType = .none
        cell.accessibilityIdentifier = "addAlbumName"
        return cell
    }
    
    private func addDateCellForRow(at indexPath: IndexPath) -> LabelTableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
        else { preconditionFailure("Could not load LabelTableViewCell") }
        
        cell.configure(with: NSLocalizedString("editImageDetails_dateCreation", comment: "Creation Date"), detail: "")
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = "addCreationDate"
        return cell
    }
    
    private func addTimeCellForRow(at indexPath: IndexPath) -> LabelTableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
        else { preconditionFailure("Could not load LabelTableViewCell") }
        
        cell.configure(with: NSLocalizedString("editImageDetails_timeCreation", comment: "Creation Time"), detail: "")
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = "addCreationTime"
        return cell
    }
    
    private func addCounterCellForRow(at indexPath: IndexPath) -> LabelTableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
        else { preconditionFailure("Could not load LabelTableViewCell") }
        
        cell.configure(with: NSLocalizedString("Counter", comment: "Counter"), detail: "")
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = "addCounter"
        return cell
    }
    
    
    // MARK: - Actions
    func numberOfSections(in tableView: UITableView) -> Int {
        return RenameSection.count.rawValue - (self.isEditing ? 1 : 0)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var nberOfRows = 0
        switch RenameSection(rawValue: section) {
        case .prefix:
            nberOfRows = 1 + (tableView.isEditing || UploadVars.shared.prefixFileNameBeforeUpload ? prefixActions.count : 0)
        case .replace:
            nberOfRows = 1 + (tableView.isEditing || UploadVars.shared.replaceFileNameBeforeUpload ? replaceActions.count : 0)
        case .suffix:
            nberOfRows = 1 + (tableView.isEditing || UploadVars.shared.suffixFileNameBeforeUpload ? suffixActions.count : 0)
        case .fileExtension:
            nberOfRows = 1 + (UploadVars.shared.changeCaseOfFileExtension ? 1 : 0)
        default:
            preconditionFailure("Unknown section \(section)")
        }
        
        return nberOfRows
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var tableViewCell = UITableViewCell()
        switch RenameSection(rawValue: indexPath.section) {
        case .prefix:
            let row = indexPath.row > 0 ? prefixActions[indexPath.row - 1].index : indexPath.row
            switch row {
            case 0 /* Add prefix switch */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
                else { preconditionFailure("Could not load SwitchTableViewCell") }
                
                cell.configure(with: NSLocalizedString("settings_renamePrefix", comment: "Prefix File Name"))
                cell.cellSwitch.setOn(UploadVars.shared.prefixFileNameBeforeUpload, animated: true)
                cell.cellSwitchBlock = { switchState in
                    // Enable/disable prefix actions
                    UploadVars.shared.prefixFileNameBeforeUpload = switchState
                    
                    // Get rows that should be added/removed
                    var rowsToInsertOrDelete: [IndexPath] = []
                    for (index, _) in self.prefixActions.enumerated() {
                        rowsToInsertOrDelete.append(IndexPath(row: index + 1, section: RenameSection.prefix.rawValue))
                    }
                    
                    // Suggest to add actions or add/remove rows
                    if switchState {
                        if rowsToInsertOrDelete.isEmpty {
                            self.suggestToAddPrefixAction()
                        } else {
                            self.updateExample(prefixActions: self.prefixActions)
                            self.tableView?.insertRows(at: rowsToInsertOrDelete, with: .automatic)
                            if let footerView = self.tableView?.footerView(forSection: RenameSection.prefix.rawValue) as? AddActionTableViewFooterView {
                                footerView.setEnabled(self.availablePrefixActions().isEmpty == false)
                            }
                        }
                    } else {
                        self.updateExample(prefixActions: self.prefixActions)
                        self.tableView?.deleteRows(at: rowsToInsertOrDelete, with: .automatic)
                        if let footerView = self.tableView?.footerView(forSection: RenameSection.prefix.rawValue) as? AddActionTableViewFooterView {
                            footerView.setEnabled(false)
                        }
                    }
                }
                
                cell.accessibilityIdentifier = "prefixFileNameSwitch"
                tableViewCell = cell
                
            case RenameAction.ActionType.addText.rawValue /* Text of prefix */:
                tableViewCell = addTextCellForRow(at: indexPath)
                
            case RenameAction.ActionType.addAlbum.rawValue /* Dummy album name */:
                tableViewCell = addAlbumNameCellForRow(at: indexPath)
                
            case RenameAction.ActionType.addDate.rawValue /* Dummy creation date */:
                tableViewCell = addDateCellForRow(at: indexPath)
                
            case RenameAction.ActionType.addTime.rawValue /* Dummy creation time */ :
                tableViewCell = addTimeCellForRow(at: indexPath)
                
            case RenameAction.ActionType.addCounter.rawValue /* Dummy counter */ :
                tableViewCell = addCounterCellForRow(at: indexPath)
                
            default:
                break
            }
            
        case .replace:
            let row = indexPath.row > 0 ? replaceActions[indexPath.row - 1].index : indexPath.row
            switch row {
            case 0 /* Replace name switch */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
                else { preconditionFailure("Could not load SwitchTableViewCell") }
                
                cell.configure(with: NSLocalizedString("settings_renameReplace", comment: "Replace File Name"))
                cell.cellSwitch.setOn(UploadVars.shared.replaceFileNameBeforeUpload, animated: true)
                cell.cellSwitchBlock = { switchState in
                    // Enable/disable replace actions
                    UploadVars.shared.replaceFileNameBeforeUpload = switchState
                    
                    // Get rows that should be added/removed
                    var rowsToInsertOrDelete: [IndexPath] = []
                    for (index, _) in self.replaceActions.enumerated() {
                        rowsToInsertOrDelete.append(IndexPath(row: index + 1, section: RenameSection.replace.rawValue))
                    }
                    
                    // Suggest to add actions or add/remove rows
                    if switchState {
                        if rowsToInsertOrDelete.isEmpty {
                            self.suggestToAddReplaceAction()
                        } else {
                            self.updateExample(replaceActions: self.replaceActions)
                            self.tableView?.insertRows(at: rowsToInsertOrDelete, with: .automatic)
                            if let footerView = self.tableView?.footerView(forSection: RenameSection.replace.rawValue) as? AddActionTableViewFooterView {
                                footerView.setEnabled(self.availableReplaceActions().isEmpty == false)
                            }
                        }
                    } else {
                        self.updateExample(replaceActions: self.replaceActions)
                        self.tableView?.deleteRows(at: rowsToInsertOrDelete, with: .automatic)
                        if let footerView = self.tableView?.footerView(forSection: RenameSection.replace.rawValue) as? AddActionTableViewFooterView {
                            footerView.setEnabled(false)
                        }
                    }
                }
                cell.accessibilityIdentifier = "replaceFileNameSwitch"
                tableViewCell = cell
                
            case RenameAction.ActionType.addText.rawValue /* e.g. a separator */:
                tableViewCell = addTextCellForRow(at: indexPath)
                
            case RenameAction.ActionType.addAlbum.rawValue /* Dummy album name */:
                tableViewCell = addAlbumNameCellForRow(at: indexPath)
                
            case RenameAction.ActionType.addDate.rawValue /* Dummy creation date */:
                tableViewCell = addDateCellForRow(at: indexPath)
                
            case RenameAction.ActionType.addTime.rawValue /* Dummy creation time */ :
                tableViewCell = addTimeCellForRow(at: indexPath)
                
            case RenameAction.ActionType.addCounter.rawValue /* Dummy counter */ :
                tableViewCell = addCounterCellForRow(at: indexPath)
                
            default:
                break
            }
            
        case .suffix:
            let row = indexPath.row > 0 ? suffixActions[indexPath.row - 1].index : indexPath.row
            switch row {
            case 0 /* Add suffix switch */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
                else { preconditionFailure("Could not load SwitchTableViewCell") }
                
                cell.configure(with: NSLocalizedString("settings_renameSuffix", comment: "Suffix File Name"))
                cell.cellSwitch.setOn(UploadVars.shared.suffixFileNameBeforeUpload, animated: true)
                cell.cellSwitchBlock = { switchState in
                    // Enable/disable suffix actions
                    UploadVars.shared.suffixFileNameBeforeUpload = switchState
                    
                    // Get rows that should be added/removed
                    var rowsToInsertOrDelete: [IndexPath] = []
                    for (index, _) in self.suffixActions.enumerated() {
                        rowsToInsertOrDelete.append(IndexPath(row: index + 1, section: RenameSection.suffix.rawValue))
                    }
                    
                    // Suggest to add actions or add/remove rows
                    if switchState {
                        if rowsToInsertOrDelete.isEmpty {
                            self.suggestToAddSuffixAction()
                        } else {
                            self.updateExample(suffixActions: self.suffixActions)
                            self.tableView?.insertRows(at: rowsToInsertOrDelete, with: .automatic)
                            if let footerView = self.tableView?.footerView(forSection: RenameSection.suffix.rawValue) as? AddActionTableViewFooterView {
                                footerView.setEnabled(self.availableReplaceActions().isEmpty == false)
                            }
                        }
                    } else {
                        self.updateExample(suffixActions: self.suffixActions)
                        self.tableView?.deleteRows(at: rowsToInsertOrDelete, with: .automatic)
                        if let footerView = self.tableView?.footerView(forSection: RenameSection.suffix.rawValue) as? AddActionTableViewFooterView {
                            footerView.setEnabled(false)
                        }
                    }
                }
                cell.accessibilityIdentifier = "suffixFileNameSwitch"
                tableViewCell = cell
                
            case RenameAction.ActionType.addText.rawValue /* Text of suffix */:
                tableViewCell = addTextCellForRow(at: indexPath)
                
            case RenameAction.ActionType.addAlbum.rawValue /* Dummy album name */:
                tableViewCell = addAlbumNameCellForRow(at: indexPath)
                
            case RenameAction.ActionType.addDate.rawValue /* Dummy creation date */:
                tableViewCell = addDateCellForRow(at: indexPath)
                
            case RenameAction.ActionType.addTime.rawValue /* Dummy creation time */ :
                tableViewCell = addTimeCellForRow(at: indexPath)
                
            case RenameAction.ActionType.addCounter.rawValue /* Dummy counter */ :
                tableViewCell = addCounterCellForRow(at: indexPath)
                
            default:
                break
            }
            
        case .fileExtension:
            switch indexPath.row {
            case 0 /* Change Case switch */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
                else { preconditionFailure("Could not load SwitchTableViewCell") }
                
                cell.configure(with: NSLocalizedString("settings_renameChangeCase", comment: "Change Case"))
                cell.cellSwitch.setOn(UploadVars.shared.changeCaseOfFileExtension, animated: true)
                cell.cellSwitchBlock = { switchState in
                    // Number of rows will change accordingly
                    UploadVars.shared.changeCaseOfFileExtension = switchState
                    // Position of the row that should be added/removed
                    let rowAtIndexPath = IndexPath(row: 1, section: RenameSection.fileExtension.rawValue)
                    if switchState {
                        // Insert row in existing table
                        self.tableView?.insertRows(at: [rowAtIndexPath], with: .automatic)
                    } else {
                        // Remove row in existing table
                        self.tableView?.deleteRows(at: [rowAtIndexPath], with: .automatic)
                    }
                    // Update example shown in Info section
                    self.updateExample()
                }
                cell.accessibilityIdentifier = "changeCaseOfFileExtension"
                tableViewCell = cell
                
            case 1 /* Case of File Extension */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "CaseSelectorTableViewCell", for: indexPath) as? CaseSelectorTableViewCell
                else { preconditionFailure("Could not load CaseSelectorTableViewCell") }
                
                cell.configure(with: UploadVars.shared.caseOfFileExtension)
                cell.cellCaseSelectorBlock = {
                    // Update example shown in Info section
                    self.updateExample()
                }
                cell.accessibilityIdentifier = "caseOfFileExtension"
                tableViewCell = cell
                
            default:
                break
            }
            
        default:
            preconditionFailure("Unknown section \(indexPath.section)")
        }
        
        return tableViewCell
    }
    
    
    // MARK: - Action Deletion
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        var result = false
        switch RenameSection(rawValue: indexPath.section) {
        case .prefix, .replace, .suffix:
            result = indexPath.row > 0
        default:
            break
        }
        return result
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        debugPrint("Commit editingStyle: \(editingStyle) forRowAt: \(indexPath) where isEditing: \(tableView.isEditing)")
        switch RenameSection(rawValue: indexPath.section) {
        case .prefix:
            // Remove action and corresponding row
            self.prefixActions.remove(at: indexPath.row - 1)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            
            // Update example, settings and section
            self.updatePrefixSettingsAndSection()
            self.updateExample(prefixActions: self.prefixActions)

        case .replace:
            // Remove action and corresponding row
            replaceActions.remove(at: indexPath.row - 1)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            
            // Update example, settings and section
            self.updateReplaceSettingsAndSection()
            self.updateExample(replaceActions: self.replaceActions)

        case .suffix:
            // Remove action and corresponding row
            suffixActions.remove(at: indexPath.row - 1)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            
            // Update example, settings and section
            self.updateSuffixSettingsAndSection()
            self.updateExample(suffixActions: self.suffixActions)

        default:
            break
        }
    }
    
    
    // MARK: - Actions Reordering
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Drag mode enabled?
        if tableView.isEditing == false { return false }
        
        // Prevent fileExtension section from being moved
        var result = false
        switch RenameSection(rawValue: indexPath.section) {
        case .prefix, .replace, .suffix:
            result = indexPath.row > 0
        default:
            break
        }
        return result
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard let sourceSection = RenameSection(rawValue: sourceIndexPath.section),
              let destinationSection = RenameSection(rawValue: destinationIndexPath.section)
        else { return }
        
        switch (sourceSection, destinationSection) {
        case (.prefix, .prefix):
            prefixActions.swapAt(sourceIndexPath.row - 1, destinationIndexPath.row - 1)
            updatePrefixSettingsAndSection()
            updateExample(prefixActions: prefixActions)

        case (.prefix, .replace):
            replaceActions.insert(prefixActions[sourceIndexPath.row - 1], at: destinationIndexPath.row - 1)
            prefixActions.remove(at: sourceIndexPath.row - 1)
            updatePrefixSettingsAndSection()
            updateReplaceSettingsAndSection()
            updateExample(prefixActions: prefixActions, replaceActions: replaceActions)

        case (.prefix, .suffix):
            suffixActions.insert(prefixActions[sourceIndexPath.row - 1], at: destinationIndexPath.row - 1)
            prefixActions.remove(at: sourceIndexPath.row - 1)
            updatePrefixSettingsAndSection()
            updateSuffixSettingsAndSection()
            updateExample(prefixActions: prefixActions, suffixActions: suffixActions)

        case (.replace, .prefix):
            prefixActions.insert(replaceActions[sourceIndexPath.row - 1], at: destinationIndexPath.row - 1)
            replaceActions.remove(at: sourceIndexPath.row - 1)
            updatePrefixSettingsAndSection()
            updateReplaceSettingsAndSection()
            updateExample(prefixActions: prefixActions, replaceActions: replaceActions)

        case (.replace, .replace):
            replaceActions.swapAt(sourceIndexPath.row - 1, destinationIndexPath.row - 1)
            updateReplaceSettingsAndSection()
            updateExample(replaceActions: replaceActions)

        case (.replace, .suffix):
            suffixActions.insert(replaceActions[sourceIndexPath.row - 1], at: destinationIndexPath.row - 1)
            replaceActions.remove(at: sourceIndexPath.row - 1)
            updateReplaceSettingsAndSection()
            updateSuffixSettingsAndSection()
            updateExample(replaceActions: replaceActions, suffixActions: suffixActions)

        case (.suffix, .prefix):
            prefixActions.insert(suffixActions[sourceIndexPath.row - 1], at: destinationIndexPath.row - 1)
            suffixActions.remove(at: sourceIndexPath.row - 1)
            updatePrefixSettingsAndSection()
            updateSuffixSettingsAndSection()
            updateExample(prefixActions: prefixActions, suffixActions: suffixActions)

        case (.suffix, .replace):
            replaceActions.insert(suffixActions[sourceIndexPath.row - 1], at: destinationIndexPath.row - 1)
            suffixActions.remove(at: sourceIndexPath.row - 1)
            updateReplaceSettingsAndSection()
            updateSuffixSettingsAndSection()
            updateExample(replaceActions: replaceActions, suffixActions: suffixActions)

        case (.suffix, .suffix):
            suffixActions.swapAt(sourceIndexPath.row - 1, destinationIndexPath.row - 1)
            updateSuffixSettingsAndSection()
            updateExample(suffixActions: suffixActions)

        default:
            break
        }
    }
}
