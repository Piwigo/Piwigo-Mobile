//
//  AlbumViewController+Delete.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: Delete Images
extension AlbumViewController
{
    @objc func deleteSelection() {
        initSelection(beforeAction: .delete)
    }

    func askDeleteConfirmation() {
        // Split orphaned and non-orphaned images
        var toRemove = selectedImageData.filter({$0.categoryIds.count > 1})
        var toDelete = selectedImageData.filter({$0.categoryIds.count == 1})
        let totalNberToDelete = toDelete.count + toRemove.count

        // We cannot propose to remove images from a smart albums
        if categoryId < 0 {
            toDelete.append(contentsOf: toRemove)
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
                toDelete.append(contentsOf: toRemove)

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

    func removeImages(_ toRemove: [PiwigoImageData], andThenDelete toDelete: [PiwigoImageData]) {
        var imagesToRemove = toRemove
        if imagesToRemove.isEmpty {
            if toDelete.isEmpty {
                updatePiwigoHUDwithSuccess() { [self] in
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
        guard let imageData = imagesToRemove.last,
              var categoryIds = imageData.categoryIds else {
            // Forget this image
            imagesToRemove.removeLast()
            
            // Update HUD
            updatePiwigoHUD(withProgress: 1.0 - Float(imagesToRemove.count) / Float(totalNumberOfImages))
            
            // Next image
            removeImages(imagesToRemove, andThenDelete:toDelete)
            return
        }
        categoryIds.removeAll { $0 as NSNumber === NSNumber(value: categoryId) }

        // Prepare parameters for removing the images/videos from the category
        let newImageCategories = categoryIds.map({"\($0)"}).joined(separator: ";")
        let paramsDict = [
            "image_id": String(format: "%d", imageData.imageId),
            "categories": newImageCategories,
            "multiple_value_mode": "replace"
        ]

        // Send request to Piwigo server
        ImageUtilities.setInfos(with: paramsDict) { [self] in
            // Remove image from current category in cache and update UI
            CategoriesData.sharedInstance()
                .removeImage(imageData, fromCategory: String(format: "%ld", categoryId))

            // Next image
            imagesToRemove.removeLast()

            // Update HUD
            updatePiwigoHUD(withProgress: 1.0 - Float(imagesToRemove.count) / Float(totalNumberOfImages))

            // Next image
            removeImages(imagesToRemove, andThenDelete:toDelete)
            
        } failure: { [self] error in
            // Error — Try again ?
            if imagesToRemove.count > 1 {
                cancelDismissRetryPiwigoError(withTitle: NSLocalizedString("deleteImageFail_title", comment: "Delete Failed"), message: NSLocalizedString("deleteImageFail_message", comment: "Image could not be deleted."), errorMessage: error.localizedDescription, cancel: { [self] in
                    hidePiwigoHUD() { [self] in
                        updateButtonsInSelectionMode()
                    }
                }, dismiss: { [self] in
                    // Bypass image
                    imagesToRemove.removeLast()
                    // Continue removing images
                    removeImages(imagesToRemove, andThenDelete:toDelete)
                }, retry: { [self] in
                    // Try relogin if unauthorized
                    if error.code == 401 {
                        let appDelegate = UIApplication.shared.delegate as? AppDelegate
                        appDelegate?.reloginAndRetry() { [self] in
                            removeImages(toRemove, andThenDelete:toDelete)
                        }
                    } else {
                        removeImages(imagesToRemove, andThenDelete:toDelete)
                    }
                })
            } else {
                dismissRetryPiwigoError(withTitle: NSLocalizedString("deleteImageFail_title", comment: "Delete Failed"), message: NSLocalizedString("deleteImageFail_message", comment: "Image could not be deleted."), errorMessage: error.localizedDescription, dismiss: { [self] in
                    hidePiwigoHUD() { [self] in
                        updateButtonsInSelectionMode()
                    }
                }, retry: { [self] in
                    // Try relogin if unauthorized
                    if error.code == 401 {
                        let appDelegate = UIApplication.shared.delegate as? AppDelegate
                        appDelegate?.reloginAndRetry() { [self] in
                            removeImages(imagesToRemove, andThenDelete: toDelete)
                        }
                    } else {
                        removeImages(imagesToRemove, andThenDelete:toDelete)
                    }
                })
            }
        }
    }

    func deleteImages(_ toDelete: [PiwigoImageData]) {
        if toDelete.isEmpty {
            updatePiwigoHUDwithSuccess() { [self] in
                hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { [self] in
                    cancelSelect()
                }
            }
            return
        }

        // Let's delete all images at once
        ImageUtilities.delete(toDelete) { [self] in
            // Hide HUD
            updatePiwigoHUDwithSuccess() { [self] in
                hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { [self] in
                    cancelSelect()
                }
            }
        } failure: { [self] error in
            // Error — Try again ?
            dismissRetryPiwigoError(withTitle: NSLocalizedString("deleteImageFail_title", comment: "Delete Failed"), message: NSLocalizedString("deleteImageFail_message", comment: "Image could not be deleted."), errorMessage: error.localizedDescription, dismiss: { [self] in
                hidePiwigoHUD() { [self] in
                    updateButtonsInSelectionMode()
                }
            }, retry: { [self] in
                // Try relogin if unauthorized
                if error.code == 401 {
                    let appDelegate = UIApplication.shared.delegate as? AppDelegate
                    appDelegate?.reloginAndRetry() { [self] in
                        deleteImages(toDelete)
                    }
                } else {
                    deleteImages(toDelete)
                }
            })
        }
    }
}
