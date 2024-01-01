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
        editedRow = IndexPath(row: textField.tag, section: SettingsSection.imageUpload.rawValue)
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
              let screenCoordinateSpace = settingsTableView.window?.screen.coordinateSpace,
              let editedRow = editedRow,
              let cell = settingsTableView.cellForRow(at: editedRow)
        else {
            return }

        // Convert the keyboard's frame from the screen's coordinate space to the view's coordinate space
        let toCoordinateSpace: UICoordinateSpace = settingsTableView.coordinateSpace
        let kbFrame = screenCoordinateSpace.convert(kbInfo, to: toCoordinateSpace)
        
        // Calc missing height
        let missingHeight =  cell.frame.maxY - kbFrame.minY + 10.0
        if missingHeight > 0 {
            // Update table insets
            let insets = UIEdgeInsets(top: 0, left: 0, bottom: missingHeight, right: 0)
            settingsTableView.contentInset = insets
            settingsTableView.verticalScrollIndicatorInsets = insets
        }
    }

    @objc func onKeyboardDisappear(_ notification: NSNotification) {
        settingsTableView.contentInset = .zero
        settingsTableView.verticalScrollIndicatorInsets = .zero
    }
}
