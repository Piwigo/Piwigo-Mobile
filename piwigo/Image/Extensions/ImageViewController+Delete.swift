//
//  ImageViewController+Delete.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

extension ImageViewController
{
    // MARK: - Delete or Remove Image from Album
    @objc func deleteImage() {
        // Disable buttons during action
        setEnableStateOfButtons(false)

        let alert = UIAlertController(title: "",
            message: NSLocalizedString("deleteSingleImage_message", comment: "Are you sure you want to delete this image? This cannot be undone!"),
            preferredStyle: .actionSheet)

        let cancelAction = UIAlertAction(
            title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
            style: .cancel, handler: { [self] action in
                // Re-enable buttons
                setEnableStateOfButtons(true)
            })

        let removeAction = UIAlertAction(
            title: NSLocalizedString("removeSingleImage_title", comment: "Remove from Album"),
            style: .default, handler: { [self] action in
                removeImageFromAlbum()
            })

        let deleteAction = UIAlertAction(
            title: NSLocalizedString("deleteSingleImage_title", comment: "Delete Image"),
            style: .destructive, handler: { [self] action in
                deleteImageFromDatabase()
            })

        // Add actions
        alert.addAction(cancelAction)
        alert.addAction(deleteAction)
        if categoryId > 0, let albums = imageData?.albums?.filter({$0.pwgID > 0}), albums.count > 1 {
            // This image is used in another album
            // Proposes to remove it from the current album, unless it was selected from a smart album
            alert.addAction(removeAction)
        }

        // Present list of actions
        alert.view.tintColor = .piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        alert.popoverPresentationController?.barButtonItem = deleteBarButton
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = .piwigoColorOrange()
        }
    }
    
    func removeImageFromAlbum() {
        // Display HUD during deletion
        showPiwigoHUD(withTitle: NSLocalizedString("removeSingleImageHUD_removing", comment: "Removing Photo…"), detail: "", buttonTitle: "", buttonTarget: nil, buttonSelector: nil, inMode: .indeterminate)
        
        // Remove selected category ID from image category list
        guard let imageData = imageData,
              var catIDs = imageData.albums?.compactMap({$0.pwgID}).filter({$0 > 0}) else {
            dismissPiwigoError(withTitle: NSLocalizedString("deleteImageFail_title", comment: "Delete Failed")) {
                // Hide HUD
                self.hidePiwigoHUD { [unowned self] in
                    // Re-enable buttons
                    self.setEnableStateOfButtons(true)
                }
            }
            return
        }
        catIDs.removeAll(where: {$0 == categoryId})
        
        // Prepare parameters for removing the image/video from the selected category
        let imageID = imageData.pwgID
        let newImageCategories = catIDs.compactMap({"\($0)"}).joined(separator: ",")
        let paramsDict: [String : Any] = ["image_id"            : imageID,
                                          "categories"          : newImageCategories,
                                          "multiple_value_mode" : "replace"]
        
        // Send request to Piwigo server
        LoginUtilities.checkSession { [self] in
            ImageUtilities.setInfos(with: paramsDict) { [self] in
                // Retrieve album
                if let albums = imageData.albums,
                   let album = albums.first(where: {$0.pwgID == categoryId}) {
                    // Remove image from album
                    album.removeFromImages(imageData)

                    // Update albums
                    self.albumProvider.updateAlbums(removingImages: 1, fromAlbum: album)

                    // Save changes
                    do {
                        try self.savingContext.save()
                    } catch let error as NSError {
                        print("Could not save copied images \(error), \(error.userInfo)")
                    }
                }

                // Hide HUD
                self.updatePiwigoHUDwithSuccess { [unowned self] in
                    self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { [unowned self] in
                        // Display preceding/next image or return to album view
                        self.didRemoveImage()
                    }
                }
            } failure: { [self] error in
                self.removeImageFromAlbumError(error)
            }
        } failure: { [self] error in
            self.removeImageFromAlbumError(error)
        }
    }
    
    private func removeImageFromAlbumError(_ error: NSError) {
        DispatchQueue.main.async { [self] in
            let title = NSLocalizedString("deleteImageFail_title", comment: "Delete Failed")
            let message = NSLocalizedString("deleteImageFail_message", comment: "Image could not be deleted")
            self.dismissPiwigoError(withTitle: title, message: message,
                                    errorMessage: error.localizedDescription) { [unowned self] in
                // Hide HUD
                hidePiwigoHUD { [unowned self] in
                    // Re-enable buttons
                    setEnableStateOfButtons(true)
                }
            }
        }
    }
    
    func deleteImageFromDatabase() {
        // Remove selected category ID from image category list
        guard let imageData = imageData else {
            dismissPiwigoError(withTitle: NSLocalizedString("deleteImageFail_title", comment: "Delete Failed")) {
                // Hide HUD
                self.hidePiwigoHUD { [self] in
                    // Re-enable buttons
                    self.setEnableStateOfButtons(true)
                }
            }
            return
        }

        // Display HUD during deletion
        showPiwigoHUD(withTitle: NSLocalizedString("deleteSingleImageHUD_deleting", comment: "Deleting Image…"), detail: "", buttonTitle: "", buttonTarget: nil, buttonSelector: nil, inMode: .indeterminate)
        
        // Send request to Piwigo server
        LoginUtilities.checkSession { [self] in
            ImageUtilities.delete(Set([imageData])) { [self] in
                // Save image ID for marking Upload request in the background
                let imageID = imageData.pwgID
                
                // Delete image from cache (also deletes image files)
                self.savingContext.delete(imageData)
                
                // Retrieve albums associated to the deleted image
                if let albums = imageData.albums {
                    // Remove image from cached albums
                    albums.forEach { album in
                        self.albumProvider.updateAlbums(removingImages: 1, fromAlbum: album)
                    }
                }
                
                // Save changes
                do {
                    try self.savingContext.save()
                } catch let error as NSError {
                    print("Could not save albums after image deletion \(error), \(error.userInfo)")
                }

                // If this image was uploaded with the iOS app,
                // update cache so that it can be re-uploaded.
                UploadManager.shared.backgroundQueue.async {
                    UploadManager.shared.uploadProvider.markAsDeletedPiwigoImages(withIDs: [imageID])
                }

                // Hide HUD
                self.updatePiwigoHUDwithSuccess { [self] in
                    self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { [self] in
                        // Display preceding/next image or return to album view
                        self.didRemoveImage()
                    }
                }
            } failure: { [self] error in
                self.deleteImageFromDatabaseError(error)
            }
        } failure: { [self] error in
            self.deleteImageFromDatabaseError(error)
        }
    }
    
    private func deleteImageFromDatabaseError(_ error: NSError) {
        DispatchQueue.main.async { [self] in
            let title = NSLocalizedString("deleteImageFail_title", comment: "Delete Failed")
            var message = NSLocalizedString("deleteImageFail_message", comment: "Image could not be deleted")
            self.dismissPiwigoError(withTitle: title, message: message,
                                    errorMessage: error.localizedDescription) { [unowned self] in
                // Hide HUD
                hidePiwigoHUD { [self] in
                    // Re-enable buttons
                    setEnableStateOfButtons(true)
                }
            }
        }
    }
}


// MARK: - SelectCategoryImageRemovedDelegate Methods
extension ImageViewController: SelectCategoryImageRemovedDelegate
{
    func didRemoveImage() {
        // Return to the album view if the album is empty
        let nbImages = images?.fetchedObjects?.count ?? 0
        if nbImages == 0 {
            // Return to the Album/Images collection view
            navigationController?.popViewController(animated: true)
            return
        }

        // Can we present the next image?
        if imageIndex < nbImages {
            // Create view controller for presenting next image
            guard let nextImage = imagePageViewController(atIndex: imageIndex) else { return }
            nextImage.imagePreviewDelegate = self

            // This changes the View Controller
            // and calls the presentationIndexForPageViewController datasource method
            pageViewController!.setViewControllers([nextImage], direction: .forward, animated: true) { [unowned self] finished in
                // Update image data
                self.imageData = images?.object(at: IndexPath(row: imageIndex, section: 0))
                // Re-enable buttons
                self.setEnableStateOfButtons(true)
                // Reset favorites button
                // pwg.users.favorites… methods available from Piwigo version 2.10
                if "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending {
                    let isFavorite = (imageData?.albums ?? Set<Album>())
                        .contains(where: {$0.pwgID == pwgSmartAlbum.favorites.rawValue})
                    self.favoriteBarButton?.setFavoriteImage(for: isFavorite)
                }
            }
            return
        }

        // Can we present the preceding image?
        if imageIndex > 0 {
            // Create view controller for presenting next image
            imageIndex -= 1
            guard let prevImage = imagePageViewController(atIndex: imageIndex) else { return }
            prevImage.imagePreviewDelegate = self

            // This changes the View Controller
            // and calls the presentationIndexForPageViewController datasource method
            pageViewController!.setViewControllers( [prevImage], direction: .reverse, animated: true) { [unowned self] finished in
                // Update image data
                self.imageData = images?.object(at: IndexPath(row: imageIndex, section: 0))
                // Re-enable buttons
                self.setEnableStateOfButtons(true)
                // Reset favorites button
                if "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending {
                    let isFavorite = (imageData?.albums ?? Set<Album>())
                        .contains(where: {$0.pwgID == pwgSmartAlbum.favorites.rawValue})
                    self.favoriteBarButton?.setFavoriteImage(for: isFavorite)
                }
            }
            return
        }
    }
}
