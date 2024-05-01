//
//  LoginViewController+Keyboard.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 07/01/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import UIKit

extension LoginViewController
{    
    @objc func onKeyboardWillShow(_ notification: NSNotification) {
        guard let info = notification.userInfo,
              let kbInfo = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let window = view.window
        else { return }

        // Calc intersection between the keyboard's frame and the view's bounds
        let fromCoordinateSpace = window.screen.coordinateSpace
        let toCoordinateSpace: UICoordinateSpace = scrollView
        let convertedKeyboardFrameEnd = fromCoordinateSpace.convert(kbInfo, to: toCoordinateSpace)
        let viewIntersection = scrollView.bounds.intersection(convertedKeyboardFrameEnd)

        // Calc missing height
        let oldVertOffset: CGFloat = scrollView.contentOffset.y
        var missingHeight = loginButton.frame.maxY - oldVertOffset
        missingHeight += viewIntersection.height + CGFloat(3)
        missingHeight -= scrollView.bounds.height

        // Update vertical inset and offset if needed
        if missingHeight > CGFloat.zero {
            // Update vertical inset and offset
            let insets = UIEdgeInsets(top: CGFloat.zero, left: CGFloat.zero, bottom: missingHeight, right: CGFloat.zero)
            scrollView.contentInset = insets
            let point = CGPointMake(0, oldVertOffset + missingHeight)
            scrollView.setContentOffset(point, animated: true)
        }
    }

    @objc func onKeyboardWillHide(_ notification: NSNotification) {
        scrollView.contentInset = .zero
    }
}
