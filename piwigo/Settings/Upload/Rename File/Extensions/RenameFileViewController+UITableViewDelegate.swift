//
//  RenameFileViewController+UITableViewDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 29/03/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit
import uploadKit


// MARK: UITableViewDelegate Methods
extension RenameFileViewController: UITableViewDelegate
{
    // MARK: - Headers
    private func getContentOfHeader(forSection section: Int) -> (String, String) {
        var title: String = "", text: String = ""
        switch section {
        case RenameSection.prefix.rawValue:
            title = NSLocalizedString("settings_renameAddBefore", comment: "Add Before Name")
        case RenameSection.replace.rawValue:
            title = NSLocalizedString("settings_renameReplace", comment: "Replace Name")
        case RenameSection.suffix.rawValue:
            title = NSLocalizedString("settings_renameAddAfter", comment: "Add After Name")
        case RenameSection.fileExtension.rawValue:
            title = NSLocalizedString("settings_renameFileExtension", comment: "File Extension")
        default:
            preconditionFailure("Invalid section \(section)")
        }
        return (title, text)
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let (title, text) = getContentOfHeader(forSection: section)
        return TableViewUtilities.shared.heightOfHeader(withTitle: title, text: text,
                                                        width: tableView.frame.size.width)
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let (title, text) = getContentOfHeader(forSection: section)
        return TableViewUtilities.shared.viewOfHeader(withTitle: title, text: text)
    }
    
    
    // MARK: - Rows
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }
    

    // MARK: - Rows — Actions Reordering
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Show reorder control if necessary
        cell.showsReorderControl = tableView.isEditing ? self.tableView(tableView, canMoveRowAt: indexPath) : false
    }
    
    func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
                   toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        // Prevent rows from being moved to fileExtension section
        guard let proposedSection = RenameSection(rawValue: proposedDestinationIndexPath.section),
              proposedSection != .fileExtension
        else { return sourceIndexPath }
        
        // Can only move actions of sections
        if proposedDestinationIndexPath.row == 0 {
            return sourceIndexPath
        }
        
        return proposedDestinationIndexPath
    }

    
    // MARK: - Rows | Formats Modification
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        var result = false
        switch RenameSection(rawValue: indexPath.section) {
        case .prefix:
            let row = indexPath.row > 0 ? prefixActions[indexPath.row - 1].index : indexPath.row
            switch row {
            case RenameAction.ActionType.addDate.rawValue,
                 RenameAction.ActionType.addTime.rawValue,
                 RenameAction.ActionType.addCounter.rawValue:
                result = true
            default:
                break
            }
            
        case .replace:
            let row = indexPath.row > 0 ? replaceActions[indexPath.row - 1].index : indexPath.row
            switch row {
            case RenameAction.ActionType.addDate.rawValue,
                 RenameAction.ActionType.addTime.rawValue,
                 RenameAction.ActionType.addCounter.rawValue:
                result = true
            default:
                break
            }
            
        case .suffix:
            let row = indexPath.row > 0 ? suffixActions[indexPath.row - 1].index : indexPath.row
            switch row {
            case RenameAction.ActionType.addDate.rawValue,
                 RenameAction.ActionType.addTime.rawValue,
                 RenameAction.ActionType.addCounter.rawValue:
                result = true
            default:
                break
            }
            
        default:
            break
        }
        
        return result
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch RenameSection(rawValue: indexPath.section) {
        case .prefix:
            let row = indexPath.row > 0 ? prefixActions[indexPath.row - 1].index : indexPath.row
            switch row {
            case RenameAction.ActionType.addDate.rawValue       /* Date format */:
                pushDateFormatSelector(for: indexPath, withFormatString: prefixActions[indexPath.row - 1].style)
            case RenameAction.ActionType.addTime.rawValue       /* Time format */:
                pushTimeFormatSelector(for: indexPath, withFormatString: prefixActions[indexPath.row - 1].style)
            case RenameAction.ActionType.addCounter.rawValue    /* Counter format */:
                pushCounterFormatSelector(for: indexPath, withFormatString: prefixActions[indexPath.row - 1].style)
            default:
                break
            }
            
        case .replace:
            let row = indexPath.row > 0 ? replaceActions[indexPath.row - 1].index : indexPath.row
            switch row {
            case RenameAction.ActionType.addDate.rawValue       /* Date format */:
                pushDateFormatSelector(for: indexPath, withFormatString: replaceActions[indexPath.row - 1].style)
            case RenameAction.ActionType.addTime.rawValue       /* Time format */:
                pushTimeFormatSelector(for: indexPath, withFormatString: replaceActions[indexPath.row - 1].style)
            case RenameAction.ActionType.addCounter.rawValue    /* Counter format */:
                pushCounterFormatSelector(for: indexPath, withFormatString: replaceActions[indexPath.row - 1].style)
            default:
                break
            }
            
        case .suffix:
            let row = indexPath.row > 0 ? suffixActions[indexPath.row - 1].index : indexPath.row
            switch row {
            case RenameAction.ActionType.addDate.rawValue       /* Date format */:
                pushDateFormatSelector(for: indexPath, withFormatString: suffixActions[indexPath.row - 1].style)
            case RenameAction.ActionType.addTime.rawValue       /* Time format */:
                pushTimeFormatSelector(for: indexPath, withFormatString: suffixActions[indexPath.row - 1].style)
            case RenameAction.ActionType.addCounter.rawValue    /* Counter format */:
                pushCounterFormatSelector(for: indexPath, withFormatString: suffixActions[indexPath.row - 1].style)
            default:
                break
            }
            
        default:
            break
        }
    }
    
    private func pushDateFormatSelector(for indexPath: IndexPath, withFormatString formatString: String) {
        let dateFormatSB = UIStoryboard(name: "DateFormatSelectorViewController", bundle: nil)
        guard let dateFormatVC = dateFormatSB.instantiateViewController(withIdentifier: "DateFormatSelectorViewController") as? DateFormatSelectorViewController else { return }
        dateFormatVC.startValue = startValue
        dateFormatVC.prefixBeforeUpload = prefixBeforeUpload
        dateFormatVC.prefixActions = prefixActions
        dateFormatVC.replaceBeforeUpload = replaceBeforeUpload
        dateFormatVC.replaceActions = replaceActions
        dateFormatVC.suffixBeforeUpload = suffixBeforeUpload
        dateFormatVC.suffixActions = suffixActions
        dateFormatVC.changeCaseBeforeUpload = changeCaseBeforeUpload
        dateFormatVC.caseOfFileExtension = caseOfFileExtension
        dateFormatVC.delegate = self
        dateFormatVC.dateFormats = formatString.asPwgDateFormats
        navigationController?.pushViewController(dateFormatVC, animated: true)
    }
    
    private func pushTimeFormatSelector(for indexPath: IndexPath, withFormatString formatString: String) {
        let timeFormatSB = UIStoryboard(name: "TimeFormatSelectorViewController", bundle: nil)
        guard let timeFormatVC = timeFormatSB.instantiateViewController(withIdentifier: "TimeFormatSelectorViewController") as? TimeFormatSelectorViewController else { return }
        timeFormatVC.startValue = startValue
        timeFormatVC.prefixBeforeUpload = prefixBeforeUpload
        timeFormatVC.prefixActions = prefixActions
        timeFormatVC.replaceBeforeUpload = replaceBeforeUpload
        timeFormatVC.replaceActions = replaceActions
        timeFormatVC.suffixBeforeUpload = suffixBeforeUpload
        timeFormatVC.suffixActions = suffixActions
        timeFormatVC.changeCaseBeforeUpload = changeCaseBeforeUpload
        timeFormatVC.caseOfFileExtension = caseOfFileExtension
        timeFormatVC.delegate = self
        timeFormatVC.timeFormats = formatString.asPwgTimeFormats
        navigationController?.pushViewController(timeFormatVC, animated: true)
    }

    private func pushCounterFormatSelector(for indexPath: IndexPath, withFormatString formatString: String) {
        let counterFormatSB = UIStoryboard(name: "CounterFormatSelectorViewController", bundle: nil)
        guard let counterFormatVC = counterFormatSB.instantiateViewController(withIdentifier: "CounterFormatSelectorViewController") as? CounterFormatSelectorViewController else { return }
        counterFormatVC.prefixBeforeUpload = prefixBeforeUpload
        counterFormatVC.prefixActions = prefixActions
        counterFormatVC.replaceBeforeUpload = replaceBeforeUpload
        counterFormatVC.replaceActions = replaceActions
        counterFormatVC.suffixBeforeUpload = suffixBeforeUpload
        counterFormatVC.suffixActions = suffixActions
        counterFormatVC.changeCaseBeforeUpload = changeCaseBeforeUpload
        counterFormatVC.caseOfFileExtension = caseOfFileExtension
        counterFormatVC.delegate = self
        counterFormatVC.counterStartValue = UploadVars.shared.counterStartValue
        counterFormatVC.counterFormats = formatString.asPwgCounterFormats
        navigationController?.pushViewController(counterFormatVC, animated: true)
    }

    
    // MARK: - Footers | Add Action Buttons
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch RenameSection(rawValue: section) {
        case .prefix:
            if prefixBeforeUpload, availablePrefixActions().isEmpty == false {
                return 28.0
            }
        case .replace:
            if replaceBeforeUpload, availableReplaceActions().isEmpty == false {
                return 28.0
            }
        case .suffix:
            if suffixBeforeUpload, availableSuffixActions().isEmpty == false {
                return 28.0
            }
        default:
            break
        }
        return 0.0
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        switch RenameSection(rawValue: section) {
        case .prefix:
            if prefixBeforeUpload, availablePrefixActions().isEmpty == false {
                guard let footer = tableView.dequeueReusableHeaderFooterView(withIdentifier: "addActionFooter") as? AddActionTableViewFooterView
                else { preconditionFailure("Could not load AddActionTableViewFooterView") }
                footer.button.addTarget(self, action: #selector(addPrefixAction), for: .touchUpInside)
                return footer
            }
            
        case .replace:
            if replaceBeforeUpload, availableReplaceActions().isEmpty == false {
                guard let footer = tableView.dequeueReusableHeaderFooterView(withIdentifier: "addActionFooter") as? AddActionTableViewFooterView
                else { preconditionFailure("Could not load AddActionTableViewFooterView") }
                footer.button.addTarget(self, action: #selector(addReplaceAction), for: .touchUpInside)
                return footer
            }
            
        case .suffix:
            if suffixBeforeUpload, availableSuffixActions().isEmpty == false {
                guard let footer = tableView.dequeueReusableHeaderFooterView(withIdentifier: "addActionFooter") as? AddActionTableViewFooterView
                else { preconditionFailure("Could not load AddActionTableViewFooterView") }
                footer.button.addTarget(self, action: #selector(addSuffixAction), for: .touchUpInside)
                return footer
            }
            
        default:
            break
        }
        return nil
    }
    
    @objc func addPrefixAction() {
        suggestToAddPrefixAction()
    }
    
    @objc func addReplaceAction() {
        suggestToAddReplaceAction()
    }
    
    @objc func addSuffixAction() {
        suggestToAddSuffixAction()
    }
}
