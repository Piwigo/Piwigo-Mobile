//
//  UploadParametersViewController+UITextViewDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 31/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

extension UploadParametersViewController: UITextViewDelegate {
    
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
        paramsTableView.endEditing(true)
        return true
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        commonComment = textView.text
    }
}
