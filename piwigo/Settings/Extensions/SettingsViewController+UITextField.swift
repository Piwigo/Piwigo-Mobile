//
//  SettingsViewController+UITextField.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 01/01/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

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
                                         + (UploadVars.resizeImageOnUpload ? 2 : 0)
                                         + (UploadVars.compressImageOnUpload ? 1 : 0),
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
            UploadVars.defaultAuthor = textField.text ?? ""
        case .prefix:
            UploadVars.defaultPrefix = textField.text ?? ""
            if UploadVars.defaultPrefix.isEmpty {
                UploadVars.prefixFileNameBeforeUpload = false
                // Remove row in existing table
                let prefixIndexPath = IndexPath(row: 5 + (user.hasAdminRights ? 1 : 0)
                                                       + (UploadVars.resizeImageOnUpload ? 2 : 0)
                                                       + (UploadVars.compressImageOnUpload ? 1 : 0),
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


extension SettingsViewController {
    
    @objc func onKeyboardAppear(_ notification: NSNotification) {
        guard let info = notification.userInfo,
              let kbInfo = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let window = settingsTableView.window,
              let editedRow = editedRow,
              let cell = settingsTableView.cellForRow(at: editedRow)
        else { return }

        // Calc missing height
        let oldVertOffset = settingsTableView.contentOffset.y
        var missingHeight = settingsTableView.safeAreaInsets.top
        missingHeight += cell.frame.maxY - oldVertOffset
        missingHeight += kbInfo.height
        missingHeight += settingsTableView.safeAreaInsets.bottom
        missingHeight -= window.screen.bounds.height
        if missingHeight > 0 {
            // Update vertical inset and offset
            let insets = UIEdgeInsets(top: 0, left: 0, bottom: missingHeight, right: 0)
            settingsTableView.contentInset = insets
            let point = CGPointMake(0, oldVertOffset + missingHeight)
            settingsTableView.setContentOffset(point, animated: true)
        }
    }

    @objc func onKeyboardDisappear(_ notification: NSNotification) {
        // Reset content inset
        settingsTableView.contentInset = .zero
    }
}
