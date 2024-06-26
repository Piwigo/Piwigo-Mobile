//
//  LoginViewController+UITextField.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 25/06/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import UIKit
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
