//
//  AlbumViewController+Delete.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

// MARK: Delete Images
extension AlbumViewController
{
    @objc func deleteSelection() {
        initSelection(beforeAction: .delete)
    }

    func askDeleteConfirmation() {
        // Split orphaned and non-orphaned images
        var toRemove = Set<Image>()
        var toDelete = Set<Image>()
        for selectedImageId in selectedImageIds {
            guard let selectedImage = images.fetchedObjects?.first(where: {$0.pwgID == selectedImageId})
                else { continue }
            if (selectedImage.albums ?? Set<Album>()).filter({$0.pwgID > 0}).count == 1 {
                toDelete.insert(selectedImage)
            } else {
                toRemove.insert(selectedImage)
            }
        }
        let totalNberToDelete = toDelete.count + toRemove.count

        // We cannot propose to remove images from a smart albums
        if categoryId < 0 {
            toDelete.formUnion(toRemove)
            toRemove = []
        }
        
        // Alert message
        var messageString: String?
        if totalNberToDelete > 1 {
            messageString = String.localizedStringWithFormat(NSLocalizedString("deleteSeveralImages_message", comment: "Are you sure you want to delete the selected %@ images?"), NSNumber(value: totalNberToDelete))
        } else {
            messageString = NSLocalizedString("deleteSingleImage_message", comment: "Are you sure you want to delete this image?")
        }

        // Do we really want to delete these images?
        let alert = UIAlertController(title: nil, message: messageString,
                                      preferredStyle: .actionSheet)

        let cancelAction = UIAlertAction(
            title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
            style: .cancel, handler: { [self] action in
                updateButtonsInSelectionMode()
            })

        let removeImagesAction = UIAlertAction(
            title: toDelete.isEmpty ? NSLocalizedString("removeSingleImage_title", comment: "Remove from Album") : NSLocalizedString("deleteCategory_orphanedImages", comment: "Delete Orphans"),
            style: toDelete.isEmpty ? .default : .destructive,
            handler: { [self] action in
                // Display HUD during server update
                totalNumberOfImages = toRemove.count + (toDelete.isEmpty ? 0 : 1)
                if totalNumberOfImages > 1 {
                    showPiwigoHUD(
                        withTitle: toDelete.isEmpty
                            ? NSLocalizedString("removeSeveralImagesHUD_removing", comment: "Removing Photos…")
                            : NSLocalizedString("deleteSeveralImagesHUD_deleting", comment: "Deleting Images…"),
                        detail: "", buttonTitle: "", buttonTarget: nil, buttonSelector: nil,
                        inMode: .annularDeterminate)
                } else {
                    showPiwigoHUD(
                        withTitle: toDelete.isEmpty
                            ? NSLocalizedString("removeSingleImageHUD_removing", comment: "Removing Photo…")
                            : NSLocalizedString("deleteSingleImageHUD_deleting", comment: "Deleting Image…"),
                        detail: "", buttonTitle: "", buttonTarget: nil, buttonSelector: nil,
                        inMode: .indeterminate)
                }

                // Start removing images
                removeImages(toRemove, andThenDelete: toDelete)
            })

        let deleteImagesAction = UIAlertAction(
            title: totalNberToDelete > 1 ? String.localizedStringWithFormat(NSLocalizedString("deleteSeveralImages_title", comment: "Delete %@ Images"), NSNumber(value: totalNberToDelete)) : NSLocalizedString("deleteSingleImage_title", comment: "Delete Image"),
            style: .destructive, handler: { [self] action in
                // Append image to remove
                toDelete.formUnion(toRemove)

                // Display HUD during server update
                showPiwigoHUD(
                    withTitle: toDelete.count > 1
                        ? NSLocalizedString("deleteSingleImageHUD_deleting", comment: "Deleting Image…")
                        : NSLocalizedString("deleteSeveralImagesHUD_deleting", comment: "Deleting Images…"),
                    detail: "", buttonTitle: "", buttonTarget: nil, buttonSelector: nil,
                    inMode: .indeterminate)

                // Start deleting images
                deleteImages(toDelete)
            })

        // Add actions
        alert.addAction(cancelAction)
        alert.addAction(deleteImagesAction)
        if !toRemove.isEmpty {
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

    func removeImages(_ toRemove: Set<Image>, andThenDelete toDelete: Set<Image>) {
        var imagesToRemove = toRemove
        if imagesToRemove.isEmpty {
            if toDelete.isEmpty {
                updatePiwigoHUDwithSuccess() { [self] in
                    // Save changes
                    do {
                        try self.mainContext.save()
                    } catch let error as NSError {
                        print("Could not save moved images \(error), \(error.userInfo)")
                    }
                    // Hide HUD and deselect images
                    hidePiwigoHUD() { [self] in
                        cancelSelect()
                    }
                }
            } else {
                deleteImages(toDelete)
            }
            return
        }

        // Update image category list
        guard let imageData = imagesToRemove.first,
              let albums = imageData.albums else {
            // Forget this image
            imagesToRemove.removeFirst()

            // Update HUD
            updatePiwigoHUD(withProgress: 1.0 - Float(imagesToRemove.count) / Float(totalNumberOfImages))

            // Next image
            removeImages(imagesToRemove, andThenDelete:toDelete)
            return
        }
        var categoryIds = albums.compactMap({$0.pwgID})
        categoryIds.removeAll(where: {$0 == categoryId})

        // Prepare parameters for removing the images/videos from the category
        let newImageCategories = categoryIds.map({"\($0)"}).joined(separator: ";")
        let paramsDict = [
            "image_id": String(format: "%d", imageData.pwgID),
            "categories": newImageCategories,
            "multiple_value_mode": "replace"
        ]

        // Send request to Piwigo server
        LoginUtilities.checkSession(ofUser: user) {  [self] in
            ImageUtilities.setInfos(with: paramsDict) { [self] in
                // Remove image from source album
                imageData.removeFromAlbums(albumData)
                
                // Update albums
                self.albumProvider.updateAlbums(removingImages: 1, fromAlbum: albumData)

                // Next image
                imagesToRemove.removeFirst()

                // Update HUD
                updatePiwigoHUD(withProgress: 1.0 - Float(imagesToRemove.count) / Float(totalNumberOfImages))

                // Next image
                removeImages(imagesToRemove, andThenDelete:toDelete)

            } failure: { [self] error in
                self.removeImages(imagesToRemove, andThenDelete: toDelete, error: error)
            }
        } failure: { [self] error in
            self.removeImages(imagesToRemove, andThenDelete: toDelete, error: error)
        }
    }
    
    private func removeImages(_ toRemove: Set<Image>, andThenDelete toDelete: Set<Image>, error: NSError) {
        var imagesToRemove = toRemove
        let title = NSLocalizedString("deleteImageFail_title", comment: "Delete Failed")
        let message = NSLocalizedString("deleteImageFail_message", comment: "Image could not be deleted.")
        if imagesToRemove.count > 1 {
            cancelDismissPiwigoError(withTitle: title, message: message,
                                     errorMessage: error.localizedDescription) { [unowned self] in
                hidePiwigoHUD() { [unowned self] in
                    // Save changes
                    do {
                        try self.mainContext.save()
                    } catch let error as NSError {
                        print("Could not save moved images \(error), \(error.userInfo)")
                    }
                    // Hide HUD and update buttons
                    updateButtonsInSelectionMode()
                }
            } dismiss: { [unowned self] in
                // Bypass image
                imagesToRemove.removeFirst()
                // Continue removing images
                removeImages(imagesToRemove, andThenDelete:toDelete)
            }
        } else {
            dismissPiwigoError(withTitle: title, message: message,
                                     errorMessage: error.localizedDescription) { [unowned self] in
                hidePiwigoHUD() { [unowned self] in
                    // Save changes
                    do {
                        try self.mainContext.save()
                    } catch let error as NSError {
                        print("Could not save moved images \(error), \(error.userInfo)")
                    }
                    // Hide HUD and update buttons
                    updateButtonsInSelectionMode()
                }
            }
        }
    }

    func deleteImages(_ toDelete: Set<Image>) {
        if toDelete.isEmpty {
            updatePiwigoHUDwithSuccess() { [self] in
                // Save changes
                do {
                    try self.mainContext.save()
                } catch let error as NSError {
                    print("Could not save moved images \(error), \(error.userInfo)")
                }
                // Hide HUD and deselect images
                hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { [self] in
                    cancelSelect()
                }
            }
            return
        }

        // Let's delete all images at once
        LoginUtilities.checkSession(ofUser: user) { [unowned self] in
            ImageUtilities.delete(toDelete) { [unowned self] in
                DispatchQueue.main.async {
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
                        print("Could not save albums after image deletion \(error), \(error.userInfo)")
                    }

                    // Update cache so that these images can be re-uploaded.
                    UploadManager.shared.backgroundQueue.async {
                        UploadManager.shared.markAsDeletedPiwigoImages(withIDs: imageIDs)
                    }

                    // Hide HUD
                    self.updatePiwigoHUDwithSuccess() { [self] in
                        hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { [self] in
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
    
    private func deleteImagesError(_ error: NSError) {
        DispatchQueue.main.async { [self] in
            let title = NSLocalizedString("deleteImageFail_title", comment: "Delete Failed")
            let message = NSLocalizedString("deleteImageFail_message", comment: "Image could not be deleted.")
            dismissPiwigoError(withTitle: title, message: message, errorMessage: error.localizedDescription) { [self] in
                // Save changes
                do {
                    try self.mainContext.save()
                } catch let error as NSError {
                    print("Could not save moved images \(error), \(error.userInfo)")
                }
                // Hide HUD and update buttons
                hidePiwigoHUD() { [self] in
                    updateButtonsInSelectionMode()
                }
            }
        }
    }
}
