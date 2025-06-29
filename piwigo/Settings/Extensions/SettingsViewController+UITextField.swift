//
//  SettingsViewController+UITextField.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 01/01/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

// MARK: - UITextFieldDelegate Methods
extension SettingsViewController: UITextFieldDelegate {
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        // Will tell onKeyboardAppear() which cell is being edited
        switch TextFieldTag(rawValue: textField.tag) {
        case .author:
            editedRow = IndexPath(row: 0, section: SettingsSection.imageUpload.rawValue)
        default:
            break
        }
        return true
    }
    
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        settingsTableView?.endEditing(true)
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        switch TextFieldTag(rawValue: textField.tag) {
        case .author:
            UploadVars.shared.defaultAuthor = textField.text ?? ""
        default:
            break
        }
        
        // Done cell editing
        editedRow = nil
    }
}
