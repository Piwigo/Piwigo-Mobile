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
import PwgKit
import PwgAPIKit
import PwgCacheKit
import PwgUIKit
import PwgUploadKit

final class AlbumDeletion: NSObject
{
    // Initialisation
    init(album: Album, nbOrphans: Int64,
         topViewController: UIViewController) {
        self.album = album
        self.nbOrphans = nbOrphans
        self.topViewController = topViewController
    }
    
    var album: Album
    lazy var userData: UserProperties = {
        guard let user = album.user?.getProperties()
        else { preconditionFailure("Album has no User instance") }
        return user
    }()
    var topViewController: UIViewController
    
    private var deleteAction: UIAlertAction?
    private var nbOrphans = Int64.min
    
    @MainActor
    func displayAlert(completion: @escaping (Bool) -> Void)
    {
        let alert = UIAlertController(
            title: String(localized: "deleteCategory_title", comment: "DELETE ALBUM"),
            message: String.localizedStringWithFormat(String(localized: "deleteCategory_message", comment: "ARE YOU SURE YOU WANT TO DELETE THE ALBUM \"%@\" AND ALL %lld IMAGES?"), album.name, album.totalNbImages),
            preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: Localized.cancel,
                                         style: .cancel, handler: { _ in
            // Hide swipe buttons
            completion(true)
        })
        alert.addAction(cancelAction)
        
        if album.totalNbImages == 0 {
            // Empty album
            let emptyCategoryAction = UIAlertAction(
                title: String(localized: "deleteCategory_empty", comment: "Delete Empty Album"),
                style: .destructive, handler: { [self] action in
                    // Display HUD during the deletion
                    topViewController.showHUD(withTitle: String(localized: "deleteCategoryHUD_label", comment: "Deleting Album…"))
                    
                    // Delete empty album
                    deleteAlbum(withDeletionMode: .none, completion: completion)
                })
            alert.addAction(emptyCategoryAction)
        } else {
            // Album containing images
            let keepImagesAction = UIAlertAction(
                title: String(localized: "deleteCategory_noImages", comment: "Keep Photos/Videos"),
                style: .default, handler: { [self] action in
                    if nbOrphans == Int64.zero {
                        // There will be no more orphans after the album deletion
                        deleteAlbum(withDeletionMode: .none, completion: completion)
                    } else {
                        // There will be orphans, ask confirmation
                        confirmAlbumDeletion(withNumberOfImages: album.totalNbImages,
                                             deletionMode: .none, completion: completion)
                    }
                })
            alert.addAction(keepImagesAction)
            
            if nbOrphans == Int64.min {
                let orphanImagesAction = UIAlertAction(
                    title: String(localized: "deleteCategory_orphanedImages", comment: "Delete Orphans"),
                    style: .destructive,
                    handler: { [self] action in
                        confirmAlbumDeletion(withNumberOfImages: album.totalNbImages,
                                             deletionMode: .orphaned, completion: completion)
                    })
                alert.addAction(orphanImagesAction)
            }
            else if nbOrphans != 0 {
                let orphanImagesAction = UIAlertAction(
                    title: String.localizedStringWithFormat(String(localized: "deleteCategory_severalOrphanedImages", comment: "Delete %lld Orphans"), self.nbOrphans),
                    style: .destructive,
                    handler: { [self] action in
                        confirmAlbumDeletion(withNumberOfImages: album.totalNbImages,
                                             deletionMode: .orphaned, completion: completion)
                    })
                alert.addAction(orphanImagesAction)
            }
            
            if nbOrphans != album.totalNbImages {
                let allImagesAction = UIAlertAction(
                    title: String.localizedStringWithFormat(String(localized: "deleteSeveralImages_title", comment: "Delete %@ Photos/Videos"), NSNumber(value: album.totalNbImages)),
                    style: .destructive,
                    handler: { [self] action in
                        confirmAlbumDeletion(withNumberOfImages: album.totalNbImages,
                                             deletionMode: .all, completion: completion)
                    })
                allImagesAction.accessibilityIdentifier = "DeleteAll"
                alert.addAction(allImagesAction)
            }
        }
        
        // Present list of actions
        alert.view.tintColor = PwgColor.tintColor
        alert.view.accessibilityIdentifier = "DeleteAlbum"
        alert.overrideUserInterfaceStyle = UIVars.shared.isDarkPaletteActive ? UIUserInterfaceStyle.dark : UIUserInterfaceStyle.light
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
            title: String(localized: "deleteCategoryConfirm_title", comment: "Are you sure?"),
            message: String.localizedStringWithFormat(String(localized: "deleteCategoryConfirm_message", comment: "Please enter the number of images in order to delete this album\nNumber of images: %@"), NSNumber(value: album.totalNbImages)),
            preferredStyle: .alert)
        
        alert.addTextField(configurationHandler: { [self] textField in
            textField.placeholder = "\(NSNumber(value: album.nbImages))"
            textField.keyboardAppearance = UIVars.shared.isDarkPaletteActive ? .dark : .default
            textField.clearButtonMode = .always
            textField.keyboardType = .numberPad
            textField.delegate = self
        })
        
        let defaultAction = UIAlertAction(title: Localized.cancel,
                                          style: .cancel, handler: { _ in
            completion(true)
        })
        
        deleteAction = UIAlertAction(
            title: String(localized: "deleteCategoryConfirm_deleteButton", comment: "DELETE"),
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
        alert.overrideUserInterfaceStyle = UIVars.shared.isDarkPaletteActive ? .dark : .light
        topViewController.present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = PwgColor.tintColor
        }
    }
    
    @MainActor
    private func checkDeletion(withNumberOfImages number: Int, deletionMode: pwgAlbumDeletionMode,
                               completion: @escaping (Bool) -> Void) {
        // Check provided number of images
        if number != album.totalNbImages {
            topViewController.dismissPiwigoError(withTitle: String(localized: "deleteCategoryMatchError_title", comment: "Number Doesn't Match"), message: String(localized: "deleteCategoryMatchError_message", comment: "The number of images you entered doesn't match the number of images in the category. Please try again if you desire to delete this album"), errorMessage: "") {
            }
            return
        }
        
        // Display HUD during the deletion
        topViewController.showHUD(withTitle: String(localized: "deleteCategoryHUD_label", comment: "Deleting Album…"))
        
        // Delete album (deleted images will remain in cache)
        deleteAlbum(withDeletionMode: deletionMode, completion: completion)
    }
    
    private func deleteAlbum(withDeletionMode deletionMode: pwgAlbumDeletionMode,
                             completion: @escaping (Bool) -> Void) {
        // Prepare set of parent IDs before deleting album (including root album)
        let parentIDs = Set(album.upperIds.components(separatedBy: ",")
            .compactMap({Int32($0)})).filter({$0 != album.pwgID}).union(Set([pwgSmartAlbum.root.rawValue]))
        
        // Delete the category
        Task {
            do throws(PwgKitError) {
                // Collect the IDs of the albums which the server will delete, i.e. this album
                // and its sub-albums, before the cache is updated below
                let deletedIDs = AlbumProvider().getIDsOfAlbumAndSubAlbums(withID: album.pwgID,
                                                                           inContext: DataController.shared.newTaskContext())
                
                // Check session
                try await LoginUtilities().checkSessionOfCurrentUser()
                
                // Delete album
                _ = try await JSONManager.shared.deleteCategory(withID: album.pwgID, inMode: deletionMode)
                
                // Auto-upload already disabled by AlbumProvider if necessary
                // Also remove this album, or one of its sub-albums, from the auto-upload destination
                if deletedIDs.contains(UploadVars.shared.autoUploadCategoryId) {
                    UploadVars.shared.autoUploadCategoryId = Int32.min
                }
                
                // Delete the upload requests whose destination album was deleted.
                // Completed requests are only deleted when every photo of the album was deleted
                // from the server: in the other modes a photo may still belong to another album,
                // and the app would then propose it for upload again.
                await UploadManager.shared.deleteUploads(ofDeletedAlbumsWithIDs: deletedIDs,
                                                         photosDeleted: deletionMode == .all)
                
                // Update parent album data
                let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
                for parentID in parentIDs {
                    // Don't fetch an album already being fetched
                    if AlbumVars.shared.isFetchingAlbumData.contains(parentID) { continue }
                    
                    // Remember that the app is fetching all album data
                    // until the fetch completes or the fetch or the import below throws an error
                    AlbumVars.shared.isFetchingAlbumData.insert(parentID)
                    defer { AlbumVars.shared.isFetchingAlbumData.remove(parentID) }
                    
                    // Fetch album data
                    let pwgData = try await JSONManager.shared.fetchAlbums(forUserWithAdminRights: userData.hasAdminRights,
                                                                           inParentWithId: parentID,
                                                                           thumbnailSize: thumnailSize)
                    // Update cache
                    try await AlbumProvider().importAlbums(pwgData, inParent: parentID)
                }
                
                // Work completed ► Hide HUD, update UI
                await MainActor.run { [self] in
                    self.topViewController.updateHUDwithSuccess() { [self] in
                        self.topViewController.hideHUD(afterDelay: pwgDelayHUD) { [self] in
                            // Album successfully deleted ▶ Remove category ID from list of recently used albums
                            let userInfo = ["categoryId" : NSNumber.init(value: album.pwgID)]
                            NotificationCenter.default.post(name: Notification.Name.pwgRemoveRecentAlbum,
                                                            object: nil, userInfo: userInfo)
                            // Hide swipe buttons
                            completion(true)
                        }
                    }
                }
            }
            catch {
                await MainActor.run { [self] in
                    self.topViewController.hideHUD { [self] in
                        // Display error alert after fetching album data
                        let title = String(localized: "deleteCategoryError_title", comment: "Delete Fail")
                        let message = String(localized: "deleteCategoryError_message", comment: "Failed to delete your album")
                        self.deleteAlbumError(error, title: title, message: message)
                    }
                }
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
