//
//  TagsViewController+Add.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

extension TagsViewController
{
    // MARK: - Add tag (for admins only)
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
        alert.view.tintColor = .piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = .piwigoColorOrange()
        }
    }

    func addTag(withName tagName: String?) {
        // Check tag name
        guard let tagName = tagName, tagName.count != 0 else {
            return
        }
        
        // Display HUD during the update
        showPiwigoHUD(withTitle: NSLocalizedString("tagsAddHUD_label", comment: "Creating Tag…"))

        // Add new tag
        DispatchQueue.global(qos: .userInteractive).async {
            self.tagsProvider.addTag(with: tagName, completionHandler: { error in
                guard let error = error else {
                    self.updatePiwigoHUDwithSuccess {
                        self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD, completion: {})
                    }
                    return
                }
                self.hidePiwigoHUD {
                    self.dismissPiwigoError(
                        withTitle: NSLocalizedString("tagsAddError_title", comment: "Create Fail"),
                        message: NSLocalizedString("tagsAddError_message", comment: "Failed to…"),
                        errorMessage: error.localizedDescription, completion: { })
                }
            })
        }
    }
}


// MARK: - UITextFieldDelegate Methods
extension TagsViewController: UITextFieldDelegate
{
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        // Disable Add/Delete Category action
        addAction?.isEnabled = false
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Enable Add/Delete Tag action if text field not empty
        let finalString = (textField.text as NSString?)?.replacingCharacters(in: range, with: string)
        let allTags = tagsProvider.fetchedResultsController.fetchedObjects ?? []
        let existTagWithName = (allTags.first(where: {$0.tagName == finalString}) != nil)
        addAction?.isEnabled = (((finalString?.count ?? 0) >= 1) && !existTagWithName)
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        // Disable Add/Delete Category action
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
