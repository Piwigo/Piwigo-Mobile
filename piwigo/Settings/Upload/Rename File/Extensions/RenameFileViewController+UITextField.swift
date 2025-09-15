//
//  RenameFileViewController+UITextField.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 29/03/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit
import uploadKit

// MARK: - UITextFieldDelegate Methods
extension RenameFileViewController: UITextFieldDelegate {

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        // Will tell onKeyboardAppear() which cell is being edited
        if let cell = textField.parentTableViewCell() as? TextFieldTableViewCell,
           let indexPath = tableView?.indexPath(for: cell) as? IndexPath {
            editedRow = indexPath
        }
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Accept only characters not leading to file management issues
        return ["/", "\\", ":"].contains(string) ? false : true
    }
    
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        tableView?.endEditing(true)
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        // Get indexPath of cell
        guard let cell = textField.parentTableViewCell() as? TextFieldTableViewCell,
              let indexPath = tableView?.indexPath(for: cell) as? IndexPath
        else { return }
        
        switch RenameSection(rawValue: indexPath.section) {
        case .prefix:
            // Empty prefix?
            if (textField.text ?? "").isEmpty {
                // Remove action and corresponding row
                self.prefixActions.remove(at: indexPath.row - 1)
                self.tableView?.deleteRows(at: [indexPath], with: .automatic)
            }
            else {
                // Update action
                // Piwigo 2.10.2 supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
                let text = textField.text?.utf8mb3Encoded ?? ""
                self.prefixActions[indexPath.row - 1].style = text
            }

            // Update example, settings and section
            self.updateExample()
            self.updatePrefixSettingsAndSection()

        case .replace:
            // Empty name?
            if (textField.text ?? "").isEmpty {
                // Remove action and corresponding row
                self.replaceActions.remove(at: indexPath.row - 1)
                self.tableView?.deleteRows(at: [indexPath], with: .automatic)
            }
            else {
                // Update action
                // Piwigo 2.10.2 supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
                let text = textField.text?.utf8mb3Encoded ?? ""
                self.replaceActions[indexPath.row - 1].style = text
            }

            // Update example, settings and section
            self.updateExample()
            self.updateReplaceSettingsAndSection()

        case .suffix:
            // Suffix empty?
            if (textField.text ?? "").isEmpty {
                // Remove action and corresponding row
                self.suffixActions.remove(at: indexPath.row - 1)
                self.tableView?.deleteRows(at: [indexPath], with: .automatic)
            }
            else {
                // Update action
                // Piwigo 2.10.2 supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
                let text = textField.text?.utf8mb3Encoded ?? ""
                self.suffixActions[indexPath.row - 1].style = text
            }

            // Update example, settings and section
            self.updateExample()
            self.updateSuffixSettingsAndSection()

        default:
            break
        }
        
        // Done cell editing
        editedRow = nil
    }
}
