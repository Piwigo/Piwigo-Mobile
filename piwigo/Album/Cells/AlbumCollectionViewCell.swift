//
//  AlbumCollectionViewCell.swift
//  piwigo
//
//  Created by Spencer Baker on 3/9/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5.4 by Eddy Lelièvre-Berna on 23/01/2022
//

import CoreData
import UIKit
import piwigoKit

@objc
protocol AlbumCollectionViewCellDelegate: NSObjectProtocol {
    func pushCategoryView(_ viewController: UIViewController?)
    func deleteCategory(_ albumId: Int32, nbImages: Int64)
}

class AlbumCollectionViewCell: UICollectionViewCell
{
    weak var categoryDelegate: AlbumCollectionViewCellDelegate?
    var albumData: Album? {
        didSet {
            tableView?.reloadData()
        }
    }
    var savingContext: NSManagedObjectContext?
    
    private var tableView: UITableView?
    private var renameAlert: UIAlertController?
    private var renameAction: UIAlertAction?
    private var deleteAction: UIAlertAction?
    private var nbOrphans = Int64.min
    private enum textFieldTag: Int {
        case albumName = 1000, albumDescription, nberOfImages
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        tableView = UITableView()
        tableView?.translatesAutoresizingMaskIntoConstraints = false
        tableView?.backgroundColor = UIColor.clear
        tableView?.separatorStyle = .none
        tableView?.register(UINib(nibName: "AlbumTableViewCell", bundle: nil),
                            forCellReuseIdentifier: "AlbumTableViewCell")
        tableView?.delegate = self
        tableView?.dataSource = self
        if let tableView = tableView {
            contentView.addSubview(tableView)
        }
        contentView.addConstraints(NSLayoutConstraint.constraintFillSize(tableView)!)

        NotificationCenter.default.addObserver(self, selector: #selector(autoUploadUpdated(_:)),
                                               name: .pwgAutoUploadEnabled, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(autoUploadUpdated(_:)),
                                               name: .pwgAutoUploadDisabled, object: nil)
    }

    @objc
    func applyColorPalette() {
        tableView?.reloadData()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        albumData = nil
    }

    @objc
    func autoUploadUpdated(_ notification: Notification?) {
        // Is this cell concerned?
        if UploadVars.autoUploadCategoryId != Int(albumData?.pwgID ?? 0)  { return }

        // Disallow user to delete the active auto-upload destination album
        let cell = tableView?.cellForRow(at: IndexPath(row: 0, section: 0)) as? AlbumTableViewCell
        cell?.refreshButtons(true)
    }

    deinit {
        renameAction = nil
        NotificationCenter.default.removeObserver(self, name: .pwgAutoUploadEnabled, object: nil)
        NotificationCenter.default.removeObserver(self, name: .pwgAutoUploadDisabled, object: nil)
    }

    
    // MARK: - Move Category
    private func moveCategory() {
        guard let albumData = albumData else { return }
        
        let moveSB = UIStoryboard(name: "SelectCategoryViewController", bundle: nil)
        guard let moveVC = moveSB.instantiateViewController(withIdentifier: "SelectCategoryViewController") as? SelectCategoryViewController else { return }
        if moveVC.setInput(parameter: albumData, for: .moveAlbum) {
            moveVC.albumMovedDelegate = self
            moveVC.savingContext = savingContext
            categoryDelegate?.pushCategoryView(moveVC)
        }
    }

    
    // MARK: - Rename Category
    private func renameCategory() {
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
            attributedStr.addAttribute(.foregroundColor, value: AppVars.shared.isDarkPaletteActive ? UIColor.white : UIColor.black, range: wholeRange)
            let style = NSMutableParagraphStyle()
            style.alignment = NSTextAlignment.left
            attributedStr.addAttribute(.paragraphStyle, value: style, range: wholeRange)
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

    private func shouldEnableActionWith(newName: String?, newDescription: String?) -> Bool {
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

    
    // MARK: - Delete Category
    private func deleteCategory() {
        guard let albumData = albumData else { return }

        // Determine the present view controller
        let topViewController = topMostController()

        let alert = UIAlertController(
            title: NSLocalizedString("deleteCategory_title", comment: "DELETE ALBUM"),
            message: String.localizedStringWithFormat(NSLocalizedString("deleteCategory_message", comment: "ARE YOU SURE YOU WANT TO DELETE THE ALBUM \"%@\" AND ALL %@ IMAGES?"), albumData.name, NSNumber(value: albumData.totalNbImages)),
            preferredStyle: .actionSheet)

        let cancelAction = UIAlertAction(
            title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
            style: .cancel, handler: { [self] action in
                // Hide swipe buttons
                let cell = tableView?.cellForRow(at: IndexPath(row: 0, section: 0)) as? AlbumTableViewCell
                cell?.hideSwipe(animated: true)
            })
        alert.addAction(cancelAction)

        if albumData.totalNbImages == 0 {
            // Empty album
            let emptyCategoryAction = UIAlertAction(
                title: NSLocalizedString("deleteCategory_empty", comment: "Delete Empty Album"),
                style: .destructive, handler: { [self] action in
                    // Display HUD during the deletion
                    topViewController?.showPiwigoHUD(withTitle: NSLocalizedString("deleteCategoryHUD_label", comment: "Deleting Album…"), detail: "", buttonTitle: "", buttonTarget: nil, buttonSelector: nil, inMode: .indeterminate)
                    
                    // Delete empty album
                    deleteCategory(withDeletionMode: .none,
                                   andViewController: topViewController)
                })
            alert.addAction(emptyCategoryAction)
        } else {
            // Album containing images
            let keepImagesAction = UIAlertAction(
                title: NSLocalizedString("deleteCategory_noImages", comment: "Keep Photos"),
                style: .default, handler: { [self] action in
                    confirmCategoryDeletion(withNumberOfImages: albumData.totalNbImages,
                                            deletionMode: .none,
                                            andViewController: topViewController)
                })
            alert.addAction(keepImagesAction)

            if NetworkVars.usesCalcOrphans == false ||
                (NetworkVars.usesCalcOrphans && nbOrphans == Int64.min) {
                let orphanImagesAction = UIAlertAction(
                    title: NSLocalizedString("deleteCategory_orphanedImages", comment: "Delete Orphans"),
                    style: .destructive,
                    handler: { [self] action in
                        confirmCategoryDeletion(withNumberOfImages: albumData.totalNbImages,
                                                deletionMode: .orphaned,
                                                andViewController: topViewController)
                    })
                alert.addAction(orphanImagesAction)
            }
            else if nbOrphans != 0 {
                let orphanImagesAction = UIAlertAction(
                    title: self.nbOrphans > 1 ? String.localizedStringWithFormat(NSLocalizedString("deleteCategory_severalOrphanedImages", comment: "Delete %@ Orphans"), NSNumber(value: self.nbOrphans)) : NSLocalizedString("deleteCategory_singleOrphanedImage", comment: "Delete Orphan"),
                    style: .destructive,
                    handler: { [self] action in
                        confirmCategoryDeletion(withNumberOfImages: albumData.totalNbImages,
                                                deletionMode: .orphaned,
                                                andViewController: topViewController)
                    })
                alert.addAction(orphanImagesAction)
            }

            let allImagesAction = UIAlertAction(
                title: albumData.totalNbImages > 1 ? String.localizedStringWithFormat(NSLocalizedString("deleteCategory_allImages", comment: "Delete %@ Images"), NSNumber(value: albumData.totalNbImages)) : NSLocalizedString("deleteSingleImage_title", comment: "Delete Image"),
                style: .destructive,
                handler: { [self] action in
                    confirmCategoryDeletion(withNumberOfImages: albumData.totalNbImages,
                                            deletionMode: .all,
                                            andViewController: topViewController)
                })
            allImagesAction.accessibilityIdentifier = "DeleteAll"
            alert.addAction(allImagesAction)
        }

        // Present list of actions
        alert.view.tintColor = UIColor.piwigoColorOrange()
        alert.view.accessibilityIdentifier = "DeleteAlbum"
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? UIUserInterfaceStyle.dark : UIUserInterfaceStyle.light
        } else {
            // Fallback on earlier versions
        }
        alert.popoverPresentationController?.sourceView = contentView
        alert.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection.unknown
        alert.popoverPresentationController?.sourceRect = contentView.frame
        topViewController?.present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange()
        }
    }

    private func confirmCategoryDeletion(withNumberOfImages number: Int64,
                                         deletionMode: pwgCategoryDeletionMode,
                                         andViewController topViewController: UIViewController?) {
        guard let albumData = albumData else { return }

        // Are you sure?
        let alert = UIAlertController(
            title: NSLocalizedString("deleteCategoryConfirm_title", comment: "Are you sure?"),
            message: String.localizedStringWithFormat(NSLocalizedString("deleteCategoryConfirm_message", comment: "Please enter the number of images in order to delete this album\nNumber of images: %@"), NSNumber(value: albumData.totalNbImages)),
            preferredStyle: .alert)

        alert.addTextField(configurationHandler: { [self] textField in
            textField.placeholder = "\(NSNumber(value: albumData.nbImages))"
            textField.keyboardAppearance = AppVars.shared.isDarkPaletteActive ? .dark : .default
            textField.clearButtonMode = .always
            textField.keyboardType = .numberPad
            textField.delegate = self
            textField.tag = textFieldTag.nberOfImages.rawValue
        })

        let defaultAction = UIAlertAction(
            title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
            style: .cancel,
            handler: { action in
            })

        deleteAction = UIAlertAction(
            title: NSLocalizedString("deleteCategoryConfirm_deleteButton", comment: "DELETE"),
            style: .destructive,
            handler: { [self] action in
                if (alert.textFields?.first?.text?.count ?? 0) > 0 {
                    checkDeletion(withNumberOfImages: Int(alert.textFields?.first?.text ?? "") ?? 0,
                                  deletionMode: deletionMode, andViewController: topViewController)
                }
            })
        deleteAction?.accessibilityIdentifier = "DeleteAll"

        alert.addAction(defaultAction)
        if let deleteAction = deleteAction {
            alert.addAction(deleteAction)
        }
        alert.view.tintColor = UIColor.piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        topViewController?.present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange()
        }
    }

    private func checkDeletion(withNumberOfImages number: Int,
                               deletionMode: pwgCategoryDeletionMode,
                               andViewController topViewController: UIViewController?) {
        guard let albumData = albumData else { return }

        // Check provided number of images
        if number != albumData.totalNbImages {
            topViewController?.dismissPiwigoError(withTitle: NSLocalizedString("deleteCategoryMatchError_title", comment: "Number Doesn't Match"), message: NSLocalizedString("deleteCategoryMatchError_message", comment: "The number of images you entered doesn't match the number of images in the category. Please try again if you desire to delete this album"), errorMessage: "") {
            }
            return
        }

        // Display HUD during the deletion
        topViewController?.showPiwigoHUD(withTitle: NSLocalizedString("deleteCategoryHUD_label", comment: "Deleting Album…"), detail: "", buttonTitle: "", buttonTarget: nil, buttonSelector: nil, inMode: .indeterminate)

        // Delete album (deleted images will remain in cache)
        deleteCategory(withDeletionMode: deletionMode, andViewController: topViewController)
    }

    private func deleteCategory(withDeletionMode deletionMode: pwgCategoryDeletionMode,
                                andViewController topViewController: UIViewController?) {
        guard let albumData = albumData else { return }

        // Delete the category
        AlbumUtilities.delete(albumData.pwgID, inMode: deletionMode) {

            // Remove this album from the auto-upload destination
            if UploadVars.autoUploadCategoryId == albumData.pwgID {
                UploadVars.autoUploadCategoryId = Int32.min
            }

            // Close HUD, hide swipe button, remove album from cache
            topViewController?.updatePiwigoHUDwithSuccess() { [self] in
                topViewController?.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { [self] in
                    // Hide swipe buttons
                    let cell = tableView?.cellForRow(at: IndexPath(row: 0, section: 0)) as? AlbumTableViewCell
                    cell?.hideSwipe(animated: true)

                    // Delete album from cache and update total number of images in parent album
                    let removedImages = deletionMode == .none ? Int64.zero : albumData.totalNbImages
                    categoryDelegate?.deleteCategory(albumData.pwgID, nbImages: removedImages)
                }
            }
        } failure: { error in
            topViewController?.hidePiwigoHUD() {
                topViewController?.dismissPiwigoError(withTitle: NSLocalizedString("deleteCategoryError_title", comment: "Delete Fail"), message: NSLocalizedString("deleteCategoryError_message", comment: "Failed to delete your album"), errorMessage: error.localizedDescription) {
                }
            }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}


// MARK: - UITableViewDataSource Methods
extension AlbumCollectionViewCell: UITableViewDataSource
{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "AlbumTableViewCell", for: indexPath) as? AlbumTableViewCell else {
            print("Error: tableView.dequeueReusableCell does not return a AlbumTableViewCell!")
            return AlbumTableViewCell()
        }
        
        // Configure cell
        cell.config(withAlbumData: albumData)
        
        // Album modifications are possible only if data are known
        if albumData != nil {
            cell.delegate = self
            cell.isAccessibilityElement = true
        }
        return cell
    }
}


// MARK: - UITableViewDelegate
extension AlbumCollectionViewCell: UITableViewDelegate
{
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 148.5 // see XIB file
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // Push new album view
        if categoryDelegate?.responds(to: #selector(AlbumCollectionViewCellDelegate.pushCategoryView(_:))) ?? false,
            let albumData = albumData {
            let albumView = AlbumViewController(albumId: albumData.pwgID)
            categoryDelegate?.pushCategoryView(albumView)
        }
    }
}


// MARK: - MGSwipeTableCellDelegate Methods
extension AlbumCollectionViewCell: MGSwipeTableCellDelegate
{
    func swipeTableCell(_ cell: MGSwipeTableCell, canSwipe direction: MGSwipeDirection,
                        from point: CGPoint) -> Bool {
        return true
    }
    
    func swipeTableCellWillBeginSwiping(_ cell: MGSwipeTableCell) {
        // Determine number of orphans if album deleted
        DispatchQueue.global(qos: .userInteractive).async { [unowned self] in
            self.nbOrphans = Int64.min
            guard let catId = albumData?.pwgID else { return }
            AlbumUtilities.calcOrphans(catId) { nbOrphans in
                self.nbOrphans = nbOrphans
            } failure: { _ in }
        }
    }

    func swipeTableCell(_ cell: MGSwipeTableCell, swipeButtonsFor direction: MGSwipeDirection, swipeSettings: MGSwipeSettings, expansionSettings: MGSwipeExpansionSettings) -> [UIView]?
    {
        guard let albumData = albumData else { return nil }

        // Only admins can rename, move and delete albums
        if !NetworkVars.hasAdminRights { return nil }

        // Settings
        cell.swipeBackgroundColor = UIColor.piwigoColorOrange()
        swipeSettings.transition = .border

        // Right => Left swipe
        if direction == .rightToLeft {
            let trash = MGSwipeButton(title: "", icon: UIImage(named: "swipeTrash.png"),
                backgroundColor: UIColor.red, callback: { [self] sender in
                    deleteCategory()
                    return false
                })
            let move = MGSwipeButton(title: "", icon: UIImage(named: "swipeMove.png"),
                backgroundColor: UIColor.piwigoColorBrown(), callback: { [self] sender in
                    moveCategory()
                    return false
                })
            let rename = MGSwipeButton(title: "", icon: UIImage(named: "swipeRename.png"),
                backgroundColor: UIColor.piwigoColorOrange(), callback: { [self] sender in
                    renameCategory()
                    return false
                })

            // Disallow user to delete the active auto-upload destination album
            if (UploadVars.autoUploadCategoryId == Int(albumData.pwgID)),
                UploadVars.isAutoUploadActive {
                return [move, rename]
            } else {
                expansionSettings.buttonIndex = 0
                return [trash, move, rename]
            }
        }
        return nil
    }
}


// MARK: - UITextField Delegate Methods
extension AlbumCollectionViewCell: UITextFieldDelegate
{
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        switch textFieldTag(rawValue: textField.tag) {
        case .albumName, .albumDescription:
            // Check both text fields
            let newName = renameAlert?.textFields?.first?.text
            let newDescription = renameAlert?.textFields?.last?.text
            renameAction?.isEnabled = shouldEnableActionWith(newName: newName,
                                                             newDescription: newDescription)
        case .nberOfImages:
            // The album deletion cannot be requested if a number of images is not provided.
            if let _ = Int(textField.text ?? "") {
                deleteAction?.isEnabled = true
            } else {
                deleteAction?.isEnabled = false
            }
        case .none:
            renameAction?.isEnabled = false
            deleteAction?.isEnabled = false
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
        case .nberOfImages:
            // The album deletion cannot be requested if a number of images is not provided.
            if let nberAsText = (textField.text as NSString?)?.replacingCharacters(in: range, with: string),
               let _ = Int(nberAsText) {
                deleteAction?.isEnabled = true
            } else {
                deleteAction?.isEnabled = false
            }
        case .none:
            renameAction?.isEnabled = false
            deleteAction?.isEnabled = false
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
        case .nberOfImages:
            // The album deletion cannot be requested if a number of images is not provided.
            deleteAction?.isEnabled = false
        case .none:
            renameAction?.isEnabled = false
            deleteAction?.isEnabled = false
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


// MARK: - SelectCategoryAlbumMovedDelegate Methods
extension AlbumCollectionViewCell: SelectCategoryAlbumMovedDelegate
{
    func didMoveCategory() {
        // Hide swipe commands
        let cell = tableView?.cellForRow(at: IndexPath(row: 0, section: 0)) as? AlbumTableViewCell
        cell?.hideSwipe(animated: true)

        // Remove category from the album/images collection
//        categoryDelegate?.moveCategory(self)
    }
}
