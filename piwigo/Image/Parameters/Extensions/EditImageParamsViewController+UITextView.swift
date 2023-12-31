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
