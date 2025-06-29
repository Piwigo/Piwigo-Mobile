//
//  CounterFormatSelectorViewController+UITextField.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 31/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

// MARK: - UITextFieldDelegate Methods
extension CounterFormatSelectorViewController: UITextFieldDelegate {

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        // Will tell onKeyboardAppear() which cell is being edited
        if let cell = textField.parentTableViewCell() as? TextFieldTableViewCell,
           let indexPath = tableView?.indexPath(for: cell) as? IndexPath {
            editedRow = indexPath
        }
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Accept only digits
        return CharacterSet(charactersIn: string).isSubset(of: CharacterSet.decimalDigits)
    }
    
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        if (textField.text ?? "").isEmpty == false {
            // Update header
            updateExample()
            return true
        }
        return false
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        // Update settings
        if let value = Int64(textField.text ?? ""), value >= 0 {
            currentCounter = value
        }

        // Update header
        updateExample()

        // Done cell editing
        editedRow = nil
    }
}
