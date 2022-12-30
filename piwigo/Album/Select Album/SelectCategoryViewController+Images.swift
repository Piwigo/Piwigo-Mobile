//
//  SelectCategoryViewController+Images.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/12/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

extension SelectCategoryViewController {
    // MARK: - Retrieve Image Data
    func retrieveImageData() {
        // Job done?
        if inputImageIds.count == 0 {
            // We do have complete image data
            DispatchQueue.main.async { [self] in
                self.inputImages.forEach { image in
                    let catIDs = Set((image.albums ?? Set<Album>()).map({$0.pwgID}))
                    if commonCatIDs.isEmpty {
                        commonCatIDs = catIDs
                    } else {
                        commonCatIDs = commonCatIDs.intersection(catIDs)
                    }
                }
                self.hidePiwigoHUD { }
            }
            return
        }
        
        guard let imageId = inputImageIds.first else {
            self.hidePiwigoHUD {
                self.dismissPiwigoError(withTitle: NSLocalizedString("imageDetailsFetchError_title", comment: "Image Details Fetch Failed")) {
                    self.dismiss(animated: true) { }
                }
            }
            return
        }
        
        // Check whether we already have complete image data
        if let imageData = inputImages.first(where: {$0.pwgID == imageId}),
           imageData.fileSize != Int64.zero {
            inputImageIds.removeFirst()
            retrieveImageData()
            return
        }
        
        // Image data are not complete when retrieved using pwg.categories.getImages
        // Required by Copy, Delete, Move actions (may also be used to show albums image belongs to)
        imageProvider.getInfos(forID: imageId,
                               inCategoryId: inputAlbum.pwgID) { [self] in
            // Image info retrieved
            self.inputImageIds.removeFirst()
            
            // Update HUD
            self.updatePiwigoHUD(withProgress: 1.0 - Float(self.inputImageIds.count) / Float(self.nberOfImages))
            
            // Next image
            self.retrieveImageData()
            
        } failure: { [unowned self] error in
            let title = NSLocalizedString("imageDetailsFetchError_title", comment: "Image Details Fetch Failed")
            var message = NSLocalizedString("imageDetailsFetchError_retryMessage", comment: "Fetching the image data failed\nTry again?")
            dismissRetryPiwigoError(withTitle: title, message: message,
                                    errorMessage: error.localizedDescription, dismiss: {
            }, retry: { [unowned self] in
                // Relogin and retry
                LoginUtilities.reloginAndRetry() { [unowned self] in
                    retrieveImageData()
                } failure: { [unowned self] error in
                    message = NSLocalizedString("internetErrorGeneral_broken", comment: "Sorry…")
                    dismissPiwigoError(withTitle: title, message: message,
                                       errorMessage: error?.localizedDescription ?? "") { }
                }
            })
        }
    }
    
    
    // MARK: - Copy Images Methods
    func copyImages(toAlbum albumData: Album) {
        // Add category to list of recent albums
        let userInfo = ["categoryId": albumData.pwgID]
        NotificationCenter.default.post(name: .pwgAddRecentAlbum, object: nil, userInfo: userInfo)
        
        // Job done?
        if inputImages.count == 0 {
            // Close HUD
            updatePiwigoHUDwithSuccess() {
                // Save changes
                do {
                    try self.savingContext.save()
                } catch let error as NSError {
                    print("Could not save copied images \(error), \(error.userInfo)")
                }
                // Hide HUD and dismiss album selector
                self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) {
                    self.dismiss(animated: true) {
                        // Update image data in current view (ImageDetailImage view)
                        self.imageCopiedDelegate?.didCopyImage()
                    }
                }
            }
            return
        }
        
        // Check image data
        guard let imageData = inputImages.first else {
            // Close HUD, inform user and save in Core Data store
            self.hidePiwigoHUD { self.showError() }
            return
        }
        
        // Copy next image to seleted album
        self.copyImage(imageData, toAlbum: albumData) { success in
            if success {
                // Next image…
                self.inputImages.removeFirst()
                self.updatePiwigoHUD(withProgress: 1.0 - Float(self.inputImages.count) / Float(self.nberOfImages))
                self.copyImages(toAlbum: albumData)
            } else {
                // Close HUD, inform user and save in Core Data store
                self.hidePiwigoHUD { self.showError() }
            }
        } onFailure: { error in
            // Close HUD, inform user and save in Core Data store
            self.hidePiwigoHUD {
                self.showError(with: error?.localizedDescription ?? "")
            }
        }
    }
    
    private func copyImage(_ imageData: Image, toAlbum albumData: Album,
                           onCompletion completion: @escaping (_ success: Bool) -> Void,
                           onFailure fail: @escaping (_ error: NSError?) -> Void) {
        // Append selected category ID to image category list
        guard let albums = imageData.albums else {
            self.showError()
            return
        }
        var categoryIds = albums.compactMap({$0.pwgID})
        categoryIds.append(albumData.pwgID)
        
        // Prepare parameters for copying the image/video to the selected category
        let newImageCategories = categoryIds.compactMap({ String($0) }).joined(separator: ";")
        let paramsDict: [String : Any] = ["image_id"            : imageData.pwgID,
                                          "categories"          : newImageCategories,
                                          "multiple_value_mode" : "replace"]
        
        // Send request to Piwigo server
        ImageUtilities.setInfos(with: paramsDict) { [self] in
            // Add image to album
            albumData.addToImages(imageData)

            // Update albums
            self.albumProvider.updateAlbums(addingImages: 1, toAlbum: albumData)
            
            // Set album thumbnail with first copied image if necessary
            if [nil, Int64.zero].contains(albumData.thumbnailId) || albumData.thumbnailUrl == nil {
                albumData.thumbnailId = imageData.pwgID
                let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
                albumData.thumbnailUrl = ImageUtilities.getURLs(imageData, ofMinSize: thumnailSize)?.0
            }
            completion(true)
        } failure: { error in
            fail(error)
        }
    }
    
    
    // MARK: - Move Images Methods
    func moveImages(toAlbum albumData: Album) {
        // Add category to list of recent albums
        let userInfo = ["categoryId": albumData.pwgID]
        NotificationCenter.default.post(name: .pwgAddRecentAlbum, object: nil, userInfo: userInfo)
        
        // Jobe done?
        if inputImages.count == 0 {
            // Close HUD
            updatePiwigoHUDwithSuccess() {
                // Save changes
                do {
                    try self.savingContext.save()
                } catch let error as NSError {
                    print("Could not save moved images \(error), \(error.userInfo)")
                }
                // Hide HUD and dismiss album selector
                self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) {
                    self.dismiss(animated: true) {
                        // Remove image from ImageDetailImage view
                        self.imageRemovedDelegate?.didRemoveImage()
                    }
                }
            }
            return
        }
        
        // Check image data
        guard let imageData = inputImages.first else {
            // Close HUD, inform user and save in Core Data store
            self.hidePiwigoHUD { self.showError() }
            return
        }
        
        // Move next image to seleted album
        moveImage(imageData, toCategory: albumData) { success in
            if success {
                // Next image…
                self.inputImages.removeFirst()
                self.updatePiwigoHUD(withProgress: 1.0 - Float(self.inputImages.count) / Float(self.nberOfImages))
                self.moveImages(toAlbum: albumData)
            } else {
                // Close HUD, inform user and save in Core Data store
                self.hidePiwigoHUD { self.showError() }
            }
        } onFailure: { error in
            // Close HUD, inform user and save in Core Data store
            self.hidePiwigoHUD {
                self.showError(with: error?.localizedDescription ?? "")
            }
        }
    }
    
    private func moveImage(_ imageData: Image, toCategory albumData: Album,
                           onCompletion completion: @escaping (_ success: Bool) -> Void,
                           onFailure fail: @escaping (_ error: NSError?) -> Void) {
        // Append selected category ID to image category list
        guard let albums = imageData.albums else {
            self.showError()
            return
        }
        var categoryIds = albums.compactMap({$0.pwgID})
        categoryIds.append(albumData.pwgID)
        
        // Remove current categoryId from image category list
        categoryIds.removeAll(where: {$0 == inputAlbum.pwgID})
        
        // Prepare parameters for moving the image/video to the selected category
        let newImageCategories = categoryIds.compactMap({ String($0) }).joined(separator: ";")
        let paramsDict: [String : Any] = ["image_id"            : imageData.pwgID,
                                          "categories"          : newImageCategories,
                                          "multiple_value_mode" : "replace"]
        
        // Send request to Piwigo server
        ImageUtilities.setInfos(with: paramsDict) { [self] in
            // Add image to target album
            albumData.addToImages(imageData)

            // Update target albums
            self.albumProvider.updateAlbums(addingImages: 1, toAlbum: albumData)
            
            // Set album thumbnail with first copied image if necessary
            if [nil, Int64.zero].contains(albumData.thumbnailId) || albumData.thumbnailUrl == nil {
                albumData.thumbnailId = imageData.pwgID
                let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
                albumData.thumbnailUrl = ImageUtilities.getURLs(imageData, ofMinSize: thumnailSize)?.0
            }

            // Remove image from source album
            imageData.removeFromAlbums(inputAlbum)
            
            // Update albums
            self.albumProvider.updateAlbums(removingImages: 1, fromAlbum: inputAlbum)
            completion(true)
        } failure: { error in
            fail(error)
        }
    }
}
