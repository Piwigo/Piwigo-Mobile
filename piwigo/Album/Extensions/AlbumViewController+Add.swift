//
//  AlbumViewController+Add.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

extension AlbumViewController
{
    // MARK: - Create Sub-Album
    @objc func addAlbum() {
        // Change colour of Upload Images button
        createAlbumButton.backgroundColor = UIColor.gray

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
                if homeAlbumButton.isHidden {
                    didCancelTapAddButton()
                }
        })

        createAlbumAction = UIAlertAction(
            title: NSLocalizedString("alertAddButton", comment: "Add"),
            style: .default, handler: { [self] action in
                // Create album
                let albumName = alert.textFields?.first?.text ?? NSLocalizedString("categorySelection_title", comment: "Album")
                addCategory(withName: albumName, andComment: alert.textFields?.last?.text ?? "",
                            inParent: albumData)
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
                     inParent albumData: Album) {
        // Display HUD during the update
        showHUD(withTitle: NSLocalizedString("createNewAlbumHUD_label", comment: "Creating Album…"))

        // Create album
        PwgSession.checkSession(ofUser: user) { [self] in
            AlbumUtilities.create(withName: albumName, description: albumComment,
                                  status: "public", inAlbumWithId: albumData.pwgID) { [self] newCatId in
                // Album successfully created ▶ Add new album to cache and update parent albums
                DispatchQueue.global(qos: .userInitiated).async { [self] in
                    self.albumProvider.addAlbum(newCatId, withName: albumName, comment: albumComment,
                                                inAlbumWithObjectID: albumData.objectID,
                                                forUserWithObjectID: user.objectID)
                }
                
                // Hide HUD
                updateHUDwithSuccess() { [self] in
                    hideHUD(afterDelay: pwgDelayHUD) { [self] in
                        // Reset buttons
                        didCancelTapAddButton()
                        // Scroll to top if necessary
                        let indexPath = IndexPath(item: 0, section: 0)
                        let visibleCells = collectionView.indexPathsForVisibleItems
                        if visibleCells.isEmpty == false, visibleCells.contains(indexPath) == false {
                            collectionView.scrollToItem(at: indexPath, at: .top, animated: true)
                        }
                    }
                }
            } failure: { [self] error in
                self.addCategoryError(error)
            }
        } failure: { [self] error in
            self.addCategoryError(error)
        }
    }
    
    private func addCategoryError(_ error: Error) {
        self.hideHUD() { [self] in
            // Session logout required?
            if let pwgError = error as? PwgSessionError,
               [.invalidCredentials, .incompatiblePwgVersion, .invalidURL, .authenticationFailed].contains(pwgError) {
                ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
                return
            }
            
            // Report error
            let title = NSLocalizedString("createAlbumError_title", comment: "Create Album Error")
            let message = NSLocalizedString("createAlbumError_message", comment: "Failed to create a new album")
            dismissPiwigoError(withTitle: title, message: message, errorMessage: error.localizedDescription) { [self] in
                // Reset buttons
                didCancelTapAddButton()
            }
        }
    }
}


// MARK: - UITextField Delegate Methods
extension AlbumViewController: UITextFieldDelegate
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

