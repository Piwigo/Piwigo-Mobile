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
                removeImageFromCategory()
            })

        let deleteAction = UIAlertAction(
            title: NSLocalizedString("deleteSingleImage_title", comment: "Delete Image"),
            style: .destructive, handler: { [self] action in
                deleteImageFromDatabase()
            })

        // Add actions
        alert.addAction(cancelAction)
        alert.addAction(deleteAction)
        if let categoryIds = imageData.categoryIds, categoryIds.count > 1,
           categoryId > 0 {
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

    func removeImageFromCategory() {
        // Display HUD during deletion
        showPiwigoHUD(withTitle: NSLocalizedString("removeSingleImageHUD_removing", comment: "Removing Photo…"), detail: "", buttonTitle: "", buttonTarget: nil, buttonSelector: nil, inMode: .indeterminate)

        // Update image category list
        guard var categoryIds = imageData.categoryIds else {
            dismissPiwigoError(withTitle: NSLocalizedString("deleteImageFail_title", comment: "Delete Failed")) {
                // Hide HUD
                self.hidePiwigoHUD { [unowned self] in
                    // Re-enable buttons
                    self.setEnableStateOfButtons(true)
                }
            }
            return
        }
        categoryIds.removeAll { $0 as AnyObject === NSNumber(value: categoryId) as AnyObject }

        // Prepare parameters for removing the image/video from the selected category
        let newImageCategories = categoryIds.compactMap({ $0.stringValue }).joined(separator: ";")
        let paramsDict: [String : Any] = ["image_id"            : imageData.imageId,
                                          "categories"          : newImageCategories,
                                          "multiple_value_mode" : "replace"]
        
        // Send request to Piwigo server
        ImageUtilities.setInfos(with: paramsDict) { [unowned self] in
            // Update image data
            self.imageData.categoryIds = categoryIds

            // Hide HUD
            self.updatePiwigoHUDwithSuccess { [unowned self] in
                self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { [unowned self] in
                    // Remove image from cache and update UI in main thread
                    CategoriesData.sharedInstance()
                        .removeImage(self.imageData, fromCategory: String(self.categoryId))
                    // Display preceding/next image or return to album view
                    self.didRemoveImage(withId: self.imageData.imageId)
                }
            }
        } failure: { [unowned self] error in
            let title = NSLocalizedString("deleteImageFail_title", comment: "Delete Failed")
            var message = NSLocalizedString("deleteImageFail_message", comment: "Image could not be deleted")
            self.dismissRetryPiwigoError(withTitle: title, message: message,
                                         errorMessage: error.localizedDescription, dismiss: { [unowned self] in
                // Hide HUD
                hidePiwigoHUD { [unowned self] in
                    // Re-enable buttons
                    setEnableStateOfButtons(true)
                }
            }, retry: { [unowned self] in
                // Relogin and retry
                LoginUtilities.reloginAndRetry() { [unowned self] in
                    removeImageFromCategory()
                } failure: { [unowned self] error in
                    message = NSLocalizedString("internetErrorGeneral_broken", comment: "Sorry…")
                    dismissPiwigoError(withTitle: title, message: message,
                                       errorMessage: error?.localizedDescription ?? "") { [unowned self] in
                        hidePiwigoHUD { [unowned self] in
                            // Re-enable buttons
                            setEnableStateOfButtons(true)
                        }
                    }
                }
            })
        }
    }

    func deleteImageFromDatabase() {
        // Display HUD during deletion
        showPiwigoHUD(withTitle: NSLocalizedString("deleteSingleImageHUD_deleting", comment: "Deleting Image…"), detail: "", buttonTitle: "", buttonTarget: nil, buttonSelector: nil, inMode: .indeterminate)

        // Send request to Piwigo server
        ImageUtilities.delete([imageData]) { [unowned self] in
            // Hide HUD
            self.updatePiwigoHUDwithSuccess { [unowned self] in
                self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { [self] in
                    // Display preceding/next image or return to album view
                    self.didRemoveImage(withId: imageData.imageId)
                }
            }
        } failure: { [unowned self] error in
            let title = NSLocalizedString("deleteImageFail_title", comment: "Delete Failed")
            var message = NSLocalizedString("deleteImageFail_message", comment: "Image could not be deleted")
            self.dismissRetryPiwigoError(withTitle: title, message: message,
                                         errorMessage: error.localizedDescription, dismiss: { [unowned self] in
                // Hide HUD
                hidePiwigoHUD { [unowned self] in
                    // Re-enable buttons
                    setEnableStateOfButtons(true)
                }
            }, retry: { [unowned self] in
                // Relogin and retry
                LoginUtilities.reloginAndRetry() { [unowned self] in
                    deleteImageFromDatabase()
                } failure: { [unowned self] error in
                    message = NSLocalizedString("internetErrorGeneral_broken", comment: "Sorry…")
                    dismissPiwigoError(withTitle: title, message: message,
                                       errorMessage: error?.localizedDescription ?? "") { [unowned self] in
                        hidePiwigoHUD { [unowned self] in
                            // Re-enable buttons
                            setEnableStateOfButtons(true)
                        }
                    }
                }
            })
        }
    }
}


// MARK: - SelectCategoryImageRemovedDelegate Methods
extension ImageViewController: SelectCategoryImageRemovedDelegate
{
    func didRemoveImage(withId imageID: Int) {
        // Determine index of the removed image
        guard let indexOfRemovedImage = images.firstIndex(where: { $0.imageId == imageID }) else { return }

        // Remove the image from the datasource
        images.remove(at: indexOfRemovedImage)

        // Return to the album view if the album is empty
        if images.isEmpty {
            // Return to the Album/Images collection view
            navigationController?.popViewController(animated: true)
            return
        }

        // Can we present the next image?
        if indexOfRemovedImage < images.count {
            // Retrieve data of next image (may be incomplete)
            let imageData = images[indexOfRemovedImage]

            // Create view controller for presenting next image
            guard let nextImage = imagePageViewController(atIndex: indexOfRemovedImage) else { return }
            nextImage.imagePreviewDelegate = self
            imageIndex = indexOfRemovedImage

            // This changes the View Controller
            // and calls the presentationIndexForPageViewController datasource method
            pageViewController!.setViewControllers([nextImage], direction: .forward, animated: true) { [unowned self] finished in
                // Update image data
                self.imageData = self.images[indexOfRemovedImage]
                // Re-enable buttons
                self.setEnableStateOfButtons(true)
                // Reset favorites button
                // pwg.users.favorites… methods available from Piwigo version 2.10
                if "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending {
                    let isFavorite = CategoriesData.sharedInstance()
                        .category(withId: kPiwigoFavoritesCategoryId,
                                  containsImagesWithId: [NSNumber(value: imageData.imageId)])
                    self.favoriteBarButton?.setFavoriteImage(for: isFavorite)
                }
            }
            return
        }

        // Can we present the preceding image?
        if indexOfRemovedImage > 0 {
            // Retrieve data of next image (may be incomplete)
            let imageData = images[indexOfRemovedImage - 1]

            // Create view controller for presenting next image
            guard let prevImage = imagePageViewController(atIndex: indexOfRemovedImage - 1) else { return }
            prevImage.imagePreviewDelegate = self
            imageIndex = indexOfRemovedImage - 1

            // This changes the View Controller
            // and calls the presentationIndexForPageViewController datasource method
            pageViewController!.setViewControllers( [prevImage], direction: .reverse, animated: true) { [unowned self] finished in
                // Re-enable buttons
                self.setEnableStateOfButtons(true)
                // Reset favorites button
                if "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending {
                    let isFavorite = CategoriesData.sharedInstance()
                        .category(withId: kPiwigoFavoritesCategoryId,
                                  containsImagesWithId: [NSNumber(value: imageData.imageId)])
                    self.favoriteBarButton?.setFavoriteImage(for: isFavorite)
                }
            }
            return
        }
    }
}
