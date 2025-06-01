//
//  TimeFormatSelectorViewController+UITableViewDataSource.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 25/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

// MARK: - UITableViewDataSource
extension TimeFormatSelectorViewController: UITableViewDataSource
{
    // MARK: - Rows
    func numberOfSections(in tableView: UITableView) -> Int {
        return TimeSection.count.rawValue
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var nberOfRows = 0
        switch TimeSection(rawValue: section) {
        case .hour:
            let nberOfCases = pwgTimeFormat.Hour.allCases.count
            nberOfRows = (timeFormats[section] == .hour(format: .none)) ? 1 : nberOfCases
        case .minute:
            let nberOfCases = pwgTimeFormat.Minute.allCases.count
            nberOfRows = (timeFormats[section] == .minute(format: .none)) ? 1 : nberOfCases
        case .second:
            let nberOfCases = pwgTimeFormat.Second.allCases.count
            nberOfRows = (timeFormats[section] == .second(format: .none)) ? 1 : nberOfCases
        case .separator:
            nberOfRows = timeFormats[section] == .separator(format: .none) ? 1 : 2
        default:
            preconditionFailure("Unknown section \(section)")
        }
        return nberOfRows
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var tableViewCell = UITableViewCell()
        switch TimeSection(rawValue: indexPath.section) {
        case .hour:
            switch indexPath.row {
            case 0 /* Display Hour switch */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
                else { preconditionFailure("Could not load SwitchTableViewCell") }
                
                cell.configure(with: NSLocalizedString("Hour", comment: "Hour"))
                cell.cellSwitch.setOn(timeFormats[indexPath.section] != .hour(format: .none), animated: true)
                cell.cellSwitchBlock = { switchState in
                    // Get indexPaths of options to display or hide
                    let rowsToInsertOrDelete = self.indexPathsOfOptions(in: indexPath.section)
                    // Update hour option
                    if switchState {
                        // Enable hour format
                        let defaultHourFormat: pwgTimeFormat? = pwgTimeFormat(UploadVars.shared.defaultHourFormat)
                        self.timeFormats[indexPath.section] = defaultHourFormat ?? .hour(format: .HH)
                        // Show options
                        self.tableView?.insertRows(at: rowsToInsertOrDelete, with: .automatic)
                    } else {
                        // Disable hour format
                        self.timeFormats[indexPath.section] = .hour(format: .none)
                        // Hide options
                        self.tableView?.deleteRows(at: rowsToInsertOrDelete, with: .automatic)
                    }
                    // Update header
                    self.updateExample()
                }
                cell.accessibilityIdentifier = "hourSwitch"
                tableViewCell = cell
                
            case 1 /* hha option */ :
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                
                cell.configure(with: NSLocalizedString("12-hour", comment: "12-hour cycle"), detail: "")
                let isSelected = timeFormats[indexPath.section] == .hour(format: .hha)
                cell.accessoryType = isSelected ? .checkmark : .none
                cell.isUserInteractionEnabled = !isSelected
                cell.accessibilityIdentifier = "12-hour"
                tableViewCell = cell
                
            case 2 /* HH option */ :
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                
                cell.configure(with: NSLocalizedString("24-hour cycle", comment: "24-hour cycle"), detail: "")
                let isSelected = timeFormats[indexPath.section] == .hour(format: .HH)
                cell.accessoryType = isSelected ? .checkmark : .none
                cell.isUserInteractionEnabled = !isSelected
                cell.accessibilityIdentifier = "24-hour"
                tableViewCell = cell
                
            default:
                preconditionFailure("Unknown row \(indexPath.row) in section \(indexPath.section)")
            }
            
        case .minute:
            switch indexPath.row {
            case 0 /* Display Minute switch */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
                else { preconditionFailure("Could not load SwitchTableViewCell") }
                
                cell.configure(with: NSLocalizedString("Minute", comment: "Minute"))
                cell.cellSwitch.setOn(timeFormats[indexPath.section] != .minute(format: .none), animated: true)
                cell.cellSwitchBlock = { switchState in
                    // Get indexPaths of options to display or hide
                    let rowsToInsertOrDelete = self.indexPathsOfOptions(in: indexPath.section)
                    // Update minute option
                    if switchState {
                        // Enable minute format
                        let defaultMinuteFormat: pwgTimeFormat? = pwgTimeFormat(UploadVars.shared.defaultMinuteFormat)
                        self.timeFormats[indexPath.section] = defaultMinuteFormat ?? .minute(format: .mm)
                        // Show options
                        self.tableView?.insertRows(at: rowsToInsertOrDelete, with: .automatic)
                    } else {
                        // Disable minute format
                        self.timeFormats[indexPath.section] = .minute(format: .none)
                        // Hide options
                        self.tableView?.deleteRows(at: rowsToInsertOrDelete, with: .automatic)
                    }
                    // Update header
                    self.updateExample()
                }
                cell.accessibilityIdentifier = "minuteSwitch"
                tableViewCell = cell
                
            case 1 /* mm option */ :
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                
                cell.configure(with: NSLocalizedString("settings_renameTwoDigit", comment: "2-digit version"), detail: "")
                let isSelected = timeFormats[indexPath.section] == .minute(format: .mm)
                cell.accessoryType = isSelected ? .checkmark : .none
                cell.isUserInteractionEnabled = !isSelected
                cell.accessibilityIdentifier = "12-hour"
                tableViewCell = cell
                
            default:
                preconditionFailure("Unknown row \(indexPath.row) in section \(indexPath.section)")
            }
            
        case .second:
            switch indexPath.row {
            case 0 /* Display Second switch */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
                else { preconditionFailure("Could not load SwitchTableViewCell") }
                
                cell.configure(with: NSLocalizedString("Second", comment: "Second"))
                cell.cellSwitch.setOn(timeFormats[indexPath.section] != .second(format: .none), animated: true)
                cell.cellSwitchBlock = { switchState in
                    // Get indexPaths of options to display or hide
                    let rowsToInsertOrDelete = self.indexPathsOfOptions(in: indexPath.section)
                    // Update second option
                    if switchState {
                        // Enable second format
                        let defaultSecondFormat: pwgTimeFormat? = pwgTimeFormat(UploadVars.shared.defaultSecondFormat)
                        self.timeFormats[indexPath.section] = defaultSecondFormat ?? .second(format: .ss)
                        // Show options
                        self.tableView?.insertRows(at: rowsToInsertOrDelete, with: .automatic)
                    } else {
                        // Disable second format
                        self.timeFormats[indexPath.section] = .second(format: .none)
                        // Hide options
                        self.tableView?.deleteRows(at: rowsToInsertOrDelete, with: .automatic)
                    }
                    // Update header
                    self.updateExample()
                }
                cell.accessibilityIdentifier = "secondSwitch"
                tableViewCell = cell
                
            case 1 /* ss option */ :
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                
                cell.configure(with: NSLocalizedString("settings_renameTwoDigit", comment: "2-digit version"), detail: "")
                let isSelected = timeFormats[indexPath.section] == .second(format: .ss)
                cell.accessoryType = isSelected ? .checkmark : .none
                cell.isUserInteractionEnabled = !isSelected
                cell.accessibilityIdentifier = "2-digit"
                tableViewCell = cell
                
            case 2 /* ssSSS option */ :
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                
                cell.configure(with: NSLocalizedString("settings_renameFiveDigit", comment: "5-digit version"), detail: "")
                let isSelected = timeFormats[indexPath.section] == .second(format: .ssSSS)
                cell.accessoryType = isSelected ? .checkmark : .none
                cell.isUserInteractionEnabled = !isSelected
                cell.accessibilityIdentifier = "5-digit"
                tableViewCell = cell
                
            default:
                preconditionFailure("Unknown row \(indexPath.row) in section \(indexPath.section)")
            }

        case .separator:
            switch indexPath.row {
            case 0 /* Display Hour/Minute/Second Separator switch */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
                else { preconditionFailure("Could not load SwitchTableViewCell") }
                
                cell.configure(with: NSLocalizedString("Separator", comment: "Separator"))
                cell.cellSwitch.setOn(timeFormats[indexPath.section] != .separator(format: .none), animated: true)
                cell.cellSwitchBlock = { switchState in
                    // Get indexPath of option to display or hide
                    let rowToInsertOrDelete = IndexPath(row: 1, section: TimeSection.separator.rawValue)
                    // Update separator option
                    if switchState {
                        // Enable separator format
                        self.timeFormats[indexPath.section] = .separator(format: .dash)
                        // Show options
                        self.tableView?.insertRows(at: [rowToInsertOrDelete], with: .automatic)
                    } else {
                        // Disable separator format
                        self.timeFormats[indexPath.section] = .separator(format: .none)
                        // Hide options
                        self.tableView?.deleteRows(at: [rowToInsertOrDelete], with: .automatic)
                    }
                    // Update header
                    self.updateExample()
                }
                cell.accessibilityIdentifier = "separatorSwitch"
                tableViewCell = cell
                
            case 1 /* Select Separator */ :
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SeparatorSelectorTableViewCell", for: indexPath) as? SeparatorSelectorTableViewCell
                else { preconditionFailure("Could not load SeparatorSelectorTableViewCell") }
                cell.configure(with: timeFormats[indexPath.section].asString)
                cell.cellSeparatorSelectorBlock = { choice in
                    // Update separator
                    if let index = self.timeFormats.firstIndex(where: {
                        if case .separator( _) = $0 { return true } else { return false } }) {
                        self.timeFormats[index] = .separator(format: choice)
                    }
                    // Update header
                    self.updateExample()
                }
                cell.accessibilityIdentifier = "separatorChoice"
                tableViewCell = cell
                
            default:
                preconditionFailure("Unknown row \(indexPath.row) in section \(indexPath.section)")
            }

        default:
            preconditionFailure("Unknown section \(indexPath.section)")
        }
        
        return tableViewCell
    }
}
