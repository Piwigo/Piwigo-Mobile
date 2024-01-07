//
//  EditImageParamsViewController+UITextView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 31/12/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

// MARK: - UITextViewDelegate Methods
extension EditImageParamsViewController: UITextViewDelegate
{
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        // Hide picker if necessary
        let indexPath = IndexPath(row: EditImageParamsOrder.datePicker.rawValue, section: 0)
        if hasDatePicker {
            // Found a picker, so remove it
            hasDatePicker = false
            editImageParamsTableView.beginUpdates()
            editImageParamsTableView.deleteRows(at: [indexPath], with: .fade)
            editImageParamsTableView.endUpdates()
        }
        
        // Will tell onKeyboardDidShow() which cell is being edited
        let row = editImageParamsTableView.numberOfRows(inSection: 0) - 1
        editedRow = IndexPath(row: row, section: 0)
        return true
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        shouldUpdateComment = true
        textView.textColor = .piwigoColorOrange()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let finalString = (textView.text as NSString).replacingCharacters(in: range, with: text)
        commonComment = finalString.htmlToAttributedString
        return true
    }

    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        editImageParamsTableView.endEditing(true)
        return true
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        commonComment = textView.text.htmlToAttributedString
    }
}
