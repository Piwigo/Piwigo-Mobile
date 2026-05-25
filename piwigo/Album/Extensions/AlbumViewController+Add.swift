//
//  AlbumViewController+Add.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import PwgKit
import PwgAPIKit
import PwgCacheKit
import PwgUIKit

extension AlbumViewController
{
    // MARK: Toolbar Buttons (iOS 26+)
    func getAddAlbumBarButton() -> UIBarButtonItem {
        let image = UIImage(systemName: "rectangle.stack.badge.plus")!
        let button = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(didTapCreateAlbum))
        button.accessibilityIdentifier = "org.piwigo.addAlbum"
        return button
    }
    
    func getAddImageBarButton() -> UIBarButtonItem {
        let image = UIImage(systemName: "photo.badge.plus")!
        let button = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(checkPhotoLibraryAccess))
        button.accessibilityIdentifier = "org.piwigo.addImages"
        return button
    }
    
    
    // MARK: - Create Sub-Album
    @MainActor
    @objc func didTapCreateAlbum() {
        // Hide CreateAlbum and UploadImages buttons
        hideOptionalButtons { [self] in
            // Hide Add and Home buttons
            hideButtons()
            
            // Present dialog for creating album
            showCreateCategoryDialog()
            
            // Reset action of Add button
            addButton.removeTarget(self, action: #selector(didCancelTapAddButton), for: .touchUpInside)
            addButton.addTarget(self, action: #selector(didTapAddButton), for: .touchUpInside)
        }
    }
    
    @MainActor
    func showCreateCategoryDialog() {
        let alert = UIAlertController(
            title: String(localized: "createNewAlbum_title", comment: "New Album"),
            message: String(localized: "createNewAlbum_message", comment: "Enter a name for this album:"),
            preferredStyle: .alert)

        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = String(localized: "createNewAlbum_placeholder", comment: "Album Name")
            textField.clearButtonMode = .always
            textField.keyboardType = .default
            textField.keyboardAppearance = InterfaceVars.shared.isDarkPaletteActive ? .dark : .default
            textField.autocapitalizationType = .sentences
            textField.autocorrectionType = .yes
            textField.returnKeyType = .continue
            textField.delegate = self
        })

        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = String(localized: "createNewAlbumDescription_placeholder", comment: "Description")
            textField.clearButtonMode = .always
            textField.keyboardType = .default
            textField.keyboardAppearance = InterfaceVars.shared.isDarkPaletteActive ? .dark : .default
            textField.autocapitalizationType = .sentences
            textField.autocorrectionType = .yes
            textField.returnKeyType = .continue
            textField.delegate = self
        })

        let cancelAction = UIAlertAction(
            title: String(localized: "alertCancelButton", comment: "Cancel"),
            style: .cancel, handler: { [self] action in
                // Cancel action
                if homeAlbumButton.isHidden {
                    didCancelTapAddButton()
                }
        })

        createAlbumAction = UIAlertAction(
            title: String(localized: "alertAddButton", comment: "Add"),
            style: .default, handler: { [self] action in
                // Create album
                let albumName = alert.textFields?.first?.text ?? String(localized: "categorySelection_title", comment: "Album")
                addCategory(withName: albumName, andComment: alert.textFields?.last?.text ?? "",
                            inParent: albumData)
        })

        alert.addAction(cancelAction)
        if let createAlbumAction = createAlbumAction {
            alert.addAction(createAlbumAction)
        }
        alert.view.tintColor = PwgColor.tintColor
        alert.view.accessibilityIdentifier = "CreateAlbum"
        alert.overrideUserInterfaceStyle = InterfaceVars.shared.isDarkPaletteActive ? .dark : .light
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = PwgColor.tintColor
        }
    }

    @MainActor
    func addCategory(withName albumName: String, andComment albumComment: String,
                     inParent albumData: Album) {
        // Prepare set of parent IDs before creating album (including root album)
        let hasAdminRights = user.hasAdminRights
        let parentIDs = Set(albumData.upperIds.components(separatedBy: ",")
            .compactMap({Int32($0)})).filter({$0 != albumData.pwgID}).union(Set([pwgSmartAlbum.root.rawValue]))
        
        // Display HUD during the update
        showHUD(withTitle: String(localized: "createNewAlbumHUD_label", comment: "Creating Album…"))

        // Send request to Piwigo server
        Task {
            do {
                // Check session
                try await LoginUtilities().checkSession(ofUserWithID: user.objectID, lastConnected: user.lastUsed)
                
                // Create album
                let newCatId = try await JSONManager.shared.create(withName: albumName, description: albumComment,
                                                                   status: "public", inAlbumWithId: albumData.pwgID)
                
                // Update parent album data
                let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
                for parentID in parentIDs {
                    // Don't fetch an album already being fetched
                    if AlbumVars.shared.isFetchingAlbumData.contains(parentID) { continue }
                    
                    // Remember that the app is fetching album data
                    AlbumVars.shared.isFetchingAlbumData.insert(parentID)

                    // Fetch album data recursively
                    let pwgData = try await JSONManager.shared.fetchAlbums(forUserWithAdminRights: hasAdminRights,
                                                                           inParentWithId: parentID,
                                                                           thumbnailSize: thumnailSize)
                    // Update cache
                    try AlbumProvider().importAlbums(pwgData, inParent: parentID)
                    
                    // Remove album from list of albums being fetched
                    AlbumVars.shared.isFetchingAlbumData.remove(parentID)
                }

                // Update UI
                await MainActor.run {
                    // Add created album to list of recently used albums
                    let userInfo = ["categoryId" : NSNumber.init(value: newCatId)]
                    NotificationCenter.default.post(name: Notification.Name.pwgAddRecentAlbum,
                                                    object: nil, userInfo: userInfo)
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
                }
            }
            catch let error as PwgKitError {
                self.addCategoryError(error)
            }
        }
    }
    
    @MainActor
    private func addCategoryError(_ error: PwgKitError) {
        self.hideHUD() { [self] in
            // Session logout required?
            if error.requiresLogout {
                ClearCache.closeSessionWithPwgError(from: self, error: error)
                return
            }
            
            // Report error
            let title = String(localized: "createAlbumError_title", comment: "Create Album Error")
            let message = String(localized: "createAlbumError_message", comment: "Failed to create a new album")
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
        if textField.placeholder == String(localized: "createNewAlbum_placeholder", comment: "Album Name") {
            createAlbumAction?.isEnabled = (textField.text?.count ?? 0) >= 1
        }
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Enable Add Category action if album name is non null
        if textField.placeholder == String(localized: "createNewAlbum_placeholder", comment: "Album Name") {
            let finalString = (textField.text as NSString?)?.replacingCharacters(in: range, with: string)
            createAlbumAction?.isEnabled = (finalString?.count ?? 0) >= 1
        }
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        // Disable Add Category action
        if textField.placeholder == String(localized: "createNewAlbum_placeholder", comment: "Album Name") {
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

