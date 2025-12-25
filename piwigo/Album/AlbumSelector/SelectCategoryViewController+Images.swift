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
    /// For calling Piwigo server in version 2.10 to 13.x
    @MainActor
    func copyImages(toAlbum albumData: Album) async {
        // Check image data
        guard let imageData = inputImages.first else {
            self.didCopyImagesWithSuccess()
            return
        }
        
        // Copy next image to seleted album
        do {
            try await self.copyImage(imageData, toAlbum: albumData)
            self.inputImages.remove(imageData)
            self.updateHUD(withProgress: Float(1) - Float(self.inputImages.count) / Float(self.nberOfImages))
            await self.copyImages(toAlbum: albumData)
        }
        catch {
            self.didFailWithError(error)
        }
    }
    
    /// For calling Piwigo server in version 2.10 to 13.x
    private func copyImage(_ imageData: Image, toAlbum albumData: Album) async throws(PwgKitError) {
        // Append selected category ID to image category list
        let albums = imageData.albums ?? Set<Album>()
        var categoryIds = albums.compactMap({$0.pwgID})
        categoryIds.append(albumData.pwgID)
        
        // Send requests to Piwigo server
        Task {
            // Check session
            try await JSONManager.shared.checkSession(ofUserWithID: user.objectID, lastConnected: user.lastUsed)
            
            // Prepare parameters for copying the image/video to the selected category
            let newImageCategories = categoryIds.compactMap({ String($0) }).joined(separator: ";")
            let paramsDict: [String : Any] = ["image_id"            : imageData.pwgID,
                                              "categories"          : newImageCategories,
                                              "multiple_value_mode" : "replace"]
            
            // Set image properties
            _ = try await JSONManager.shared.setInfos(with: paramsDict)
            
            await MainActor.run {
                // Add image to album
                albumData.addToImages(imageData)

                // Update albums
                try? AlbumProvider().updateAlbums(addingImages: 1, toAlbum: albumData)

                // Set album thumbnail with first copied image if necessary
                if [nil, Int64.zero].contains(albumData.thumbnailId) || albumData.thumbnailUrl == nil {
                    albumData.thumbnailId = imageData.pwgID
                    let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
                    albumData.thumbnailUrl = ImageUtilities.getPiwigoURL(imageData, ofMinSize: thumnailSize) as NSURL?
                }
            }
        }
    }
    
    /// For calling Piwigo server in version +14.0
    func associateImages(toAlbum albumData: Album, andDissociateFromPreviousAlbum dissociate: Bool = false) {
        // Send request to Piwigo server
        let albumID = albumData.pwgID
        let imageIDs = self.inputImages.map({ $0.pwgID })
        Task {
            do {
                // Check session
                try await JSONManager.shared.checkSession(ofUserWithID: user.objectID, lastConnected: user.lastUsed)
                
                // Associate images
                try await JSONManager.shared.setCategory(albumID, forImageIDs: imageIDs, withAction: .associate)

                // Update cache
                await MainActor.run {
                    // Add image to album
                    albumData.addToImages(self.inputImages)

                    // Update albums
                    let nberOfImages = Int64(self.inputImages.count)
                    try? AlbumProvider().updateAlbums(addingImages: nberOfImages, toAlbum: albumData)

                    // Set album thumbnail with first copied image if necessary
                    if [nil, Int64.zero].contains(albumData.thumbnailId) || albumData.thumbnailUrl == nil,
                       let imageData = inputImages.first {
                        albumData.thumbnailId = imageData.pwgID
                        let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
                        albumData.thumbnailUrl = ImageUtilities.getPiwigoURL(imageData, ofMinSize: thumnailSize) as NSURL?
                    }

                    // Should we also dissociate the images?
                    if dissociate {
                        // Dissociate images from the current album
                        self.dissociateImages(fromAlbum: self.inputAlbum)
                    } else {
                        // Close HUD, save modified data
                        self.didCopyImagesWithSuccess()
                    }
                }
            }
            catch let error as PwgKitError {
                await MainActor.run {
                    self.didFailWithError(error)
                }
            }
        }
    }
    
    @MainActor
    private func didCopyImagesWithSuccess() {
        // Close HUD
        updateHUDwithSuccess() { [self] in
            // Save changes
            self.mainContext.saveIfNeeded()
            // Hide HUD and dismiss album selector
            self.hideHUD(afterDelay: pwgDelayHUD) { [self] in
                self.dismiss(animated: true) { [self] in
                    // Update image data in current view (ImageDetailImage view)
                    self.imageCopiedDelegate?.didCopyImage()
                }
            }
        }
    }
    
    @MainActor
    private func didFailWithError(_ error: PwgKitError) {
        // Hide HUD and inform user
        self.hideHUD { [self] in
            self.showError(error)
        }
    }
    
    
    // MARK: - Move Images Methods
    /// For calling Piwigo server in version 2.10 to 13.x
    @MainActor
    func moveImages(toAlbum albumData: Album) async {
        // Add category ID to list of recently used albums
        let userInfo = ["categoryId": albumData.pwgID]
        NotificationCenter.default.post(name: .pwgAddRecentAlbum, object: nil, userInfo: userInfo)
        
        // Jobe done?
        guard let imageData = inputImages.first else {
            self.didMoveImagesWithSuccess()
            return
        }
        
        // Move next image to seleted album
        do {
            try await moveImage(imageData, toCategory: albumData)
            // Next image…
            self.inputImages.remove(imageData)
            self.updateHUD(withProgress: 1.0 - Float(self.inputImages.count) / Float(self.nberOfImages))
            await self.moveImages(toAlbum: albumData)
        }
        catch {
            self.didFailWithError(error)
        }
    }
    
    /// For calling Piwigo server in version 2.10 to 13.x
    private func moveImage(_ imageData: Image, toCategory albumData: Album) async throws(PwgKitError) {
        // Append selected category ID to image category list
        let albums = imageData.albums ?? Set<Album>()
        var categoryIds = albums.compactMap({$0.pwgID})
        categoryIds.append(albumData.pwgID)
        
        // Remove current categoryId from image category list
        categoryIds.removeAll(where: {$0 == inputAlbum.pwgID})
                
        // Send requests to Piwigo server
        Task {
            // Check session
            try await JSONManager.shared.checkSession(ofUserWithID: user.objectID, lastConnected: user.lastUsed)
            
            // Prepare parameters for moving the image/video to the selected category
            let newImageCategories = categoryIds.compactMap({ String($0) }).joined(separator: ";")
            let paramsDict: [String : Any] = ["image_id"            : imageData.pwgID,
                                              "categories"          : newImageCategories,
                                              "multiple_value_mode" : "replace"]
            
            // Set image properties
            _ = try await JSONManager.shared.setInfos(with: paramsDict)
            
            await MainActor.run {
                // Add image to target album
                albumData.addToImages(imageData)

                // Update target albums
                try? AlbumProvider().updateAlbums(addingImages: 1, toAlbum: albumData)

                // Set album thumbnail with first copied image if necessary
                if [nil, Int64.zero].contains(albumData.thumbnailId) || albumData.thumbnailUrl == nil {
                    albumData.thumbnailId = imageData.pwgID
                    let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
                    albumData.thumbnailUrl = ImageUtilities.getPiwigoURL(imageData, ofMinSize: thumnailSize) as NSURL?
                }

                // Remove image from source album
                imageData.removeFromAlbums(self.inputAlbum)

                // Update albums
                try? AlbumProvider().updateAlbums(removingImages: 1, fromAlbum: self.inputAlbum)
            }
        }
    }
    
    /// For calling Piwigo server in version +14.0
    @MainActor
    func dissociateImages(fromAlbum albumData: Album) {
        let albumID = albumData.pwgID
        let imageIDs = self.inputImages.map({ $0.pwgID })
        // Send requests to Piwigo server
        Task {
            do {
                // Check session
                try await JSONManager.shared.checkSession(ofUserWithID: user.objectID, lastConnected: user.lastUsed)
                
                // Associate images
                try await JSONManager.shared.setCategory(albumID, forImageIDs: imageIDs, withAction: .dissociate)

                // Update cache
                await MainActor.run {
                    // Remove images from album
                    albumData.removeFromImages(self.inputImages)

                    // Update albums
                    let nberOfImages = Int64(self.inputImages.count)
                    try? AlbumProvider().updateAlbums(removingImages: nberOfImages, fromAlbum: albumData)

                    // Close HUD, save modified data
                    self.didMoveImagesWithSuccess()
                }
            }
            catch let error as PwgKitError {
                await MainActor.run {
                    self.didFailWithError(error)
                }
            }
        }
    }
    
    @MainActor
    private func didMoveImagesWithSuccess() {
        // Close HUD
        updateHUDwithSuccess() { [self] in
            // Save changes
            self.mainContext.saveIfNeeded()
            
            // Hide HUD and dismiss album selector
            self.hideHUD(afterDelay: pwgDelayHUD) { [self] in
                self.dismiss(animated: true) { [self] in
                    // Remove image from ImageViewController
                    self.imageRemovedDelegate?.didRemoveImage()
                }
            }
        }
    }
}
