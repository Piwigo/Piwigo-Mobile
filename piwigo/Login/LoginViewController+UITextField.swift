//
//  LoginViewController+UITextField.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 25/06/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import piwigoKit

// MARK: - UITextField Delegate Methods
extension LoginViewController: UITextFieldDelegate
{
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        // Disable HTTP login action until user provides credentials
        if let httpAlertController = httpAlertController {
            // Requesting autorisation to access non secure web site
            // or asking HTTP basic authentication credentials
            if (httpAlertController.textFields?.count ?? 0) > 0 {
                // Being requesting HTTP basic authentication credentials
                if textField == httpAlertController.textFields?[0] {
                    if (httpAlertController.textFields?[0].text?.count ?? 0) == 0 {
                        httpLoginAction?.isEnabled = false
                    }
                } else if textField == httpAlertController.textFields?[1] {
                    if (httpAlertController.textFields?[1].text?.count ?? 0) == 0 {
                        httpLoginAction?.isEnabled = false
                    }
                }
            }
        }
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        // Disable login buttons
        if textField == serverTextField {
            loginButton.isEnabled = false
        } else if let httpAlertController = httpAlertController {
            // Requesting autorisation to access non secure web site
            // or asking HTTP basic authentication credentials
            if (httpAlertController.textFields?.count ?? 0) > 0 {
                // Being requesting HTTP basic authentication credentials
                if (textField == httpAlertController.textFields?[0]) || (textField == httpAlertController.textFields?[1]) {
                    httpLoginAction?.isEnabled = false
                }
            }
        }

        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        let finalString = (textField.text as NSString?)?.replacingCharacters(in: range, with: string)

        if textField == serverTextField {
            // Disable Login button if URL invalid
            let _ = saveServerAddress(finalString, andUsername: userTextField.text)
            loginButton.isEnabled = true
        } else if let httpAlertController = httpAlertController {
            // Requesting autorisation to access non secure web site
            // or asking HTTP basic authentication credentials
            if (httpAlertController.textFields?.count ?? 0) > 0 {
                // Being requesting HTTP basic authentication credentials
                if (textField == httpAlertController.textFields?[0]) || (textField == httpAlertController.textFields?[1]) {
                    // Enable HTTP Login action if field not empty
                    httpLoginAction?.isEnabled = (finalString?.count ?? 0) >= 1
                }
            }
        }

        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == serverTextField {
            // Save server address and username to disk
            let validURL = saveServerAddress(serverTextField.text, andUsername: userTextField.text)
            loginButton.isEnabled = validURL
            if !validURL {
                // Incorrect URL
                showIncorrectWebAddressAlert()
                return false
            }

            // User entered acceptable server address
            userTextField.becomeFirstResponder()
        }
        else if textField == userTextField {
            // User entered username
            let pwd = KeychainUtilities.password(forService: NetworkVars.serverPath,
                                                 account: userTextField.text ?? "")
            passwordTextField.text = pwd
            passwordTextField.becomeFirstResponder()
        }
        else if textField == passwordTextField {
            // User entered password —> Launch login
            launchLogin()
        }
        return true
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        if textField == serverTextField {
            // Save server address and username to disk
            let validURL = saveServerAddress(serverTextField.text, andUsername: userTextField.text)
            loginButton.isEnabled = validURL
            if !validURL {
                // Incorrect URL
                showIncorrectWebAddressAlert()
                return false
            }
        }
        return true
    }
}


extension LoginViewController {
    
    @objc func onKeyboardAppear(_ notification: NSNotification) {
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

        // Calc missing height
        let oldVertOffset = scrollView.contentOffset.y
        var missingHeight = scrollView.safeAreaInsets.top
        missingHeight += activeFieldBottom - oldVertOffset
        missingHeight += kbInfo.height
        missingHeight += scrollView.safeAreaInsets.bottom
        missingHeight -= window.screen.bounds.height
        if missingHeight > 0 {
            // Update vertical inset and offset
            let insets = UIEdgeInsets(top: 0, left: 0, bottom: missingHeight, right: 0)
            scrollView.contentInset = insets
            let point = CGPointMake(0, oldVertOffset + missingHeight)
            scrollView.setContentOffset(point, animated: true)
        }
    }

    @objc func onKeyboardDisappear(_ notification: NSNotification) {
        scrollView.contentInset = .zero
    }
}
