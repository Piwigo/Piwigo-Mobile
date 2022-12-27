//
//  AlbumCollectionViewCell+Delete.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 25/12/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import piwigoKit

extension AlbumCollectionViewCell {
    // MARK: - Delete Category
    func deleteCategory() {
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
                    if NetworkVars.usesCalcOrphans, nbOrphans == Int64.zero {
                        // There will be no more orphans after the album deletion
                        deleteCategory(withDeletionMode: .none,
                                       andViewController: topViewController)
                    } else {
                        // There will be orphans, ask confirmation
                        confirmCategoryDeletion(withNumberOfImages: albumData.totalNbImages,
                                                deletionMode: .none,
                                                andViewController: topViewController)
                    }
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
                                         deletionMode: pwgAlbumDeletionMode,
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
                               deletionMode: pwgAlbumDeletionMode,
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

    private func deleteCategory(withDeletionMode deletionMode: pwgAlbumDeletionMode,
                                andViewController topViewController: UIViewController?) {
        guard let albumData = albumData else { return }

        // Delete the category
        AlbumUtilities.delete(albumData.pwgID, inMode: deletionMode) {

            // Remove this album from the auto-upload destination
            if UploadVars.autoUploadCategoryId == albumData.pwgID {
                UploadVars.autoUploadCategoryId = Int32.min
            }

            // Close HUD, hide swipe button, remove album and images from cache
            topViewController?.updatePiwigoHUDwithSuccess() { [self] in
                topViewController?.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { [self] in
                    // Hide swipe buttons
                    let cell = tableView?.cellForRow(at: IndexPath(row: 0, section: 0)) as? AlbumTableViewCell
                    cell?.hideSwipe(animated: true)

                    // Delete album and images from cache and update UI
                    categoryDelegate?.deleteCategory(albumData.pwgID, inParent: albumData.parentId,
                                                     inMode: deletionMode)
                }
            }
        } failure: { error in
            topViewController?.hidePiwigoHUD() {
                topViewController?.dismissPiwigoError(withTitle: NSLocalizedString("deleteCategoryError_title", comment: "Delete Fail"), message: NSLocalizedString("deleteCategoryError_message", comment: "Failed to delete your album"), errorMessage: error.localizedDescription) {
                }
            }
        }
    }
}
