//
//  AlbumCollectionViewCell+Rename.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 25/12/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

extension AlbumCollectionViewCell {
    // MARK: - Rename Category
    func renameCategory() {
        guard let albumData = albumData else { return }

        // Determine the present view controller
        let topViewController = window?.topMostViewController()

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
            style: .cancel, handler: { [self] action in
                // Hide swipe buttons
                let cell = tableView?.cellForRow(at: IndexPath(row: 0, section: 0)) as? AlbumTableViewCell
                cell?.hideSwipe(animated: true)
            })

        renameAction = UIAlertAction(
            title: NSLocalizedString("renameCategory_button", comment: "Rename"),
            style: .default, handler: { [self] action in
                // Rename album if possible
                if (self.renameAlert?.textFields?.first?.text?.count ?? 0) > 0 {
                    renameCategory(withName: self.renameAlert?.textFields?.first?.text,
                                   comment: self.renameAlert?.textFields?.last?.text,
                                   andViewController: topViewController)
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
            topViewController?.present(alert, animated: true) { [self] in
                // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                renameAlert?.view.tintColor = UIColor.piwigoColorOrange()
            }
        }
    }

    func shouldEnableActionWith(newName: String?, newDescription: String?) -> Bool {
        // Renaming the album is not possible with a nil or an empty string.
        guard let newAlbumName = newName, newAlbumName.isEmpty == false else {
            return false
        }
        // Get the old album name
        guard let oldAlbumName = albumData?.name else {
            // Old album name is nil (should never happen)
            return true
        }
        // Compare with the old album name
        if newAlbumName != oldAlbumName {
            return true
        }
        // Changing the album description is not possible with a nil.
        guard let newAlbumDesc = newDescription?.htmlToAttributedString else {
            return false
        }
        // Get the old album description
        guard let oldAlbumDesc = albumData?.comment else {
            // Old album description is nil
            return newAlbumDesc.string.isEmpty ? false : true
        }
        // Compare the old and new album descriptions
        return (oldAlbumDesc != newAlbumDesc)
    }
    
    private func renameCategory(withName albumName: String?, comment albumComment: String?,
                                andViewController topViewController: UIViewController?) {
        guard let albumId = albumData?.pwgID,
              let albumName = albumName,
              let albumComment = albumComment else { return }

        // Display HUD during the update
        topViewController?.showPiwigoHUD(withTitle: NSLocalizedString("renameCategoryHUD_label", comment: "Renaming Album…"), detail: "", buttonTitle: "", buttonTarget: nil, buttonSelector: nil, inMode: .indeterminate)

        // Rename album, modify comment
        AlbumUtilities.setInfos(albumId, withName: albumName, description: albumComment) { [self] in
            DispatchQueue.main.async { [self] in
                // Update album in cache and cell
                if albumData?.name != albumName {
                    albumData?.name = albumName
                }
                if albumData?.comment.string != albumComment {
                    albumData?.comment = albumComment.htmlToAttributedString
                }
                do {
                    try savingContext?.save()
                } catch let error as NSError {
                    print("Could not fetch \(error), \(error.userInfo)")
                }
                
                // Hide HUD and swipe button
                topViewController?.updatePiwigoHUDwithSuccess() { [self] in
                    topViewController?.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { [self] in
                        // Update cell and hide swipe buttons
                        let cell = tableView?.cellForRow(at: IndexPath(row: 0, section: 0)) as? AlbumTableViewCell
                        cell?.hideSwipe(animated: true)
                    }
                }
            }
        } failure: { error in
            topViewController?.hidePiwigoHUD() {
                topViewController?.dismissPiwigoError(withTitle: NSLocalizedString("renameCategoyError_title", comment: "Rename Fail"), message: NSLocalizedString("renameCategoyError_message", comment: "Failed to rename your album"), errorMessage: error.localizedDescription) {
                }
            }
        }
    }
}

