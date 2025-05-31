//
//  UploadParametersViewController+UITextFieldDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 31/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

extension UploadParametersViewController: UITextFieldDelegate {
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        switch EditImageDetailsOrder(rawValue: textField.tag) {
        case .imageName:
            // Title
            shouldUpdateTitle = true
        case .author:
            // Author
            shouldUpdateAuthor = true
        default:
            break
        }
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let finalString = (textField.text as NSString?)?.replacingCharacters(in: range, with: string) else {
            return true
        }
        switch EditImageDetailsOrder(rawValue: textField.tag) {
        case .imageName:
            commonTitle = finalString
        case .author:
            commonAuthor = finalString
        default:
            break
        }
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        switch EditImageDetailsOrder(rawValue: textField.tag) {
        case .imageName:
            commonTitle = ""
        case .author:
            commonAuthor = ""
        default:
            break
        }
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        paramsTableView.endEditing(true)
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        switch EditImageDetailsOrder(rawValue: textField.tag) {
        case .imageName:
            if let typedText = textField.text {
                commonTitle = typedText
            }
            // Update cell
            let indexPath = IndexPath(row: EditImageDetailsOrder.imageName.rawValue, section: 0)
            paramsTableView.reloadRows(at: [indexPath], with: .automatic)
        case .author:
            if let typedText = textField.text {
                commonAuthor = typedText
            }
            // Update cell
            let indexPath = IndexPath(row: EditImageDetailsOrder.author.rawValue, section: 0)
            paramsTableView.reloadRows(at: [indexPath], with: .automatic)
        default:
            break
        }
    }
}
