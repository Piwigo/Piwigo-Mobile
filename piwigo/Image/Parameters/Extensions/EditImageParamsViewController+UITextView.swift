//
//  EditImageParamsViewController+UITextView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 31/12/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import UIKit

// MARK: - UITextViewDelegate Methods
extension EditImageParamsViewController: UITextViewDelegate
{
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        // Hide picker if necessary
        removePickersIfNeeded()

        // Will tell onKeyboardDidShow() which cell is being edited
        let rowIndex = EditImageParamsOrder.desc.rawValue - (hasDatePicker ? 0 : 1) - (hasTimePicker ? 0 : 1)
        editedRow = IndexPath(row: rowIndex, section: 0)
        return true
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        shouldUpdateComment = true
        textView.textColor = PwgColor.orange
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let finalString = (textView.text as NSString).replacingCharacters(in: range, with: text)
        commonComment = finalString
        return true
    }

    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        editImageParamsTableView.endEditing(true)
        return true
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        commonComment = textView.text
    }
}
