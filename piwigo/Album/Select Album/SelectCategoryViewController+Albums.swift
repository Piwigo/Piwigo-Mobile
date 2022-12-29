//
//  SelectCategoryViewController+Albums.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/12/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

extension SelectCategoryViewController {
    // MARK: - Move Category Methods
    func moveCategory(intoCategory parentData: Album) {
        // Display HUD during the update
        showPiwigoHUD(withTitle: NSLocalizedString("moveCategoryHUD_moving", comment: "Moving Album…"))

        DispatchQueue.global(qos: .userInitiated).async {
            // Add category to list of recent albums
            let userInfo = ["categoryId": parentData.pwgID]
            NotificationCenter.default.post(name: .pwgAddRecentAlbum, object: nil, userInfo: userInfo)

            // Move album
            AlbumUtilities.move(self.inputAlbum.pwgID,
                                intoAlbumWithId: parentData.pwgID) { [self] in
                // Update cached albums in the background
                DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
                    albumProvider.moveAlbum(self.inputAlbum.pwgID, intoAlbumWithId: parentData.pwgID)
                }
                
                // Hide HUD, swipe and view then remove category from the album/images collection view
                self.updatePiwigoHUDwithSuccess() {
                    self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) {
                        self.dismiss(animated: true) {
                            self.albumMovedDelegate?.didMoveCategory()
                        }
                    }
                }
            } failure: { [unowned self] error in
                self.hidePiwigoHUD {
                    guard let error = error as NSError? else {
                        self.showError()
                        return
                    }
                    self.showError(with: error.localizedDescription)
                }
            }
        }
    }

    
    // MARK: - Set Album Thumbnail Methods
    func setRepresentative(for albumData: Album) {
        guard let imageData = self.inputImages.first else { return }
        
        // Display HUD during the update
        showPiwigoHUD(withTitle: NSLocalizedString("categoryImageSetHUD_updating", comment:"Updating Album Thumbnail…"))
        
        // Set image as representative
        DispatchQueue.global(qos: .userInitiated).async {
            AlbumUtilities.setRepresentative(albumData, with: imageData)
            {
                DispatchQueue.main.async { [self] in
                    // Save changes
                    do {
                        try self.savingContext.save()
                    } catch let error as NSError {
                        print("Could not fetch \(error), \(error.userInfo)")
                    }

                    // Close HUD
                    self.updatePiwigoHUDwithSuccess() {
                        self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) {
                            self.dismiss(animated: true)
                        }
                    }
                }
            } failure: { [unowned self] error in
                self.hidePiwigoHUD {
                    guard let error = error as NSError? else {
                        self.showError()
                        return
                    }
                    self.showError(with: error.localizedDescription)
                }
            }
        }
    }
}
