//
//  CounterFormatSelectorViewController+UITableViewDataSource.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 30/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

extension CounterFormatSelectorViewController: UITableViewDataSource
{
    // MARK: - Rows
    func numberOfSections(in tableView: UITableView) -> Int {
        return CounterSection.count.rawValue
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var nberOfRows = 0
        switch CounterSection(rawValue: section) {
        case .start:
            nberOfRows = 1
        case .prefix:
            nberOfRows = counterFormats[section - 1] == .prefix(format: .none) ? 1 : 2
        case .digits:
            nberOfRows = 1
        case .suffix:
            nberOfRows = counterFormats[section - 1] == .suffix(format: .none) ? 1 : 2
        default:
            preconditionFailure("Unknown section \(section)")
        }
        return nberOfRows
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var tableViewCell = UITableViewCell()
        switch CounterSection(rawValue: indexPath.section) {
        case .start:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "TextFieldTableViewCell", for: indexPath) as? TextFieldTableViewCell
            else { preconditionFailure("Could not load TextFieldTableViewCell") }
            
            var title = ""
            if parent?.parent is SettingsViewController {
                title = NSLocalizedString("settings_renameCounterCurrent", comment: "Starts From")
            } else {
                title = NSLocalizedString("settings_renameCounterStart", comment: "Current Value")
            }
            cell.configure(with: title, input: String(currentCounter), placeHolder: "1")
            cell.accessibilityIdentifier = "startCounterValue"
            cell.rightTextField.delegate = self
            tableViewCell = cell

        case .prefix:
            switch indexPath.row {
            case 0 /* Display Counter Prefix switch */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
                else { preconditionFailure("Could not load SwitchTableViewCell") }
                
                cell.configure(with: NSLocalizedString("settings_prefix", comment: "Prefix"))
                cell.cellSwitch.setOn(counterFormats[indexPath.section - 1] != .prefix(format: .none), animated: true)
                cell.cellSwitchBlock = { switchState in
                    // Get indexPath of option to display or hide
                    let rowToInsertOrDelete = IndexPath(row: 1, section: CounterSection.prefix.rawValue)
                    // Update prefix option
                    if switchState {
                        // Enable prefix format
                        self.counterFormats[indexPath.section - 1] = .prefix(format: .round)
                        // Show options
                        self.tableView?.insertRows(at: [rowToInsertOrDelete], with: .automatic)
                    } else {
                        // Disable prefix format
                        self.counterFormats[indexPath.section - 1] = .prefix(format: .none)
                        // Hide options
                        self.tableView?.deleteRows(at: [rowToInsertOrDelete], with: .automatic)
                    }
                    // Update header
                    self.updateExample()
                }
                cell.accessibilityIdentifier = "prefixSwitch"
                tableViewCell = cell
                
            case 1 /* Select Prefix */ :
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "CounterPrefixSelectorTableViewCell") as? CounterPrefixSelectorTableViewCell
                else { preconditionFailure("Could not load CounterPrefixSelectorTableViewCell") }
            
                cell.configure(with: counterFormats[indexPath.section - 1].asString)
                cell.cellPrefixSelectorBlock = { choice in
                    // Update prefix
                    self.counterFormats[indexPath.section - 1] = .prefix(format: choice)
                    // Update header
                    self.updateExample()
                }
                cell.accessibilityIdentifier = "prefixChoice"
                tableViewCell = cell
                
            default:
                preconditionFailure("Unknown row \(indexPath.row) in section \(indexPath.section)")
            }

        case .digits:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SliderTableViewCell") as? SliderTableViewCell
            else { preconditionFailure("Could not load SliderTableViewCell") }
            
            // Slider value
            var value = Float(4)
            if let index = counterFormats.firstIndex(where: {
                if case .digits( _) = $0 { return true } else { return false } }) {
                value = Float(counterFormats[index].asString.count)
            }
            
            // Slider configuration
            let title = NSLocalizedString("settings_renameCounterDigits", comment: "Digits")
            let minValue: Float = Float(pwgCounterFormat.Digits.allCases.first!.rawValue.count)
            let maxValue: Float = Float(pwgCounterFormat.Digits.allCases.last!.rawValue.count)
            cell.configure(with: title, value: value, increment: 1, minValue: minValue, maxValue: maxValue, prefix: "", suffix: "")
            cell.cellSliderBlock = { newValue in
                // Update format
                if let choice = pwgCounterFormat.Digits(rawValue: String(repeating: "0", count: Int(newValue))) {
                    self.counterFormats[indexPath.section - 1] = .digits(format: choice)
                }
                // Update header
                self.updateExample()
            }
            cell.accessibilityIdentifier = "digitsSlider"
            tableViewCell = cell

        case .suffix:
            switch indexPath.row {
            case 0 /* Display Counter Suffix switch */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
                else { preconditionFailure("Could not load SwitchTableViewCell") }
                
                cell.configure(with: NSLocalizedString("settings_suffix", comment: "Suffix"))
                cell.cellSwitch.setOn(counterFormats[indexPath.section - 1] != .suffix(format: .none), animated: true)
                cell.cellSwitchBlock = { switchState in
                    // Get indexPath of option to display or hide
                    let rowToInsertOrDelete = IndexPath(row: 1, section: CounterSection.suffix.rawValue)
                    // Update suffix option
                    if switchState {
                        // Enable suffix format
                        self.counterFormats[indexPath.section - 1] = .suffix(format: .round)
                        // Show options
                        self.tableView?.insertRows(at: [rowToInsertOrDelete], with: .automatic)
                    } else {
                        // Disable suffix format
                        self.counterFormats[indexPath.section - 1] = .suffix(format: .none)
                        // Hide options
                        self.tableView?.deleteRows(at: [rowToInsertOrDelete], with: .automatic)
                    }
                    // Update header
                    self.updateExample()
                }
                cell.accessibilityIdentifier = "suffixSwitch"
                tableViewCell = cell
                
            case 1 /* Select Suffix */ :
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "CounterSuffixSelectorTableViewCell") as? CounterSuffixSelectorTableViewCell
                else { preconditionFailure("Could not load CounterSuffixSelectorTableViewCell")}
                cell.configure(with: counterFormats[indexPath.section - 1].asString)
                cell.cellSuffixSelectorBlock = { choice in
                    // Update suffix
                    self.counterFormats[indexPath.section - 1] = .suffix(format: choice)
                    // Update header
                    self.updateExample()
                }
                cell.accessibilityIdentifier = "suffixChoice"
                tableViewCell = cell
                
            default:
                preconditionFailure("Unknown row \(indexPath.row) in section \(indexPath.section)")
            }
            
        default:
            preconditionFailure("Unknown row \(indexPath.row) in section \(indexPath.section)")
        }
        
        return tableViewCell
    }
}
