//
//  AlbumDeletion.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 18/07/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import UIKit
import piwigoKit

class AlbumDeletion: NSObject
{
    // Initialisation
    init(albumData: Album, user: User, topViewController: UIViewController) {
        self.albumData = albumData
        self.user = user
        self.topViewController = topViewController
    }
    
    var albumData: Album
    var user: User
    var topViewController: UIViewController
    
    private var deleteAction: UIAlertAction?
    private var nbOrphans = Int64.min
    
    @MainActor
    func displayAlert(completion: @escaping (Bool) -> Void)
    {
        let alert = UIAlertController(
            title: NSLocalizedString("deleteCategory_title", comment: "DELETE ALBUM"),
            message: String.localizedStringWithFormat(NSLocalizedString("deleteCategory_message", comment: "ARE YOU SURE YOU WANT TO DELETE THE ALBUM \"%@\" AND ALL %lld IMAGES?"), albumData.name, albumData.totalNbImages),
            preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(
            title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
            style: .cancel, handler: { _ in
                // Hide swipe buttons
                completion(true)
            })
        alert.addAction(cancelAction)
        
        if albumData.totalNbImages == 0 {
            // Empty album
            let emptyCategoryAction = UIAlertAction(
                title: NSLocalizedString("deleteCategory_empty", comment: "Delete Empty Album"),
                style: .destructive, handler: { [self] action in
                    // Display HUD during the deletion
                    topViewController.showHUD(withTitle: NSLocalizedString("deleteCategoryHUD_label", comment: "Deleting Album…"))
                    
                    // Delete empty album
                    deleteAlbum(withDeletionMode: .none, completion: completion)
                })
            alert.addAction(emptyCategoryAction)
        } else {
            // Album containing images
            let keepImagesAction = UIAlertAction(
                title: NSLocalizedString("deleteCategory_noImages", comment: "Keep Photos"),
                style: .default, handler: { [self] action in
                    if NetworkVars.shared.usesCalcOrphans, nbOrphans == Int64.zero {
                        // There will be no more orphans after the album deletion
                        deleteAlbum(withDeletionMode: .none, completion: completion)
                    } else {
                        // There will be orphans, ask confirmation
                        confirmAlbumDeletion(withNumberOfImages: albumData.totalNbImages,
                                             deletionMode: .none, completion: completion)
                    }
                })
            alert.addAction(keepImagesAction)
            
            if NetworkVars.shared.usesCalcOrphans == false ||
                (NetworkVars.shared.usesCalcOrphans && nbOrphans == Int64.min) {
                let orphanImagesAction = UIAlertAction(
                    title: NSLocalizedString("deleteCategory_orphanedImages", comment: "Delete Orphans"),
                    style: .destructive,
                    handler: { [self] action in
                        confirmAlbumDeletion(withNumberOfImages: albumData.totalNbImages,
                                             deletionMode: .orphaned, completion: completion)
                    })
                alert.addAction(orphanImagesAction)
            }
            else if nbOrphans != 0 {
                let orphanImagesAction = UIAlertAction(
                    title: String.localizedStringWithFormat(NSLocalizedString("deleteCategory_severalOrphanedImages", comment: "Delete %lld Orphans"), self.nbOrphans),
                    style: .destructive,
                    handler: { [self] action in
                        confirmAlbumDeletion(withNumberOfImages: albumData.totalNbImages,
                                             deletionMode: .orphaned, completion: completion)
                    })
                alert.addAction(orphanImagesAction)
            }
            
            let allImagesAction = UIAlertAction(
                title: String.localizedStringWithFormat(NSLocalizedString("deleteSeveralImages_title", comment: "Delete %@ Photos/Videos"), NSNumber(value: albumData.totalNbImages)),
                style: .destructive,
                handler: { [self] action in
                    confirmAlbumDeletion(withNumberOfImages: albumData.totalNbImages,
                                         deletionMode: .all, completion: completion)
                })
            allImagesAction.accessibilityIdentifier = "DeleteAll"
            alert.addAction(allImagesAction)
        }
        
        // Present list of actions
        alert.view.tintColor = PwgColor.tintColor
        alert.view.accessibilityIdentifier = "DeleteAlbum"
        alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? UIUserInterfaceStyle.dark : UIUserInterfaceStyle.light
        topViewController.present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = PwgColor.tintColor
        }
    }
    
    @MainActor
    private func confirmAlbumDeletion(withNumberOfImages number: Int64,
                                      deletionMode: pwgAlbumDeletionMode,
                                      completion: @escaping (Bool) -> Void) {
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
        })
        
        let defaultAction = UIAlertAction(
            title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
            style: .cancel,
            handler: { _ in
                completion(true)
            })
        
        deleteAction = UIAlertAction(
            title: NSLocalizedString("deleteCategoryConfirm_deleteButton", comment: "DELETE"),
            style: .destructive,
            handler: { [self] action in
                if (alert.textFields?.first?.text?.count ?? 0) > 0 {
                    checkDeletion(withNumberOfImages: Int(alert.textFields?.first?.text ?? "") ?? 0,
                                  deletionMode: deletionMode, completion: completion)
                }
            })
        deleteAction?.accessibilityIdentifier = "DeleteAll"
        
        alert.addAction(defaultAction)
        if let deleteAction = deleteAction {
            alert.addAction(deleteAction)
        }
        alert.view.tintColor = PwgColor.tintColor
        alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        topViewController.present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = PwgColor.tintColor
        }
    }
    
    @MainActor
    private func checkDeletion(withNumberOfImages number: Int, deletionMode: pwgAlbumDeletionMode,
                               completion: @escaping (Bool) -> Void) {
        // Check provided number of images
        if number != albumData.totalNbImages {
            topViewController.dismissPiwigoError(withTitle: NSLocalizedString("deleteCategoryMatchError_title", comment: "Number Doesn't Match"), message: NSLocalizedString("deleteCategoryMatchError_message", comment: "The number of images you entered doesn't match the number of images in the category. Please try again if you desire to delete this album"), errorMessage: "") {
            }
            return
        }
        
        // Display HUD during the deletion
        topViewController.showHUD(withTitle: NSLocalizedString("deleteCategoryHUD_label", comment: "Deleting Album…"))
        
        // Delete album (deleted images will remain in cache)
        deleteAlbum(withDeletionMode: deletionMode, completion: completion)
    }
    
    private func deleteAlbum(withDeletionMode deletionMode: pwgAlbumDeletionMode,
                             completion: @escaping (Bool) -> Void) {
        // Prepare set of parent IDs before deleting album (including root album)
        let parentIds = Set(albumData.upperIds.components(separatedBy: ",")
            .compactMap({Int32($0)})).filter({$0 != albumData.pwgID}).union(Set([pwgSmartAlbum.root.rawValue]))
        
        // Delete the category
        let title = NSLocalizedString("deleteCategoryError_title", comment: "Delete Fail")
        let message = NSLocalizedString("deleteCategoryError_message", comment: "Failed to delete your album")
        PwgSession.checkSession(ofUser: user) { [self] in
            AlbumUtilities.delete(albumData.pwgID, inMode: deletionMode) { [self] in
                // Auto-upload already disabled by AlbumProvider if necessary
                // Also remove this album from the auto-upload destination
                if UploadVars.shared.autoUploadCategoryId == albumData.pwgID {
                    UploadVars.shared.autoUploadCategoryId = Int32.min
                }
                
                // Update UI and cache
                DispatchQueue.main.async {
                    // Hide swipe buttons
                    completion(true)
                }
                
                // Update parent albums data
                self.fetchAlbumData(ofParentsWithIDs: parentIds)
                
            } failure: { [self] error in
                DispatchQueue.main.async { [self] in
                    self.deleteAlbumError(error, title: title, message: message)
                }
            }
        } failure: { [self] error in
            DispatchQueue.main.async { [self] in
                self.deleteAlbumError(error, title: title, message: message)
            }
        }
    }
    
    private func fetchAlbumData(ofParentsWithIDs parentIDs: Set<Int32>) {
        // Fetch data of parent albums
        let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
        for parentID in parentIDs {
            // Remember that the app is fetching album data
            AlbumVars.shared.isFetchingAlbumData.insert(parentID)
            
            // Use the AlbumProvider to fetch album data. On completion,
            // handle general UI updates and error alerts on the main queue.
            AlbumProvider().fetchAlbums(forUser: user, inParentWithId: parentID,
                                        thumbnailSize: thumnailSize) { [self] error in
                // ► Remove album from list of albums being fetched
                AlbumVars.shared.isFetchingAlbumData.remove(parentID)
                
                // Any error?
                if let error = error {
                    DispatchQueue.main.async { [self] in
                        self.topViewController.hideHUD { [self] in
                            // Display error alert after fetching album data
                            let title = NSLocalizedString("loadingHUD_label", comment: "Loading…")
                            self.deleteAlbumError(error, title: title, message: error.localizedDescription)
                        }
                    }
                    return
                }
            }
        }
        
        // Work completed ► Hide HUDs
        DispatchQueue.main.async { [self] in
            self.topViewController.updateHUDwithSuccess() { [self] in
                self.topViewController.hideHUD(afterDelay: pwgDelayHUD) { }
            }
        }
    }
    
    @MainActor
    private func deleteAlbumError(_ error: PwgKitError, title: String, message: String) {
        // Session logout required?
        if error.requiresLogout {
            ClearCache.closeSessionWithPwgError(from: self.topViewController, error: error)
            return
        }
        
        // Report error
        self.topViewController.dismissPiwigoError(withTitle: title, message: message,
                                                  errorMessage: error.localizedDescription) {
        }
    }
}


// MARK: - UITextField Delegate Methods
extension AlbumDeletion: UITextFieldDelegate
{
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        // The album deletion cannot be requested if a number of images is not provided.
        if let _ = Int(textField.text ?? "") {
            deleteAction?.isEnabled = true
        } else {
            deleteAction?.isEnabled = false
        }
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        // The album deletion cannot be requested if a number of images is not provided.
        if let nberAsText = (textField.text as NSString?)?.replacingCharacters(in: range, with: string),
           let _ = Int(nberAsText) {
            deleteAction?.isEnabled = true
        } else {
            deleteAction?.isEnabled = false
        }
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        // The album deletion cannot be requested if a number of images is not provided.
        deleteAction?.isEnabled = false
        return true
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return true
    }
}
