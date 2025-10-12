//
//  EditImageParamsViewController+UITextField.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 31/12/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit


// MARK: - UITextFieldDelegate Methods
extension EditImageParamsViewController: UITextFieldDelegate
{
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        let indexPath = IndexPath(row: textField.tag, section: 0)
        switch EditImageParamsOrder(rawValue: textField.tag) {
        case .imageName, .author:
            // Will tell onKeyboardDidShow() which cell is being edited
            editedRow = indexPath
            
            // Hide picker if necessary
            removePickersIfNeeded()
            
        case .date:
            // Dismiss the keyboard
            view.endEditing(true)
            
            // The common date can be distant past (i.e. unset)
            // or before "1900-01-08 00:00:00" i.e. a week after unknown date
            checkDateValidity(andReloadRowAt: indexPath)
            
            // Hide time picker if necessary
            if hasTimePicker {
                hasTimePicker.toggle()
                let rowIndex = EditImageParamsOrder.timePicker.rawValue - (hasDatePicker ? 0 : 1)
                removePicker(at: IndexPath(row: rowIndex, section: 0))
            }
            
            // Show/hide date picker
            let indexPath = IndexPath(row: EditImageParamsOrder.datePicker.rawValue, section: 0)
            hasDatePicker.toggle()
            hasDatePicker ? insertPicker(at: indexPath) : removePicker(at: indexPath)
            
            // Prevent keyboard from opening
            return false
            
        case .time:
            // Dismiss the keyboard
            view.endEditing(true)
            
            // The common date can be distant past (i.e. unset)
            // or before "1900-01-08 00:00:00" i.e. a week after unknown date
            checkDateValidity(andReloadRowAt: indexPath)
            
            // Hide date picker if needd
            if hasDatePicker {
                hasDatePicker.toggle()
                let rowIndex = EditImageParamsOrder.datePicker.rawValue
                removePicker(at: IndexPath(row: rowIndex, section: 0))
            }
            
            // Show/hide time picker
            let rowIndex = EditImageParamsOrder.timePicker.rawValue - (hasDatePicker ? 0 : 1)
            let indexPath = IndexPath(row: rowIndex, section: 0)
            hasTimePicker.toggle()
            hasTimePicker ? insertPicker(at: indexPath) : removePicker(at: indexPath)
            
            // Prevent keyboard from opening
            return false
            
        default:
            break
        }
        
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        switch EditImageParamsOrder(rawValue: textField.tag) {
        case .imageName:
            // Title
            shouldUpdateTitle = true
            textField.textColor = PwgColor.orange
        case .author:
            // Author
            shouldUpdateAuthor = true
            textField.textColor = PwgColor.orange
        default:
            break
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        guard let finalString = (textField.text as NSString?)?.replacingCharacters(in: range, with: string)
        else { return false }
        
        switch EditImageParamsOrder(rawValue: textField.tag) {
        case .imageName:
            // Title
            commonTitle = finalString
        case .author:
            // Author
            commonAuthor = finalString
        default:
            break
        }
        return true
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        switch EditImageParamsOrder(rawValue: textField.tag) {
        case .imageName:
            // Title
            commonTitle = ""
        case .author:
            // Author
            commonAuthor = ""
        default:
            break
        }
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        editImageParamsTableView.endEditing(true)
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        switch EditImageParamsOrder(rawValue: textField.tag) {
        case .imageName:
            // Title
            commonTitle = textField.text ?? ""
        case .author:
            // Author
            commonAuthor = textField.text ?? ""
        default:
            break
        }
    }
    
    private func checkDateValidity(andReloadRowAt indexPath: IndexPath) {
        // The common date can be distant past (i.e. unset)
        // or before "1900-01-08 00:00:00" i.e. a week after unknown date
        if commonDateCreated < DateUtilities.weekAfter {
            // Define date as today in UTC
            let currentDate = Date()
            var calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: currentDate)
            calendar.timeZone = TimeZone(abbreviation: "UTC")!
            commonDateCreated = calendar.date(from: components)!
            shouldUpdateDateCreated = true
            
            // Update creation date
            editImageParamsTableView.reloadRows(at: [indexPath], with: .automatic)
        }
    }
    
    private func insertPicker(at indexPath: IndexPath) {
        editImageParamsTableView.beginUpdates()
        editImageParamsTableView.insertRows(at: [indexPath], with: .fade)
        editImageParamsTableView.endUpdates()
    }
    
    func removePicker(at indexPath: IndexPath) {
        editImageParamsTableView.beginUpdates()
        editImageParamsTableView.deleteRows(at: [indexPath], with: .fade)
        editImageParamsTableView.endUpdates()
    }
    
    func removePickersIfNeeded() {
        if hasDatePicker {
            // Found date picker, remove it
            hasDatePicker.toggle()
            let rowIndex = EditImageParamsOrder.datePicker.rawValue
            removePicker(at: IndexPath(row: rowIndex, section: 0))
        }
        if hasTimePicker {
            // Found time picker, remove it
            hasTimePicker.toggle()
            let rowIndex = EditImageParamsOrder.timePicker.rawValue - (hasDatePicker ? 0 : 1)
            removePicker(at: IndexPath(row: rowIndex, section: 0))
        }
    }
}
