//
//  TagsViewController+Add.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import PwgKit
import PwgAPIKit
import PwgCacheKit
import PwgUIKit

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
            textField.keyboardAppearance = InterfaceVars.shared.isDarkPaletteActive ? .dark : .default
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
        alert.overrideUserInterfaceStyle = InterfaceVars.shared.isDarkPaletteActive ? .dark : .light
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
        Task {
            do {
                // Check session
                try await LoginUtilities().checkSession(ofUserWithID: user.objectID, lastConnected: user.lastUsed)
                
                // Add tag on server
                let tagData = try await JSONManager.shared.addTag(with: tagName)
                
                // Add tag to cache
                let _ = try TagProvider().importOneBatch([tagData], asAdmin: true, tagIDs: Set<Int32>())
                
                // Update UI
                await MainActor.run {
                    self.updateHUDwithSuccess {
                        self.hideHUD(afterDelay: pwgDelayHUD, completion: {})
                    }
                }
            }
            catch let error as PwgKitError {
                await MainActor.run {
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
