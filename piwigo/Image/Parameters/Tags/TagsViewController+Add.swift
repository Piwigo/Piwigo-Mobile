//
//  TagsViewController+Add.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

extension TagsViewController
{
    // MARK: - Add tag (for admins only)
    @MainActor
    @objc func requestNewTagName() {
        let alert = UIAlertController(title: NSLocalizedString("tagsAdd_title", comment: "Add Tag"), message: NSLocalizedString("tagsAdd_message", comment: "Enter a name for this new tag"), preferredStyle: .alert)

        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = NSLocalizedString("tagsAdd_placeholder", comment: "New tag")
            textField.clearButtonMode = .always
            textField.keyboardType = .default
            textField.keyboardAppearance = AppVars.shared.isDarkPaletteActive ? .dark : .default
            textField.autocapitalizationType = .sentences
            textField.autocorrectionType = .yes
            textField.returnKeyType = .continue
            textField.delegate = self
        })

        let cancelAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"), style: .cancel, handler: { action in
            })

        addAction = UIAlertAction(title: NSLocalizedString("alertAddButton", comment: "Add"), style: .default, handler: { action in
            // Rename album if possible
            if (alert.textFields?.first?.text?.count ?? 0) > 0 {
                self.addTag(withName: alert.textFields?.first?.text)
            }
        })

        alert.addAction(cancelAction)
        if let addAction = addAction {
            alert.addAction(addAction)
        }
        alert.view.tintColor = PwgColor.tintColor
        alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = PwgColor.tintColor
        }
    }

    @MainActor
    func addTag(withName tagName: String?) {
        // Check tag name
        guard let tagName = tagName, tagName.count != 0
        else { return }
        
        // Display HUD during the update
        showHUD(withTitle: NSLocalizedString("tagsAddHUD_label", comment: "Creating Tag…"))

        // Add new tag
        DispatchQueue.global(qos: .userInteractive).async {
            self.tagProvider.addTag(with: tagName) { error in
                DispatchQueue.main.async {
                    guard let error = error else {
                        self.updateHUDwithSuccess {
                            self.hideHUD(afterDelay: pwgDelayHUD, completion: {})
                        }
                        return
                    }
                    self.hideHUD {
                        self.dismissPiwigoError(
                            withTitle: NSLocalizedString("tagsAddError_title", comment: "Create Fail"),
                            message: NSLocalizedString("tagsAddError_message", comment: "Failed to…"),
                            errorMessage: error.localizedDescription, completion: { })
                    }
                }
            }
        }
    }
}


// MARK: - UITextFieldDelegate Methods
extension TagsViewController: UITextFieldDelegate
{
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        // Initialise tag name list
        allTagNames = Set((selectedTags.fetchedObjects ?? []).map({$0.tagName}))
        allTagNames.formUnion(Set(nonSelectedTags.fetchedObjects ?? []).map({$0.tagName}))

        // Disable Add action
        addAction?.isEnabled = false
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Enable Add action if text field not empty and tag name is not a duplicate
        if let text = textField.text,
           let textRange = Range(range, in: text) {
            let updatedText = text.replacingCharacters(in: textRange, with: string)
            addAction?.isEnabled = !updatedText.isEmpty && !allTagNames.contains(updatedText)
        }
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        // Disable Add action
        addAction?.isEnabled = false
        return true
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return true
    }
}
