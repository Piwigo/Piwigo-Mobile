//
//  DateFormatSelectorViewController+UITableViewDataSource.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

// MARK: UITableViewDataSource
extension DateFormatSelectorViewController: UITableViewDataSource
{
    func numberOfSections(in tableView: UITableView) -> Int {
        return dateSections.count - (isDragEnabled ? 1 : 0)
    }
    

    // MARK: - Year/Month/Day Cells
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var nberOfRows = 0
        switch dateSections[section] {
        case DateSection.year:
            let nberOfCases = pwgDateFormat.Year.allCases.count
            nberOfRows = isDragEnabled || (dateFormats[section] == .year(format: .none)) ? 1 : nberOfCases
        case DateSection.month:
            let nberOfCases = pwgDateFormat.Month.allCases.count
            nberOfRows = isDragEnabled || (dateFormats[section] == .month(format: .none)) ? 1 : nberOfCases
        case DateSection.day:
            let nberOfCases = pwgDateFormat.Day.allCases.count
            nberOfRows = isDragEnabled || (dateFormats[section] == .day(format: .none)) ? 1 : nberOfCases
        case DateSection.separator:
            nberOfRows = dateFormats[section] == .separator(format: .none) ? 1 : 2
        default:
            preconditionFailure("Unknown section \(section)")
        }
        return nberOfRows
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var tableViewCell = UITableViewCell()
        switch dateSections[indexPath.section] {
        case .year:
            switch indexPath.row {
            case 0 /* Display Year switch */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
                else { preconditionFailure("Could not load SwitchTableViewCell") }
                
                cell.configure(with: NSLocalizedString("Year", comment: "Year"))
                cell.cellSwitch.setOn(dateFormats[indexPath.section] != .year(format: .none), animated: true)
                cell.cellSwitchBlock = { switchState in
                    // Get indexPaths of options to display or hide
                    let rowsToInsertOrDelete = self.indexPathsOfOptions(in: indexPath.section)
                    // Update year option
                    if switchState {
                        // Enable year format
                        let defaultYearFormat: pwgDateFormat? = pwgDateFormat(UploadVars.shared.defaultYearFormat)
                        self.dateFormats[indexPath.section] = defaultYearFormat ?? .year(format: .yyyy)
                        // Show options
                        self.tableView?.insertRows(at: rowsToInsertOrDelete, with: .automatic)
                    } else {
                        // Disable year format
                        self.dateFormats[indexPath.section] = .year(format: .none)
                        // Hide options
                        self.tableView?.deleteRows(at: rowsToInsertOrDelete, with: .automatic)
                    }
                    // Update header
                    self.updateExample()
                }
                cell.accessibilityIdentifier = "yearSwitch"
                tableViewCell = cell
                
            case 1 /* yy option */ :
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                
                cell.configure(with: NSLocalizedString("settings_renameTwoDigit", comment: "2-digit version"), detail: "")
                let isSelected = dateFormats[indexPath.section] == .year(format: .yy)
                cell.accessoryType = isSelected ? .checkmark : .none
                cell.isUserInteractionEnabled = !isSelected
                cell.accessibilityIdentifier = "2-digit"
                tableViewCell = cell
                
            case 2 /* yyyy option */ :
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                
                cell.configure(with: NSLocalizedString("settings_renameFourDigit", comment: "4-digit version"), detail: "")
                let isSelected = dateFormats[indexPath.section] == .year(format: .yyyy)
                cell.accessoryType = isSelected ? .checkmark : .none
                cell.isUserInteractionEnabled = !isSelected
                cell.accessibilityIdentifier = "4-digit"
                tableViewCell = cell
                
            default:
                preconditionFailure("Unknown row \(indexPath.row) in section \(indexPath.section)")
            }
            
        case .month:
            switch indexPath.row {
            case 0 /* Display Month switch */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
                else { preconditionFailure("Could not load SwitchTableViewCell") }
                
                cell.configure(with: NSLocalizedString("Month", comment: "Month"))
                cell.cellSwitch.setOn(dateFormats[indexPath.section] != .month(format: .none), animated: true)
                cell.cellSwitchBlock = { switchState in
                    // Get indexPaths of options to display or hide
                    let rowsToInsertOrDelete = self.indexPathsOfOptions(in: indexPath.section)
                    // Update month option
                    if switchState {
                        // Enable month format
                        let defaultMonthFormat: pwgDateFormat? = pwgDateFormat(UploadVars.shared.defaultMonthFormat)
                        self.dateFormats[indexPath.section] = defaultMonthFormat ?? .month(format: .MM)
                        // Show options
                        self.tableView?.insertRows(at: rowsToInsertOrDelete, with: .automatic)
                    } else {
                        // Disable month format
                        self.dateFormats[indexPath.section] = .month(format: .none)
                        // Hide options
                        self.tableView?.deleteRows(at: rowsToInsertOrDelete, with: .automatic)
                    }
                    // Update header
                    self.updateExample()
                }
                cell.accessibilityIdentifier = "monthSwitch"
                tableViewCell = cell
                
            case 1 /* MM option */ :
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                
                cell.configure(with: NSLocalizedString("settings_renameTwoDigit", comment: "2-digit version"), detail: "")
                let isSelected = dateFormats[indexPath.section] == .month(format: .MM)
                cell.accessoryType = isSelected ? .checkmark : .none
                cell.isUserInteractionEnabled = !isSelected
                cell.accessibilityIdentifier = "2-digit"
                tableViewCell = cell
                
            case 2 /* MMM option */ :
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                
                cell.configure(with: NSLocalizedString("Abbreviation", comment: "Abbreviation"), detail: "")
                let isSelected = dateFormats[indexPath.section] == .month(format: .MMM)
                cell.accessoryType = isSelected ? .checkmark : .none
                cell.isUserInteractionEnabled = !isSelected
                cell.accessibilityIdentifier = "abbreviation"
                tableViewCell = cell
                
            case 3 /* MMMM option */ :
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                
                cell.configure(with: NSLocalizedString("FullName", comment: "Full Name"), detail: "")
                let isSelected = dateFormats[indexPath.section] == .month(format: .MMMM)
                cell.accessoryType = isSelected ? .checkmark : .none
                cell.isUserInteractionEnabled = !isSelected
                cell.accessibilityIdentifier = "fullName"
                tableViewCell = cell
                
            default:
                preconditionFailure("Unknown row \(indexPath.row) in section \(indexPath.section)")
            }
            
        case .day:
            switch indexPath.row {
            case 0 /* Display Day switch */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
                else { preconditionFailure("Could not load SwitchTableViewCell") }
                
                cell.configure(with: NSLocalizedString("Day", comment: "Day"))
                cell.cellSwitch.setOn(dateFormats[indexPath.section] != .day(format: .none), animated: true)
                cell.cellSwitchBlock = { switchState in
                    // Get indexPaths of options to display or hide
                    let rowsToInsertOrDelete = self.indexPathsOfOptions(in: indexPath.section)
                    // Update day option
                    if switchState {
                        // Enable day format
                        let defaultDayFormat: pwgDateFormat? = pwgDateFormat(UploadVars.shared.defaultDayFormat)
                        self.dateFormats[indexPath.section] = defaultDayFormat ?? .day(format: .dd)
                        // Show options
                        self.tableView?.insertRows(at: rowsToInsertOrDelete, with: .automatic)
                    } else {
                        // Disable day format
                        self.dateFormats[indexPath.section] = .day(format: .none)
                        // Hide options
                        self.tableView?.deleteRows(at: rowsToInsertOrDelete, with: .automatic)
                    }
                    // Update header
                    self.updateExample()
                }
                cell.accessibilityIdentifier = "daySwitch"
                tableViewCell = cell
                
            case 1 /* dd option */ :
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                
                cell.configure(with: NSLocalizedString("settings_renameTwoDigit", comment: "2-digit version"), detail: "")
                let isSelected = dateFormats[indexPath.section] == .day(format: .dd)
                cell.accessoryType = isSelected ? .checkmark : .none
                cell.isUserInteractionEnabled = !isSelected
                cell.accessibilityIdentifier = "2-digit"
                tableViewCell = cell
                
            case 2 /* ddd option */ :
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                
                cell.configure(with: NSLocalizedString("settings_renameDayOfYear", comment: "Day of Year"), detail: "")
                let isSelected = dateFormats[indexPath.section] == .day(format: .ddd)
                cell.accessoryType = isSelected ? .checkmark : .none
                cell.isUserInteractionEnabled = !isSelected
                cell.accessibilityIdentifier = "dayOfYear"
                tableViewCell = cell
                
            case 3 /* EEE option */ :
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                
                cell.configure(with: NSLocalizedString("Abbreviation", comment: "Abbreviation"), detail: "")
                let isSelected = dateFormats[indexPath.section] == .day(format: .EEE)
                cell.accessoryType = isSelected ? .checkmark : .none
                cell.isUserInteractionEnabled = !isSelected
                cell.accessibilityIdentifier = "abbreviation"
                tableViewCell = cell
                
            case 4 /* EEEE option */ :
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                
                cell.configure(with: NSLocalizedString("FullName", comment: "Full Name"), detail: "")
                let isSelected = dateFormats[indexPath.section] == .day(format: .EEEE)
                cell.accessoryType = isSelected ? .checkmark : .none
                cell.isUserInteractionEnabled = !isSelected
                cell.accessibilityIdentifier = "fullName"
                tableViewCell = cell
                
            default:
                preconditionFailure("Unknown row \(indexPath.row) in section \(indexPath.section)")
            }
            
        case .separator:
            switch indexPath.row {
            case 0 /* Display Year/Month/Day Separator switch */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
                else { preconditionFailure("Could not load SwitchTableViewCell") }
                
                cell.configure(with: NSLocalizedString("Separator", comment: "Separator"))
                cell.cellSwitch.setOn(dateFormats[indexPath.section] != .separator(format: .none), animated: true)
                cell.cellSwitchBlock = { switchState in
                    // Get indexPath of option to display or hide
                    let rowToInsertOrDelete = IndexPath(row: 1, section: DateSection.separator.rawValue)
                    // Update separator option
                    if switchState {
                        // Enable separator format
                        self.dateFormats[indexPath.section] = .separator(format: .dash)
                        // Show options
                        self.tableView?.insertRows(at: [rowToInsertOrDelete], with: .automatic)
                    } else {
                        // Disable separator format
                        self.dateFormats[indexPath.section] = .separator(format: .none)
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
                cell.configure(with: dateFormats[indexPath.section].asString)
                cell.cellSeparatorSelectorBlock = { choice in
                    // Update separator option
                    if let index = self.dateFormats.firstIndex(where: {
                        if case .separator( _) = $0 { return true } else { return false } }) {
                        self.dateFormats[index] = .separator(format: choice)
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
    
    
    // MARK: - Year/Month/Day Reordering
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Drag mode enabled?
        if isDragEnabled == false { return false }
        
        // Prevent Separator section from being moved
        guard let section = DateSection(rawValue: indexPath.section),
              section != .separator
        else { return false }
        
        // Can only move first row of Year, Month, Day sections
        return indexPath.row == 0
    }
        
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        // Swape sections
        dateSections.swapAt(sourceIndexPath.section, destinationIndexPath.section)
        dateFormats.swapAt(sourceIndexPath.section, destinationIndexPath.section)
        tableView.reloadData()

        // Update header
        self.updateExample()
    }
}
