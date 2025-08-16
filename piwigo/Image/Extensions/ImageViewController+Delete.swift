//
//  ImageViewController+Delete.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit
import uploadKit

extension ImageViewController
{
    // MARK: - Delete/Remove Image Bar Button
    func getDeleteBarButton() -> UIBarButtonItem {
        return UIBarButtonItem.deleteImageButton(self, action: #selector(deleteImage))
    }


    // MARK: - Delete or Remove Image from Album
    @MainActor
    @objc func deleteImage() {
        // Disable buttons during action
        setEnableStateOfButtons(false)

        let alert = UIAlertController(title: "",
            message: imageData.isVideo ? NSLocalizedString("deleteSingleVideo_message", comment: "Are you sure you want to delete this image? This cannot be undone!") : NSLocalizedString("deleteSingleImage_message", comment: "Are you sure you want to delete this image? This cannot be undone!"),
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
            title: imageData.isVideo ? NSLocalizedString("deleteSingleVideo_title", comment: "Delete Video") : NSLocalizedString("deleteSingleImage_title", comment: "Delete Image"),
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
        alert.view.tintColor = PwgColor.orange
        alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        alert.popoverPresentationController?.barButtonItem = deleteBarButton
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = PwgColor.orange
        }
    }
    
    @MainActor
    func removeImageFromAlbum() {
        // Display HUD during deletion
        showHUD(withTitle: imageData.isVideo ? NSLocalizedString("removeSingleVideoHUD_removing", comment: "Removing Video…") : NSLocalizedString("removeSingleImageHUD_removing", comment: "Removing Photo…"))
        
        // Remove selected category ID from image category list
        guard let imageData = imageData,
              var catIDs = imageData.albums?.compactMap({$0.pwgID}).filter({$0 > 0}) else {
            dismissPiwigoError(withTitle: NSLocalizedString("deleteImageFail_title", comment: "Delete Failed")) { [self] in
                // Hide HUD
                self.hideHUD { [self] in
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
        PwgSession.checkSession(ofUser: user) { [self] in
            PwgSession.shared.setInfos(with: paramsDict) { [self] in
                DispatchQueue.main.async { [self] in
                    // Retrieve album
                    if let albums = imageData.albums,
                       let album = albums.first(where: {$0.pwgID == categoryId}) {
                        // Remove image from album
                        album.removeFromImages(imageData)
                        
                        // Update albums
                        self.albumProvider.updateAlbums(removingImages: 1, fromAlbum: album)
                        
                        // Save changes
                        self.mainContext.saveIfNeeded()
                    }
                    
                    // Hide HUD
                    self.updateHUDwithSuccess { [self] in
                        self.hideHUD(afterDelay: pwgDelayHUD) { [self] in
                            // Display preceding/next image or return to album view
                            self.didRemoveImage()
                        }
                    }
                }
            } failure: { [self] error in
                DispatchQueue.main.async { [self] in
                    self.removeImageFromAlbumError(error)
                }
            }
        } failure: { [self] error in
            DispatchQueue.main.async { [self] in
                self.removeImageFromAlbumError(error)
            }
        }
    }
    
    @MainActor
    private func removeImageFromAlbumError(_ error: Error) {
        // Session logout required?
        if let pwgError = error as? PwgSessionError, pwgError.requiresLogout {
            ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
            return
        }

        // Report error
        let title = NSLocalizedString("deleteImageFail_title", comment: "Delete Failed")
        let message = NSLocalizedString("deleteImageFail_message", comment: "Image could not be deleted")
        self.dismissPiwigoError(withTitle: title, message: message, errorMessage: error.localizedDescription) { [self] in
            // Hide HUD
            hideHUD { [self] in
                // Re-enable buttons
                setEnableStateOfButtons(true)
            }
        }
    }
    
    @MainActor
    func deleteImageFromDatabase() {
        // Remove selected category ID from image category list
        guard let imageData = imageData else {
            dismissPiwigoError(withTitle: NSLocalizedString("deleteImageFail_title", comment: "Delete Failed")) { [self] in
                // Hide HUD
                self.hideHUD { [self] in
                    // Re-enable buttons
                    self.setEnableStateOfButtons(true)
                }
            }
            return
        }

        // Display HUD during deletion
        showHUD(withTitle: imageData.isVideo ? NSLocalizedString("deleteSingleVideoHUD_deleting", comment: "Deleting Video…") : NSLocalizedString("deleteSingleImageHUD_deleting", comment: "Deleting Photo…"))
        
        // Send request to Piwigo server
        PwgSession.checkSession(ofUser: user) { [self] in
            ImageUtilities.delete(Set([imageData])) { [self] in
                DispatchQueue.main.async { [self] in
                    // Save image ID for marking Upload request in the background
                    let imageID = imageData.pwgID
                    
                    // Delete image from cache (also deletes image files)
                    self.mainContext.delete(imageData)
                    
                    // Retrieve albums associated to the deleted image
                    if let albums = imageData.albums {
                        // Remove image from cached albums
                        albums.forEach { album in
                            self.albumProvider.updateAlbums(removingImages: 1, fromAlbum: album)
                        }
                    }
                    
                    // Save changes
                    self.mainContext.saveIfNeeded()
                    
                    // If this image was uploaded with the iOS app,
                    // delete upload request from cache so that it can be re-uploaded.
                    UploadManager.shared.backgroundQueue.async {
                        UploadManager.shared.deleteUploadsOfDeletedImages(withIDs: [imageID])
                    }
                    
                    // Hide HUD
                    self.updateHUDwithSuccess { [self] in
                        self.hideHUD(afterDelay: pwgDelayHUD) { [self] in
                            // Display preceding/next image or return to album view
                            self.didRemoveImage()
                        }
                    }
                }
            } failure: { [self] error in
                DispatchQueue.main.async { [self] in
                    self.deleteImageFromDatabaseError(error)
                }
            }
        } failure: { [self] error in
            DispatchQueue.main.async { [self] in
                self.deleteImageFromDatabaseError(error)
            }
        }
    }
    
    @MainActor
    private func deleteImageFromDatabaseError(_ error: Error) {
        // Session logout required?
        if let pwgError = error as? PwgSessionError, pwgError.requiresLogout {
            ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
            return
        }

        // Report error
        let title = NSLocalizedString("deleteImageFail_title", comment: "Delete Failed")
        let message = NSLocalizedString("deleteImageFail_message", comment: "Image could not be deleted")
        self.dismissPiwigoError(withTitle: title, message: message, errorMessage: error.localizedDescription) { [self] in
            // Hide HUD
            hideHUD { [self] in
                // Re-enable buttons
                setEnableStateOfButtons(true)
            }
        }
    }
}


// MARK: - SelectCategoryImageRemovedDelegate Methods
extension ImageViewController: SelectCategoryImageRemovedDelegate
{
    func didRemoveImage() {
        // Is the album empty?
        let nbImages = images?.fetchedObjects?.count ?? 0
        guard nbImages != 0, let sections = images.sections
        else {
            // Return to the Album/Images collection view
            navigationController?.dismiss(animated: true)
            return
        }

        // Was user scrolling towards next images?
        if didPresentNextPage {
            // Can we present a next image having the same index path?
            if indexPath.section < sections.count,
               indexPath.item < sections[indexPath.section].numberOfObjects {
                // Present the next image
                presentImage(inDirection: .forward)
                return
            } 
            else if let newIndexPath = getIndexPath(after: indexPath) {
                // Present the first image of the next section
                indexPath = newIndexPath
                presentImage(inDirection: .forward)
                return
            }
            else if let newIndexPath = getIndexPath(before: indexPath) {
                // Present the preceding image
                indexPath = newIndexPath
                presentImage(inDirection: .reverse)
                didPresentNextPage = false
                return
            }
        } else {
            // Can we present the preceding image?
            if let newIndexPath = getIndexPath(before: indexPath) {
                indexPath = newIndexPath
                presentImage(inDirection: .reverse)
                return
            }
            else if indexPath.section < sections.count,
                    indexPath.item < sections[indexPath.section].numberOfObjects {
                // Present the next image having the same indexPath
                didPresentNextPage = true
                presentImage(inDirection: .forward)
                return
            }
            else if let newIndexPath = getIndexPath(after: indexPath) {
                // Present the next image belonging to the next section
                indexPath = newIndexPath
                didPresentNextPage = true
                presentImage(inDirection: .forward)
                return
            }
        }
        
        // Return to the Album/Images collection view
        navigationController?.dismiss(animated: true)
        return
    }
    
    private func presentImage(inDirection direction: UIPageViewController.NavigationDirection) {
        // Create image detail view controller
        var newImageVC: UIViewController?
        let imageData = getImageData(atIndexPath: indexPath)
        let fileType = pwgImageFileType(rawValue: imageData.fileType) ?? .image
        switch fileType {
        case .image:
            newImageVC = imageDetailViewController(ofImage: imageData, atIndexPath: indexPath)
        case .video:
            newImageVC = videoDetailViewController(ofImage: imageData, atIndexPath: indexPath)
        case .pdf:
            newImageVC = pdfDetailViewController(ofImage: imageData, atIndexPath: indexPath)
        }
        guard let newImageVC = newImageVC
        else {
            // Return to the Album/Images collection view
            navigationController?.dismiss(animated: true)
            return
        }

        // This changes the View Controller
        // and calls the presentationIndexForPageViewController datasource method
        pageViewController?.setViewControllers([newImageVC], direction: direction, animated: true) { [self] finished in
            // Update image data
            self.imageData = imageData
            // Set title view
            self.setTitleViewFromImageData()
            // Re-enable buttons
            self.setEnableStateOfButtons(true)
            // Reset favorites button
            // pwg.users.favorites… methods available from Piwigo version 2.10
            self.favoriteBarButton = getFavoriteBarButton()
            // Scroll album collection view to keep the selected image centred on the screen
            self.imgDetailDelegate?.didSelectImage(atIndexPath: indexPath)
        }
    }
}
