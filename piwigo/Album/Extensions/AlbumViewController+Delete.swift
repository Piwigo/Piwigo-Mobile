//
//  AlbumViewController+Delete.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit
import uploadKit

extension AlbumViewController
{
    // MARK: - Delete Bar Button
    func getDeleteBarButton() -> UIBarButtonItem {
        return UIBarButtonItem.deleteImageButton(self, action: #selector(deleteSelection))
    }

    
    // MARK: - Delete or Remove Images
    @objc func deleteSelection() {
        initSelection(ofImagesWithIDs: selectedImageIDs, beforeAction: .delete, contextually: false)
    }

    func askDeleteConfirmation(forImagesWithID imageIDs: Set<Int64>) {
        // Split orphaned and non-orphaned images
        var toRemove = Set<Image>()
        var toDelete = Set<Image>()
        for imageID in imageIDs {
            guard let image = (images.fetchedObjects ?? []).first(where: {$0.pwgID == imageID})
            else { continue }
            if (image.albums ?? Set<Album>()).filter({$0.pwgID > 0}).count == 1 {
                toDelete.insert(image)
            } else {
                toRemove.insert(image)
            }
        }
        let totalNberToDelete = toDelete.count + toRemove.count

        // We cannot propose to remove images from a smart album
        if albumData.pwgID < 0 {
            toDelete.formUnion(toRemove)
            toRemove = []
        }
        
        // Ask if the user really wants to delete these images?
        var msg = "";
        if totalNberToDelete > 1 {
            msg = String.localizedStringWithFormat(NSLocalizedString("deleteSeveralImages_message", comment: "Are you sure you want to delete the selected %@ photos/videos?"), NSNumber(value: totalNberToDelete))
        } else if let imageData = toDelete.first, imageData.isVideo {
            msg = NSLocalizedString("deleteSingleVideo_title", comment: "Are you sure you want to delete this video?")
        } else {
            msg = NSLocalizedString("deleteSingleImage_message", comment: "Are you sure you want to delete this photo?")
        }
        let alert = UIAlertController(title: nil, message: msg, preferredStyle: .actionSheet)

        // Button for cancelling the action
        let cancelAction = UIAlertAction(
            title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
            style: .cancel, handler: { [self] action in
                updateBarsInSelectMode()
            })
        alert.addAction(cancelAction)

        // Button for deleting all images
        if totalNberToDelete > 1 {
            msg = String.localizedStringWithFormat(NSLocalizedString("deleteSeveralImages_title", comment: "Delete %@ Photos/Videos"), NSNumber(value: totalNberToDelete))
        } else if let imageData = toDelete.first, imageData.isVideo {
            msg = NSLocalizedString("deleteSingleVideo_title", comment: "Delete Video")
        } else {
            msg = NSLocalizedString("deleteSingleImage_title", comment: "Delete Photo")
        }
        let deleteImagesAction = UIAlertAction(
            title: msg, style: .destructive, handler: { [self] action in
                // Append image to remove
                toDelete.formUnion(toRemove)

                // Display HUD during server update
                var msgHUD = ""
                if imageIDs.count > 1 {
                    msgHUD = NSLocalizedString("deleteSeveralImagesHUD_deleting", comment: "Deleting Photos/Videos…")
                } else if let imageData = toDelete.first, imageData.isVideo {
                    msgHUD = NSLocalizedString("deleteSingleVideoHUD_deleting", comment: "Deleting Video…")
                } else {
                    msgHUD = NSLocalizedString("deleteSingleImageHUD_deleting", comment: "Deleting Photo…")
                }
                navigationController?.showHUD(withTitle: msgHUD, inMode: .indeterminate)

                // Start deleting images
                deleteImages(toDelete)
            })
        alert.addAction(deleteImagesAction)

        if !toRemove.isEmpty {
            let removeImagesAction = UIAlertAction(
                title: toDelete.isEmpty ? NSLocalizedString("removeSingleImage_title", comment: "Remove from Album") : NSLocalizedString("deleteCategory_orphanedImages", comment: "Delete Orphans"),
                style: toDelete.isEmpty ? .default : .destructive,
                handler: { [self] action in
                    // Display HUD during server update
                    var msgHUD = ""
                    let totalNberOfImages = toRemove.count + (toDelete.isEmpty ? 0 : 1)
                    if totalNberOfImages > 1 {
                        msgHUD = toDelete.isEmpty
                        ? NSLocalizedString("removeSeveralImagesHUD_removing", comment: "Removing Photos/Videos…")
                        : NSLocalizedString("deleteSeveralImagesHUD_deleting", comment: "Deleting Photos/Videos…")
                        navigationController?.showHUD(withTitle: msgHUD, inMode: NetworkVars.shared.usesSetCategory ? .indeterminate : .determinate)
                    } else if toRemove.isEmpty {
                        // Delete a single image
                        if let imageData = toDelete.first, imageData.isVideo {
                            msgHUD = NSLocalizedString("deleteSingleVideoHUD_deleting", comment: "Deleting Video…")
                        } else {
                            msgHUD = NSLocalizedString("deleteSingleImageHUD_deleting", comment: "Deleting Photo…")
                        }
                        navigationController?.showHUD(withTitle: msgHUD, inMode: .indeterminate)
                    } else {
                        // Remove a single image
                        if let imageData = toRemove.first, imageData.isVideo {
                            msgHUD = NSLocalizedString("removeSingleVideoHUD_removing", comment: "Removing Video…")
                        } else {
                            msgHUD = NSLocalizedString("removeSingleImageHUD_removing", comment: "Removing Photo…")
                        }
                        navigationController?.showHUD(withTitle: msgHUD, inMode: .indeterminate)
                    }

                    // Start removing images
                    if NetworkVars.shared.usesSetCategory {
                        self.dissociateImages(toRemove, andThenDelete: toDelete)
                    } else {
                        self.removeImages(toRemove, andThenDelete: toDelete, total: Float(totalNberToDelete))
                    }
                })
            alert.addAction(removeImagesAction)
        }

        // Present list of actions
        alert.view.tintColor = UIColor.piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        }
        alert.popoverPresentationController?.barButtonItem = deleteBarButton
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange()
        }
    }

    /// For calling Piwigo server in version 2.10 to 13.x
    func removeImages(_ toRemove: Set<Image>, andThenDelete toDelete: Set<Image>, total: Float) {
        var imagesToRemove = toRemove
        guard let imageData = imagesToRemove.first,
              let albums = imageData.albums
        else {
            // Continue with deletion if needed
            self.deleteImages(toDelete)
            return
        }

        // Update image category list
        var categoryIds = albums.compactMap({$0.pwgID})
        categoryIds.removeAll(where: {$0 == albumData.pwgID})

        // Prepare parameters for removing the images/videos from the category
        let newImageCategories = categoryIds.map({"\($0)"}).joined(separator: ";")
        let paramsDict = [
            "image_id": String(format: "%d", imageData.pwgID),
            "categories": newImageCategories,
            "multiple_value_mode": "replace"
        ]

        // Send request to Piwigo server
        PwgSession.checkSession(ofUser: user) { [self] in
            PwgSession.shared.setInfos(with: paramsDict) { [self] in
                // Remove image from source album
                imageData.removeFromAlbums(albumData)
                
                // Update albums
                self.albumProvider.updateAlbums(removingImages: 1, fromAlbum: albumData)

                // Next image
                imagesToRemove.removeFirst()

                // Update HUD
                DispatchQueue.main.async { [self] in
                    let ratio = Float(imagesToRemove.count) / total
                    self.navigationController?.updateHUD(withProgress: 1.0 - ratio)
                }

                // Next image
                removeImages(imagesToRemove, andThenDelete:toDelete, total: total)

            } failure: { [self] error in
                self.removeImages(imagesToRemove, andThenDelete: toDelete, total: total, error: error)
            }
        } failure: { [self] error in
            self.removeImages(imagesToRemove, andThenDelete: toDelete, total: total, error: error)
        }
    }
    
    /// For calling Piwigo server in version 2.10 to 13.x
    private func removeImages(_ toRemove: Set<Image>, andThenDelete toDelete: Set<Image>,
                              total: Float, error: Error) {
        DispatchQueue.main.async { [self] in
            // Session logout required?
            if let pwgError = error as? PwgSessionError,
               [.invalidCredentials, .incompatiblePwgVersion, .invalidURL, .authenticationFailed].contains(pwgError) {
                ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
                return
            }
            
            // Report error
            var imagesToRemove = toRemove
            let title = NSLocalizedString("moveImageError_title", comment: "Delete Failed")
            let message = NSLocalizedString("deleteImageFail_message", comment: "Image could not be deleted.")
            if imagesToRemove.count > 1 {
                cancelDismissPiwigoError(withTitle: title, message: message, errorMessage: error.localizedDescription) { [self] in
                    navigationController?.hideHUD() { [self] in
                        // Save changes
                        self.mainContext.saveIfNeeded()
                        // Hide HUD and update buttons
                        self.updateBarsInSelectMode()
                    }
                } dismiss: { [self] in
                    // Bypass image
                    imagesToRemove.removeFirst()
                    // Continue removing images
                    removeImages(imagesToRemove, andThenDelete:toDelete, total: total)
                }
            } else {
                dismissPiwigoError(withTitle: title, message: message, errorMessage: error.localizedDescription) { [self] in
                    navigationController?.hideHUD() { [self] in
                        // Save changes
                        self.mainContext.saveIfNeeded()
                        // Hide HUD and update buttons
                        updateBarsInSelectMode()
                    }
                }
            }
        }
    }

    /// For calling Piwigo server in version +14.0
    private func dissociateImages(_ toRemove: Set<Image>, andThenDelete toDelete: Set<Image>) {
        // Send request to Piwigo server
        PwgSession.checkSession(ofUser: user) { [self] in
            ImageUtilities.setCategory(albumData, forImages: toRemove, withAction: .dissociate) {
                DispatchQueue.main.async { [self] in
                    // Remove images from album
                    self.albumData.removeFromImages(toRemove)
                    
                    // Update albums
                    let nberOfImages = Int64(toRemove.count)
                    self.albumProvider.updateAlbums(removingImages: nberOfImages, fromAlbum: self.albumData)

                    // Continue with deletion if needed
                    self.deleteImages(toDelete)
                }
            } failure: { [self] error in
                self.dissociateImagesError(error)
            }
        } failure: { [self] error in
            self.dissociateImagesError(error)
        }
    }

    private func dissociateImagesError(_ error: Error) {
        DispatchQueue.main.async { [self] in
            // Session logout required?
            if let pwgError = error as? PwgSessionError,
               [.invalidCredentials, .incompatiblePwgVersion, .invalidURL, .authenticationFailed].contains(pwgError) {
                ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
                return
            }
            
            // Report error
            let title = NSLocalizedString("deleteImageFail_title", comment: "Delete Failed")
            let message = NSLocalizedString("deleteImageFail_message", comment: "Image could not be deleted.")
            dismissPiwigoError(withTitle: title, message: message, errorMessage: error.localizedDescription) { [self] in
                navigationController?.hideHUD() { [self] in
                    // Save changes
                    self.mainContext.saveIfNeeded()
                    // Hide HUD and update buttons
                    updateBarsInSelectMode()
                }
            }
        }
    }

    func deleteImages(_ toDelete: Set<Image>) {
        if toDelete.isEmpty {
            DispatchQueue.main.async { [self] in
                self.navigationController?.updateHUDwithSuccess() { [self] in
                    // Save changes
                    do {
                        try self.mainContext.save()
                    } catch let error {
                        debugPrint("Could not save deleted images \(error)")
                    }
                    // Hide HUD and deselect images
                    self.navigationController?.hideHUD(afterDelay: pwgDelayHUD) { [self] in
                        self.cancelSelect()
                    }
                }
            }
            return
        }

        // Let's delete all images at once
        PwgSession.checkSession(ofUser: user) { [self] in
            ImageUtilities.delete(toDelete) { [self] in
                DispatchQueue.main.async { [self] in
                    // Save image IDs for marking Upload requests in the background
                    let imageIDs = Array(toDelete).map({$0.pwgID})

                    // Remove images from cache
                    for imageData in toDelete {
                        // Delete image from cache (also deletes image files)
                        self.mainContext.delete(imageData)

                        // Retrieve albums associated to the deleted image
                        if let albums = imageData.albums {
                            // Remove image from cached albums
                            albums.forEach { album in
                                self.albumProvider.updateAlbums(removingImages: 1, fromAlbum: album)
                            }
                        }
                    }
                    
                    // Save changes
                    do {
                        try self.mainContext.save()
                    } catch let error as NSError {
                        debugPrint("Could not save albums after image deletion \(error), \(error.userInfo)")
                    }

                    // Delete upload requests of images deleted from the Piwigo server
                    UploadManager.shared.backgroundQueue.async {
                        UploadManager.shared.deleteUploadsOfDeletedImages(withIDs: imageIDs)
                    }

                    // Hide HUD
                    self.navigationController?.updateHUDwithSuccess() { [self] in
                        self.navigationController?.hideHUD(afterDelay: pwgDelayHUD) { [self] in
                            cancelSelect()
                        }
                    }
                }
            } failure: { [self] error in
                self.deleteImagesError(error)
            }
        } failure: { [self] error in
            self.deleteImagesError(error)
        }
    }
    
    private func deleteImagesError(_ error: Error) {
        DispatchQueue.main.async { [self] in
            // Session logout required?
            if let pwgError = error as? PwgSessionError,
               [.invalidCredentials, .incompatiblePwgVersion, .invalidURL, .authenticationFailed].contains(pwgError) {
                ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
                return
            }

            // Report error
            let title = NSLocalizedString("deleteImageFail_title", comment: "Delete Failed")
            let message = NSLocalizedString("deleteImageFail_message", comment: "Image could not be deleted.")
            dismissPiwigoError(withTitle: title, message: message, errorMessage: error.localizedDescription) { [self] in
                // Save changes
                self.mainContext.saveIfNeeded()
                // Hide HUD and update buttons
                navigationController?.hideHUD() { [self] in
                    updateBarsInSelectMode()
                }
            }
        }
    }
}
