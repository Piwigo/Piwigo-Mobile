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
        showHUD(withTitle: NSLocalizedString("moveCategoryHUD_moving", comment: "Moving Album…"))

        // Add category to list of recent albums
        let userInfo = ["categoryId": parentData.pwgID]
        NotificationCenter.default.post(name: .pwgAddRecentAlbum, object: nil, userInfo: userInfo)

        // Move album
        PwgSession.checkSession(ofUser: user) {  [self] in
            AlbumUtilities.move(self.inputAlbum.pwgID,
                                intoAlbumWithId: parentData.pwgID) { [self] in
                // Remember that the app is fetching all album data
                AlbumVars.shared.isFetchingAlbumData.insert(0)

                // Use the AlbumProvider to fetch album data. On completion,
                // handle general UI updates and error alerts on the main queue.
                let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
                albumProvider.fetchAlbums(forUser: user, inParentWithId: 0, recursively: true,
                                          thumbnailSize: thumnailSize) { [self] error in
                    // ► Remove current album from list of album being fetched
                    AlbumVars.shared.isFetchingAlbumData.remove(0)

                    // Check error
                    guard let error = error else {
                        // No error ► Hide HUD
                        self.updateHUDwithSuccess() {
                            self.hideHUD(afterDelay: pwgDelayHUD) {
                                self.dismiss(animated: true)
                            }
                        }
                        return
                    }
                    
                    // Show the error
                    DispatchQueue.main.async { [self] in
                        self.hideHUD {
                            self.showError(error)
                        }
                    }
                }
            } failure: { [unowned self] error in
                self.hideHUD {
                    self.showError(error)
                }
            }
        } failure: { [unowned self] error in
            self.hideHUD {
                self.showError(error)
            }
        }
    }

    
    // MARK: - Set Album Thumbnail Methods
    func setRepresentative(for albumData: Album) {
        guard let imageData = self.inputImages.first else { return }
        
        // Display HUD during the update
        showHUD(withTitle: NSLocalizedString("categoryImageSetHUD_updating", comment:"Updating Album Thumbnail…"))
        
        // Set image as representative
        PwgSession.checkSession(ofUser: user) {  [self] in
            AlbumUtilities.setRepresentative(albumData, with: imageData)
            {
                DispatchQueue.main.async { [self] in
                    // Save changes
                    do {
                        try self.mainContext.save()
                    } catch let error as NSError {
                        debugPrint("Could not fetch \(error), \(error.userInfo)")
                    }

                    // Close HUD
                    self.updateHUDwithSuccess() {
                        self.hideHUD(afterDelay: pwgDelayHUD) {
                            self.dismiss(animated: true)
                        }
                    }
                }
            } failure: { [unowned self] error in
                self.hideHUD {
                    self.showError(error)
                }
            }
        } failure: { [unowned self] error in
            self.hideHUD {
                self.showError(error)
            }
        }
    }
}
