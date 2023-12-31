//
//  EditImageParamsViewController+UITextField.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 31/12/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

// MARK: - UITextFieldDelegate Methods
extension EditImageParamsViewController: UITextFieldDelegate
{
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField.tag == EditImageParamsOrder.date.rawValue {
            // The common date can be distant past (i.e. unset)
            if commonDateCreated == .distantPast {
                // Define date as today
                commonDateCreated = Date()
                shouldUpdateDateCreated = true

                // Update creation date
                let indexPath = IndexPath(row: EditImageParamsOrder.date.rawValue, section: 0)
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
        }

        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        switch EditImageParamsOrder(rawValue: textField.tag) {
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
        switch EditImageParamsOrder(rawValue: textField.tag) {
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
        switch EditImageParamsOrder(rawValue: textField.tag) {
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
        switch EditImageParamsOrder(rawValue: textField.tag) {
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
