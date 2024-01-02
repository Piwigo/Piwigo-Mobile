//
//  AutoUploadViewController+UITextView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/01/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import piwigoKit

// MARK: - UITextViewDelegate Methods
extension AutoUploadViewController : UITextViewDelegate {
    // Update comments and store them
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let finalString = (textView.text as NSString).replacingCharacters(in: range, with: text)
        UploadVars.autoUploadComments = finalString
        return true
    }

    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        autoUploadTableView.endEditing(true)
        return true
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        UploadVars.autoUploadComments = textView.text
    }
}
