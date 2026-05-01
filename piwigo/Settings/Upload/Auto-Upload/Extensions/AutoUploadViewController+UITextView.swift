//
//  AutoUploadViewController+UITextView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/01/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

// MARK: - UITextViewDelegate Methods
extension AutoUploadViewController : UITextViewDelegate {
    // Update comments and store them
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let oldText = textView.text as NSString
        let finalString = oldText.replacingCharacters(in: range, with: text)
        UploadVars.shared.autoUploadComments = finalString
        return true
    }

    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        autoUploadTableView.endEditing(true)
        return true
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        UploadVars.shared.autoUploadComments = textView.text
    }
}


extension AutoUploadViewController
{    
    @objc func onKeyboardAppear(_ notification: NSNotification) {
        guard let info = notification.userInfo,
              let kbInfo = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let window = autoUploadTableView.window,
              let cell = autoUploadTableView.cellForRow(at: IndexPath(row: 1, section: 2))
        else { return }

        // Calc intersection between the keyboard's frame and the view's bounds
        let fromCoordinateSpace = window.screen.coordinateSpace
        let toCoordinateSpace: any UICoordinateSpace = autoUploadTableView
        let convertedKeyboardFrameEnd = fromCoordinateSpace.convert(kbInfo, to: toCoordinateSpace)
        let viewIntersection = autoUploadTableView.bounds.intersection(convertedKeyboardFrameEnd)

        // Calc height required to allow full scrolling
        let oldVertOffset = autoUploadTableView.contentOffset.y
        var missingHeight = cell.frame.maxY - oldVertOffset
        missingHeight += viewIntersection.height
        missingHeight -= autoUploadTableView.contentSize.height
        if missingHeight > 0 {
            // Extend content view to allow full scrolling
            var insets = autoUploadTableView.contentInset
            insets.bottom += missingHeight
            autoUploadTableView.contentInset = insets

            // Scroll cell to make it visible if necessary
            if cell.frame.maxY - viewIntersection.minY > CGFloat.zero {
                let point = CGPointMake(0, oldVertOffset + missingHeight )
                autoUploadTableView.setContentOffset(point, animated: true)
            }
        }
    }

    @objc func onKeyboardDisappear(_ notification: NSNotification) {
        // Reset content inset and offset
        autoUploadTableView.contentInset = .zero
    }
}
