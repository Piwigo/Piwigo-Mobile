//
//  LoginViewController+Keyboard.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 07/01/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

extension LoginViewController
{    
    @objc func onKeyboardWillShow(_ notification: NSNotification) {
        guard let info = notification.userInfo,
              let kbInfo = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let window = view.window
        else { return }

        // Determine which field triggered the keyboard appearance
        var activeFieldBottom = 0.0
        if serverTextField.isFirstResponder {
            activeFieldBottom = userTextField.frame.maxY
        } else if userTextField.isFirstResponder {
            activeFieldBottom = passwordTextField.frame.maxY
        } else if passwordTextField.isFirstResponder {
            activeFieldBottom = loginButton.frame.maxY
        }

        // Calc intersection between the keyboard's frame and the view's bounds
        let fromCoordinateSpace = window.screen.coordinateSpace
        let toCoordinateSpace: UICoordinateSpace = scrollView
        let convertedKeyboardFrameEnd = fromCoordinateSpace.convert(kbInfo, to: toCoordinateSpace)
        let viewIntersection = scrollView.bounds.intersection(convertedKeyboardFrameEnd)

        // Calc missing height
        let oldVertOffset = scrollView.contentOffset.y
        var missingHeight = activeFieldBottom - oldVertOffset
        missingHeight += viewIntersection.height + 3.0
        missingHeight -= scrollView.bounds.height

        // Update vertical inset and offset if needed
        if missingHeight > 0 {
            // Update vertical inset and offset
            let insets = UIEdgeInsets(top: 0, left: 0, bottom: missingHeight, right: 0)
            scrollView.contentInset = insets
            let point = CGPointMake(0, oldVertOffset + missingHeight)
            scrollView.setContentOffset(point, animated: true)
        }
    }

    @objc func onKeyboardWillHide(_ notification: NSNotification) {
        scrollView.contentInset = .zero
    }
}
