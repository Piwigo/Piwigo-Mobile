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
        switch ImageUploadSetting(rawValue: textField.tag) {
        case .author:
            editedRow = IndexPath(row: 0, section: SettingsSection.imageUpload.rawValue)
        case .prefix:
            editedRow = IndexPath(row: 5 + (user.hasAdminRights ? 1 : 0)
                                         + (UploadVars.shared.resizeImageOnUpload ? 2 : 0)
                                         + (UploadVars.shared.compressImageOnUpload ? 1 : 0),
                                  section: SettingsSection.imageUpload.rawValue)
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
        switch ImageUploadSetting(rawValue: textField.tag) {
        case .author:
            UploadVars.shared.defaultAuthor = textField.text ?? ""
        case .prefix:
            UploadVars.shared.defaultPrefix = textField.text ?? ""
            if UploadVars.shared.defaultPrefix.isEmpty {
                UploadVars.shared.prefixFileNameBeforeUpload = false
                // Remove row in existing table
                let prefixIndexPath = IndexPath(row: 5 + (user.hasAdminRights ? 1 : 0)
                                                       + (UploadVars.shared.resizeImageOnUpload ? 2 : 0)
                                                       + (UploadVars.shared.compressImageOnUpload ? 1 : 0),
                                                section: SettingsSection.imageUpload.rawValue)
                settingsTableView?.deleteRows(at: [prefixIndexPath], with: .automatic)

                // Refresh flag
                let indexPath = IndexPath(row: prefixIndexPath.row - 1,
                                          section: SettingsSection.imageUpload.rawValue)
                settingsTableView?.reloadRows(at: [indexPath], with: .automatic)
            }
        default:
            break
        }
        
        // Done cell editing
        editedRow = nil
    }
}
