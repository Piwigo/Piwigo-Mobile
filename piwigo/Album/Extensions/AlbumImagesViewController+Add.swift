//
//  AlbumImagesViewController+Add.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation


extension AlbumImagesViewController
{
    // MARK: - Create Sub-Album
    @objc func addAlbum() {
        // Change colour of Upload Images button
        createAlbumButton?.backgroundColor = UIColor.gray

        // Start creating album
        showCreateCategoryDialog()
    }

    func showCreateCategoryDialog() {
        let alert = UIAlertController(
            title: NSLocalizedString("createNewAlbum_title", comment: "New Album"),
            message: NSLocalizedString("createNewAlbum_message", comment: "Enter a name for this album:"),
            preferredStyle: .alert)

        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = NSLocalizedString("createNewAlbum_placeholder", comment: "Album Name")
            textField.clearButtonMode = .always
            textField.keyboardType = .default
            textField.keyboardAppearance = AppVars.shared.isDarkPaletteActive ? .dark : .default
            textField.autocapitalizationType = .sentences
            textField.autocorrectionType = .yes
            textField.returnKeyType = .continue
            textField.delegate = self
        })

        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = NSLocalizedString("createNewAlbumDescription_placeholder", comment: "Description")
            textField.clearButtonMode = .always
            textField.keyboardType = .default
            textField.keyboardAppearance = AppVars.shared.isDarkPaletteActive ? .dark : .default
            textField.autocapitalizationType = .sentences
            textField.autocorrectionType = .yes
            textField.returnKeyType = .continue
            textField.delegate = self
        })

        let cancelAction = UIAlertAction(
            title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
            style: .cancel, handler: { [self] action in
                // Cancel action
                if homeAlbumButton?.isHidden ?? false {
                    didCancelTapAddButton()
                }
        })

        createAlbumAction = UIAlertAction(
            title: NSLocalizedString("alertAddButton", comment: "Add"),
            style: .default, handler: { [self] action in
                // Create album
                let albumName = alert.textFields?.first?.text ?? NSLocalizedString("categorySelection_title", comment: "Album")
                addCategory(withName: albumName, andComment: alert.textFields?.last?.text ?? "",
                            inParent: categoryId)
        })

        alert.addAction(cancelAction)
        if let createAlbumAction = createAlbumAction {
            alert.addAction(createAlbumAction)
        }
        alert.view.tintColor = UIColor.piwigoColorOrange()
        alert.view.accessibilityIdentifier = "CreateAlbum"
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        }
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange()
        }
    }

    func addCategory(withName albumName: String, andComment albumComment: String,
                     inParent parentId: Int) {
        // Display HUD during the update
        showPiwigoHUD(withTitle: NSLocalizedString("createNewAlbumHUD_label", comment: "Creating Album…"), detail: "", buttonTitle: "", buttonTarget: nil, buttonSelector: nil, inMode: .indeterminate)

        // Create album
        AlbumUtilities.create(withName: albumName, description: albumComment,
                              status: "public", inParentWithId: parentId) { [self] newCatId in
            // Get index of added category
            if let categories = CategoriesData.sharedInstance().getCategoriesForParentCategory(categoryId),
               let indexOfExistingItem = categories.firstIndex(where: {$0.albumId == newCatId}) {
                // Insert cell of new category
                DispatchQueue.main.async { [self] in
                    let indexPath = IndexPath(item: indexOfExistingItem, section: 0)
                    imagesCollection?.insertItems(at: [indexPath])
                }
            }
            
            // Hide HUD
            updatePiwigoHUDwithSuccess() { [self] in
                hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { [self] in
                    // Reset buttons
                    didCancelTapAddButton()
                }
            }
        } failure: { error in
            self.hidePiwigoHUD() { [self] in
                dismissPiwigoError(withTitle: NSLocalizedString("createAlbumError_title", comment: "Create Album Error"), message: NSLocalizedString("createAlbumError_message", comment: "Failed to create a new album"), errorMessage: error.localizedDescription) { [self] in
                    // Reset buttons
                    didCancelTapAddButton()
                }
            }
        }
    }
}


// MARK: - UITextField Delegate Methods
extension AlbumImagesViewController: UITextFieldDelegate
{
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        // Disable Add Category action
        if textField.placeholder == NSLocalizedString("createNewAlbum_placeholder", comment: "Album Name") {
            createAlbumAction?.isEnabled = (textField.text?.count ?? 0) >= 1
        }
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Enable Add Category action if album name is non null
        if textField.placeholder == NSLocalizedString("createNewAlbum_placeholder", comment: "Album Name") {
            let finalString = (textField.text as NSString?)?.replacingCharacters(in: range, with: string)
            createAlbumAction?.isEnabled = (finalString?.count ?? 0) >= 1
        }
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        // Disable Add Category action
        if textField.placeholder == NSLocalizedString("createNewAlbum_placeholder", comment: "Album Name") {
            createAlbumAction?.isEnabled = false
        }
        return true
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return true
    }
}
