//
//  AlbumRenaming.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 18/07/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import UIKit
import piwigoKit

// MARK: - Rename Album, Update Description
class AlbumRenaming: NSObject
{
    // Initialisation
    init(albumData: Album, user: User, mainContext: NSManagedObjectContext,
         topViewController: UIViewController) {
        self.albumData = albumData
        self.user = user
        self.mainContext = mainContext
        self.topViewController = topViewController
    }
    
    var albumData: Album
    var user: User
    var mainContext: NSManagedObjectContext
    var topViewController: UIViewController
    
    private var renameAlert: UIAlertController?
    private var renameAction: UIAlertAction?
    private enum textFieldTag: Int {
        case albumName = 1000, albumDescription
    }

    func displayAlert(completion: @escaping (Bool) -> Void)
    {
        renameAlert = UIAlertController(
            title: NSLocalizedString("renameCategory_title", comment: "Rename Album"),
            message: String(format: "%@ (%@):", NSLocalizedString("renameCategory_message", comment: "Enter a new name for this album"), albumData.name),
            preferredStyle: .alert)

        renameAlert?.addTextField(configurationHandler: { [self] textField in
            textField.placeholder = NSLocalizedString("createNewAlbum_placeholder", comment: "Album Name")
            textField.text = albumData.name
            textField.clearButtonMode = .always
            textField.keyboardType = .default
            textField.keyboardAppearance = AppVars.shared.isDarkPaletteActive ? .dark : .default
            textField.autocapitalizationType = .sentences
            textField.autocorrectionType = .yes
            textField.returnKeyType = .continue
            textField.delegate = self
            textField.tag = textFieldTag.albumName.rawValue
        })

        renameAlert?.addTextField(configurationHandler: { [self] textField in
            textField.placeholder = NSLocalizedString("createNewAlbumDescription_placeholder", comment: "Description")
            let attributedStr = NSMutableAttributedString(attributedString: albumData.comment)
            let wholeRange = NSRange(location: 0, length: attributedStr.string.count)
            let style = NSMutableParagraphStyle()
            style.alignment = NSTextAlignment.left
            let attributes = [
                NSAttributedString.Key.foregroundColor: UIColor.piwigoColorText(),
                NSAttributedString.Key.font: renameAlert?.textFields?.first?.font ?? UIFont.systemFont(ofSize: 13),
                NSAttributedString.Key.paragraphStyle: style
            ]
            attributedStr.addAttributes(attributes, range: wholeRange)
            textField.attributedText = attributedStr
            textField.clearButtonMode = .always
            textField.keyboardType = .default
            textField.keyboardAppearance = AppVars.shared.isDarkPaletteActive ? .dark : .default
            textField.autocapitalizationType = .sentences
            textField.autocorrectionType = .yes
            textField.returnKeyType = .continue
            textField.delegate = self
            textField.tag = textFieldTag.albumDescription.rawValue
        })

        let cancelAction = UIAlertAction(
            title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
            style: .cancel, handler: { action in
                // Hide swipe buttons
                completion(true)
            })

        renameAction = UIAlertAction(
            title: NSLocalizedString("renameCategory_button", comment: "Rename"),
            style: .default, handler: { [self] action in
                // Rename album if possible
                if (self.renameAlert?.textFields?.first?.text?.count ?? 0) > 0 {
                    renameAlbum(withName: self.renameAlert?.textFields?.first?.text,
                                comment: self.renameAlert?.textFields?.last?.text,
                                completion: completion)
                }
            })

        renameAlert?.addAction(cancelAction)
        if let renameAction = renameAction {
            renameAlert?.addAction(renameAction)
        }
        renameAlert?.view.tintColor = UIColor.piwigoColorOrange()
        if #available(iOS 13.0, *) {
            renameAlert?.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        if let alert = renameAlert {
            topViewController.present(alert, animated: true) { [self] in
                // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                renameAlert?.view.tintColor = UIColor.piwigoColorOrange()
            }
        }
    }
    
    private func renameAlbum(withName albumName: String?, comment albumComment: String?,
                             completion: @escaping (Bool) -> Void) {
        guard let albumName = albumName,
              let albumComment = albumComment else { return }

        // Display HUD during the update
        topViewController.showHUD(withTitle: NSLocalizedString("renameCategoryHUD_label", comment: "Renaming Album…"))

        // Rename album, modify comment
        PwgSession.checkSession(ofUser: user) {
            AlbumUtilities.setInfos(self.albumData.pwgID, withName: albumName, description: albumComment) { [self] in
                DispatchQueue.main.async { [self] in
                    // Hide swipe buttons
                    completion(true)

                    // Update album in cache and cell
                    if albumData.name != albumName {
                        albumData.name = albumName
                    }
                    if albumData.comment.string != albumComment {
                        albumData.comment = albumComment.htmlToAttributedString
                    }
                    do {
                        try mainContext.save()
                    } catch let error as NSError {
                        print("Could not save context, \(error.userInfo)")
                    }
                    
                    // Hide HUD
                    self.topViewController.updateHUDwithSuccess() {
                        self.topViewController.hideHUD(afterDelay: pwgDelayHUD) { }
                    }
                }
            } failure: { error in
                self.renameCategoryError(error, completion: completion)
            }
        } failure: { error in
            self.renameCategoryError(error, completion: completion)
        }
    }
    
    private func renameCategoryError(_ error: NSError, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            // Session logout required?
            if let pwgError = error as? PwgSessionError,
               [.invalidCredentials, .incompatiblePwgVersion, .invalidURL, .authenticationFailed]
                .contains(pwgError) {
                ClearCache.closeSessionWithPwgError(from: self.topViewController, error: pwgError)
                return
            }

            // Report error
            let title = NSLocalizedString("renameCategoyError_title", comment: "Rename Fail")
            let message = NSLocalizedString("renameCategoyError_message", comment: "Failed to rename your album")
            self.topViewController.hideHUD() {
                self.topViewController.dismissPiwigoError(withTitle: title, message: message,
                                                          errorMessage: error.localizedDescription) {
                    completion(true)
                }
            }
        }
    }
}


// MARK: - UITextField Delegate Methods
extension AlbumRenaming: UITextFieldDelegate
{
    private func shouldEnableActionWith(newName: String?, newDescription: String?) -> Bool {
        // Renaming the album is not possible with a nil or an empty string.
        guard let newAlbumName = newName, newAlbumName.isEmpty == false
        else { return false }
        
        // Compare with the old album name
        if newAlbumName != albumData.name {
            return true
        }
        
        // Changing the album description is not possible with a nil.
        guard let newAlbumDesc = newDescription?.htmlToAttributedString
        else { return false }
        
        // Compare the old and new album descriptions
        return (albumData.comment != newAlbumDesc)
    }

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        switch textFieldTag(rawValue: textField.tag) {
        case .albumName, .albumDescription:
            // Check both text fields
            let newName = renameAlert?.textFields?.first?.text
            let newDescription = renameAlert?.textFields?.last?.text
            renameAction?.isEnabled = shouldEnableActionWith(newName: newName,
                                                             newDescription: newDescription)
        case .none:
            renameAction?.isEnabled = false
        }
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        switch textFieldTag(rawValue: textField.tag) {
        case .albumName:
            // Check both text fields
            let newName = (textField.text as NSString?)?.replacingCharacters(in: range, with: string)
            let newDescription = renameAlert?.textFields?.last?.text
            renameAction?.isEnabled = shouldEnableActionWith(newName: newName,
                                                             newDescription: newDescription)
        case .albumDescription:
            // Check both text fields
            let newName = renameAlert?.textFields?.first?.text
            let newDescription = (textField.text as NSString?)?.replacingCharacters(in: range, with: string)
            renameAction?.isEnabled = shouldEnableActionWith(newName: newName,
                                                             newDescription: newDescription)
        case .none:
            renameAction?.isEnabled = false
        }
        return true
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        switch textFieldTag(rawValue: textField.tag) {
        case .albumName:
            // The album cannot be renamed with an empty string.
            renameAction?.isEnabled = false
        case .albumDescription:
            // The album cannot be renamed with an empty string or the same name.
            // Check both text fields
            let newName = renameAlert?.textFields?.first?.text
            renameAction?.isEnabled = shouldEnableActionWith(newName: newName,
                                                             newDescription: "")
        case .none:
            renameAction?.isEnabled = false
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
