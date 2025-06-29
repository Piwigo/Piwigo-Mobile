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
        let row = rowAt(indexPath: indexPath)
        switch EditImageParamsOrder(rawValue: row) {
        case .imageName, .author:
            // Will tell onKeyboardDidShow() which cell is being edited
            editedRow = indexPath

            // Hide picker if necessary
            let indexPath = IndexPath(row: EditImageParamsOrder.datePicker.rawValue, section: 0)
            if hasDatePicker {
                // Found a picker, so remove it
                hasDatePicker = false
                editImageParamsTableView.beginUpdates()
                editImageParamsTableView.deleteRows(at: [indexPath], with: .fade)
                editImageParamsTableView.endUpdates()
            }
            
        case .date:
            // Dismiss the keyboard
            view.endEditing(true)

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

            // Show date or hide picker
            let indexPath = IndexPath(row: EditImageParamsOrder.datePicker.rawValue, section: 0)
            if hasDatePicker {
                // Found a picker, so remove it
                hasDatePicker = false
                editImageParamsTableView.beginUpdates()
                editImageParamsTableView.deleteRows(at: [indexPath], with: .fade)
                editImageParamsTableView.endUpdates()
            } else {
                // Didn't find a picker, so we should insert it
                hasDatePicker = true
                editImageParamsTableView.beginUpdates()
                editImageParamsTableView.insertRows(at: [indexPath], with: .fade)
                editImageParamsTableView.endUpdates()
            }

            // Prevent keyboard from opening
            return false
        default:
            break
        }

        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        let row = rowAt(indexPath: IndexPath(row: textField.tag, section: 0))
        switch EditImageParamsOrder(rawValue: row) {
            case .imageName:
                // Title
                shouldUpdateTitle = true
                textField.textColor = .piwigoColorOrange()
            case .author:
                // Author
                shouldUpdateAuthor = true
                textField.textColor = .piwigoColorOrange()
            default:
                break
        }
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        guard let finalString = (textField.text as NSString?)?.replacingCharacters(in: range, with: string)
        else { return false }

        let row = rowAt(indexPath: IndexPath(row: textField.tag, section: 0))
        switch EditImageParamsOrder(rawValue: row) {
            case .imageName:
                // Title
                commonTitle = finalString.htmlToAttributedString
            case .author:
                // Author
                commonAuthor = finalString
            default:
                break
        }
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        let row = rowAt(indexPath: IndexPath(row: textField.tag, section: 0))
        switch EditImageParamsOrder(rawValue: row) {
            case .imageName:
                // Title
                commonTitle = "".htmlToAttributedString
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
        let row = rowAt(indexPath: IndexPath(row: textField.tag, section: 0))
        switch EditImageParamsOrder(rawValue: row) {
            case .imageName:
                // Title
                commonTitle = (textField.text ?? "").htmlToAttributedString
            case .author:
                // Author
                commonAuthor = textField.text ?? ""
            default:
                break
        }
    }
}
