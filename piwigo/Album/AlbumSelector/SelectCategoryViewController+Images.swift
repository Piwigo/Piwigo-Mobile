//
//  SelectCategoryViewController+Images.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/12/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

extension SelectCategoryViewController
{
    // MARK: - Copy Images Methods
    func copyImages(toAlbum albumData: Album) {
        // Check image data
        guard let imageData = inputImages.first else {
            self.didCopyImagesWithSuccess()
            return
        }
        
        // Copy next image to seleted album
        self.copyImage(imageData, toAlbum: albumData) { [self] in
            // Next image…
            self.inputImages.remove(imageData)
            self.updateHUD(withProgress: Float(1) - Float(self.inputImages.count) / Float(self.nberOfImages))
            self.copyImages(toAlbum: albumData)
        }
        onFailure: { [self] error in
            self.copyImagesDidFailWithError(error)
        }
    }
    
    private func copyImage(_ imageData: Image, toAlbum albumData: Album,
                           onCompletion completion: @escaping () -> Void,
                           onFailure fail: @escaping (_ error: Error?) -> Void) {
        // Append selected category ID to image category list
        let albums = imageData.albums ?? Set<Album>()
        var categoryIds = albums.compactMap({$0.pwgID})
        categoryIds.append(albumData.pwgID)
        
        // Prepare parameters for copying the image/video to the selected category
        let newImageCategories = categoryIds.compactMap({ String($0) }).joined(separator: ";")
        let paramsDict: [String : Any] = ["image_id"            : imageData.pwgID,
                                          "categories"          : newImageCategories,
                                          "multiple_value_mode" : "replace"]
        
        // Send request to Piwigo server
        PwgSession.checkSession(ofUser: user) { [self] in
            PwgSession.shared.setInfos(with: paramsDict) { [self] in
                DispatchQueue.main.async { [self] in
                    // Add image to album
                    albumData.addToImages(imageData)
                    
                    // Update albums
                    self.albumProvider.updateAlbums(addingImages: 1, toAlbum: albumData)
                    
                    // Set album thumbnail with first copied image if necessary
                    if [nil, Int64.zero].contains(albumData.thumbnailId) || albumData.thumbnailUrl == nil {
                        albumData.thumbnailId = imageData.pwgID
                        let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
                        albumData.thumbnailUrl = ImageUtilities.getPiwigoURL(imageData, ofMinSize: thumnailSize) as NSURL?
                    }
                }
                completion()
            } failure: { error in
                fail(error)
            }
        } failure: { error in
            fail(error)
        }
    }
    
    func associateImages(toAlbum albumData: Album) {
        // Send request to Piwigo server
        PwgSession.checkSession(ofUser: user) { [self] in
            ImageUtilities.setCategory(albumData, forImages: self.inputImages, withAction: .associate) {
                DispatchQueue.main.async { [self] in
                    // Add image to album
                    albumData.addToImages(self.inputImages)
                    
                    // Update albums
                    let nberOfImages = Int64(self.inputImages.count)
                    self.albumProvider.updateAlbums(addingImages: nberOfImages, toAlbum: albumData)
                    
                    // Set album thumbnail with first copied image if necessary
                    if [nil, Int64.zero].contains(albumData.thumbnailId) || albumData.thumbnailUrl == nil,
                       let imageData = inputImages.first {
                        albumData.thumbnailId = imageData.pwgID
                        let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
                        albumData.thumbnailUrl = ImageUtilities.getPiwigoURL(imageData, ofMinSize: thumnailSize) as NSURL?
                    }
                    // Close HUD, save modified data
                    self.didCopyImagesWithSuccess()
                }
            } failure: { [self] error in
                self.copyImagesDidFailWithError(error)
            }
        } failure: { [self] error in
            self.copyImagesDidFailWithError(error)
        }
    }
    
    private func didCopyImagesWithSuccess() {
        // Close HUD
        updateHUDwithSuccess() { [self] in
            // Save changes
            do {
                try self.mainContext.save()
            } catch let error {
                debugPrint("Could not save copied images, \(error)")
            }
            // Hide HUD and dismiss album selector
            self.hideHUD(afterDelay: pwgDelayHUD) { [self] in
                self.dismiss(animated: true) { [self] in
                    // Update image data in current view (ImageDetailImage view)
                    self.imageCopiedDelegate?.didCopyImage()
                }
            }
        }
    }
    
    private func copyImagesDidFailWithError(_ error: Error?) {
        // Close HUD, inform user and save in Core Data store
        self.hideHUD { [self] in
            self.showError(error)
        }
    }
    
    
    // MARK: - Move Images Methods
    func moveImages(toAlbum albumData: Album) {
        // Add category to list of recent albums
        let userInfo = ["categoryId": albumData.pwgID]
        NotificationCenter.default.post(name: .pwgAddRecentAlbum, object: nil, userInfo: userInfo)
        
        // Jobe done?
        guard let imageData = inputImages.first else {
            // Close HUD
            updateHUDwithSuccess() { [self] in
                // Save changes
                do {
                    try self.mainContext.save()
                } catch let error {
                    debugPrint("Could not save moved images, \(error)")
                }

                // Hide HUD and dismiss album selector
                self.hideHUD(afterDelay: pwgDelayHUD) { [self] in
                    self.dismiss(animated: true) { [self] in
                        // Remove image from ImageViewController
                        self.imageRemovedDelegate?.didRemoveImage()
                    }
                }
            }
            return
        }
        
        // Move next image to seleted album
        moveImage(imageData, toCategory: albumData) { [self] in
            // Next image…
            self.inputImages.remove(imageData)
            self.updateHUD(withProgress: 1.0 - Float(self.inputImages.count) / Float(self.nberOfImages))
            self.moveImages(toAlbum: albumData)
        }
        onFailure: { [self] error in
            // Close HUD, inform user and save in Core Data store
            self.hideHUD { [self] in
                self.showError(error)
            }
        }
    }
    
    private func moveImage(_ imageData: Image, toCategory albumData: Album,
                           onCompletion completion: @escaping () -> Void,
                           onFailure fail: @escaping (_ error: Error?) -> Void) {
        // Append selected category ID to image category list
        let albums = imageData.albums ?? Set<Album>()
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
        PwgSession.checkSession(ofUser: user) { [self] in
            PwgSession.shared.setInfos(with: paramsDict) { [self] in
                DispatchQueue.main.async { [self] in
                    // Add image to target album
                    albumData.addToImages(imageData)
                    
                    // Update target albums
                    self.albumProvider.updateAlbums(addingImages: 1, toAlbum: albumData)
                    
                    // Set album thumbnail with first copied image if necessary
                    if [nil, Int64.zero].contains(albumData.thumbnailId) || albumData.thumbnailUrl == nil {
                        albumData.thumbnailId = imageData.pwgID
                        let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
                        albumData.thumbnailUrl = ImageUtilities.getPiwigoURL(imageData, ofMinSize: thumnailSize) as NSURL?
                    }
                    
                    // Remove image from source album
                    imageData.removeFromAlbums(self.inputAlbum)
                    
                    // Update albums
                    self.albumProvider.updateAlbums(removingImages: 1, fromAlbum: self.inputAlbum)
                }
                completion()
            } failure: { error in
                fail(error)
            }
        } failure: { error in
            fail(error)
        }
    }
}
