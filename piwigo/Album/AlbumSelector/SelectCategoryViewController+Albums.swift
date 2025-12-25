//
//  SelectCategoryViewController+Albums.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/12/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

extension SelectCategoryViewController
{
    // MARK: - Move Category Methods
    @MainActor
    func moveCategory(intoCategory parentData: Album) {
        // Display HUD during the update
        showHUD(withTitle: NSLocalizedString("moveCategoryHUD_moving", comment: "Moving Album…"))

        // Add category ID to list of recently used albums
        let userInfo = ["categoryId": parentData.pwgID]
        NotificationCenter.default.post(name: .pwgAddRecentAlbum, object: nil, userInfo: userInfo)

        // Move album
        Task {
            do {
                // Check session
                try await JSONManager.shared.checkSession(ofUserWithID: user.objectID, lastConnected: user.lastUsed)
                
                // Move album
                try await JSONManager.shared.move(self.inputAlbum.pwgID, intoAlbumWithId: parentData.pwgID)
                
                // Remember that the app is fetching all album data
                AlbumVars.shared.isFetchingAlbumData.insert(0)

                // Fetch album data recursively
                let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
                try await AlbumProvider().fetchAlbums(forUser: user, inParentWithId: 0, recursively: true,
                                                      thumbnailSize: thumnailSize)
                
                // Remove current album from list of album being fetched
                AlbumVars.shared.isFetchingAlbumData.remove(0)

                // Update cache and UI
                await MainActor.run {
                    self.updateHUDwithSuccess() { [self] in
                        self.hideHUD(afterDelay: pwgDelayHUD) { [self] in
                            self.dismiss(animated: true)
                        }
                    }
                }
            }
            catch let error as PwgKitError {
                await MainActor.run {
                    self.hideHUD { [self] in
                        self.showError(error)
                    }
                }
            }
        }
    }

    
    // MARK: - Set Album Thumbnail Methods
    @MainActor
    func setRepresentative(for albumData: Album) {
        guard let imageData = self.inputImages.first else { return }
        
        // Display HUD during the update
        showHUD(withTitle: NSLocalizedString("categoryImageSetHUD_updating", comment:"Updating Album Thumbnail…"))
        
        // Set image as representative
        Task {
            do {
                // Check session
                try await JSONManager.shared.checkSession(ofUserWithID: user.objectID, lastConnected: user.lastUsed)
                
                // Set album representative
                try await JSONManager.shared.setRepresentative(albumData, with: imageData)
                
                // Update cache and UI
                await MainActor.run { [self] in
                    // Album thumbnail successfully changed ▶ Update catagory in cache
                    albumData.thumbnailId = imageData.pwgID
                    let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
                    albumData.thumbnailUrl = ImageUtilities.getPiwigoURL(imageData, ofMinSize: thumnailSize) as NSURL?
                    
                    // Save changes
                    self.mainContext.saveIfNeeded()
                    
                    // Close HUD
                    self.updateHUDwithSuccess() { [self] in
                        self.hideHUD(afterDelay: pwgDelayHUD) { [self] in
                            self.dismiss(animated: true)
                        }
                    }
                }
            }
            catch let error as PwgKitError {
                await MainActor.run { [self] in
                    self.showError(error)
                }
            }
        }
    }
}
