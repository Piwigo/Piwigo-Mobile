//
//  SelectCategoryViewController+Delegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 01/01/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit


// MARK: - UITableViewDelegate Methods
extension SelectCategoryViewController: UITableViewDelegate
{
    // MARK: - UITableView - Headers
    private func getContentOfHeader(inSection section: Int) -> (String, String) {
        var title = "", text = ""
        switch wantedAction {
        case .setAlbumThumbnail:
            // 1st section —> Albums containing image
            if section == 0 {
                // Title
                title = String(format: "%@\n", String(localized: "tabBar_albums", bundle: piwigoKit, comment: "Albums"))
                text = inputImages.first?.albums?.count ?? 0 > 1 ?
                NSLocalizedString("categorySelection_one", comment:"Select one of the albums containing this image") :
                NSLocalizedString("categorySelection_current", comment:"Select the current album for this image")
            } else {
                // Text
                text = NSLocalizedString("categorySelection_other", comment:"or select another album for this image")
            }
            
        default:
            // 1st section —> Recent albums
            if section == 0 {
                // Do we have recent albums to show?
                title = (recentAlbums.fetchedObjects ?? []).count > 0 ?
                NSLocalizedString("maxNberOfRecentAlbums>320px", comment: "Recent Albums") :
                String(localized: "tabBar_albums", bundle: piwigoKit, comment: "Albums")
            } else {
                // 2nd section
                title = NSLocalizedString("categorySelection_allAlbums", comment: "All Albums")
            }
        }
        return (title, text)
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let (title, text) = getContentOfHeader(inSection: section)
        return TableViewUtilities.shared.heightOfHeader(withTitle: title, text: text,
                                                        width: tableView.frame.size.width)
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let (title, text) = getContentOfHeader(inSection: section)
        return TableViewUtilities.shared.viewOfHeader(withTitle: title, text: text)
    }
    
    
    // MARK: - UITableView - Rows
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        // Retrieve album data
        let albumData: Album
        let hasRecentAlbums = (recentAlbums.fetchedObjects ?? []).count > 0
        switch indexPath.section {
        case 0:
            // Provided album
            if wantedAction == .setAlbumThumbnail {
                var catId = inputAlbum.pwgID     // This album always exists in cache
                if let catIds = inputImages.first?.albums?.compactMap({$0.pwgID}).filter({$0 > 0}),
                   catIds.count > indexPath.row {
                    catId = catIds[indexPath.row]
                }
                albumData = albumProvider.getAlbum(ofUser: user, withId: catId)!
            } else if hasRecentAlbums {
                // Recent albums
                albumData = recentAlbums.object(at: indexPath)
            } else {
                // All albums
                albumData = albums.object(at: indexPath)
            }
        default:
            let albumIndexPath = IndexPath(item: indexPath.item, section: 0)
            albumData = albums.object(at: albumIndexPath)
        }
        
        switch wantedAction {
        case .setDefaultAlbum:
            // The current default category is not selectable
            debugPrint("••> albums: \(albumData.pwgID) and \(inputAlbum.pwgID)")
            if albumData.pwgID == inputAlbum.pwgID {
                return false
            }
            
        case .moveAlbum:
            // Do nothing if this is the input category
            if albumData.pwgID == inputAlbum.pwgID {
                return false
            }
            // User cannot move album to current parent album or in itself
            if albumData.pwgID == 0 {  // upperCategories is nil for root
                if inputAlbum.parentId == 0 {
                    return false
                }
            } else if (albumData.pwgID == inputAlbum.parentId) ||
                        albumData.upperIds.components(separatedBy: ",")
                .compactMap({Int32($0)}).contains(inputAlbum.pwgID) {
                return false
            }
            
        case .setAlbumThumbnail:
            // The root album is not selectable (should not be presented but in case…)
            if albumData.pwgID == 0 {
                return false
            }
            
        case .setAutoUploadAlbum:
            // The root album is not selectable (should not be presented but in case…)
            if albumData.pwgID == 0 {
                return false
            }
            
        case .copyImage, .copyImages, .moveImage, .moveImages:
            // The root album is not selectable (should not be presented but in case…)
            if albumData.pwgID == 0 {
                return false
            }
            // Albums containing all the images are not selectable
            if commonCatIDs.contains(albumData.pwgID) {
                return false
            }
            
        default:
            return false
        }
        return true;
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)

        // Get selected category
        let albumData: Album
        let hasRecentAlbums = (recentAlbums.fetchedObjects ?? []).count > 0
        switch indexPath.section {
        case 0:
            // Provided album
            if wantedAction == .setAlbumThumbnail {
                var catId = inputAlbum.pwgID     // This album always exists in cache
                if let catIds = inputImages.first?.albums?.compactMap({$0.pwgID}).filter({$0 > 0}),
                   catIds.count > indexPath.row {
                    catId = catIds[indexPath.row]
                }
                albumData = albumProvider.getAlbum(ofUser: user, withId: catId)!
            } else if hasRecentAlbums {
                // Recent albums
                albumData = recentAlbums.object(at: indexPath)
            } else {
                // All albums
                albumData = albums.object(at: indexPath)
            }
        default:
            let albumIndexPath = IndexPath(item: indexPath.item, section: 0)
            albumData = albums.object(at: albumIndexPath)
        }
        
        // Remember the choice
        selectedCategoryId = albumData.pwgID

        // What should we do with this selection?
        switch wantedAction {
        case .setDefaultAlbum:
            // Do nothing if this is the current default category
            if (albumData.pwgID == Int32.min) ||
                (albumData.pwgID == inputAlbum.pwgID) { return }
            
            // Ask user to confirm
            let title = NSLocalizedString("setDefaultCategory_title", comment: "Default Album")
            let message:String
            if albumData.pwgID == 0 {
                message = String(format: NSLocalizedString("setDefaultCategory_message", comment: "Are you sure you want to set the album %@ as default album?"),   pwgSmartAlbum.root.name)
            } else {
                message = String(format: NSLocalizedString("setDefaultCategory_message", comment: "Are you sure you want to set the album %@ as default album?"), albumData.name)
            }
            requestConfirmation(withTitle: title, message: message,
                                forCategory: albumData, at: indexPath, handler: { [self] _ in
                // Set new Default Album
                self.delegate?.didSelectCategory(withId: albumData.pwgID)
                // Return to Settings
                self.navigationController?.popViewController(animated: true)
            })

        case .moveAlbum:
            // Do nothing if this is the current default category
            if albumData.pwgID == inputAlbum.pwgID { return }

            // User must not move album to current parent album or in itself
            if albumData.pwgID == 0 {  // upperCategories is nil for root
                if inputAlbum.parentId == 0 {
                    return
                }
            } else {
                let parentIds = albumData.upperIds.components(separatedBy: ",")
                if albumData.pwgID == inputAlbum.parentId ||
                    parentIds.contains(where: { Int32($0) == inputAlbum.pwgID}) {
                    return
                }
            }

            // Ask user to confirm
            let title = NSLocalizedString("moveCategory", comment: "Move Album")
            let message = String(format: NSLocalizedString("moveCategory_message", comment: "Are you sure you want to move \"%@\" into the album \"%@\"?"), inputAlbum.name, albumData.name)
            requestConfirmation(withTitle: title, message: message,
                                forCategory: albumData, at: indexPath) { [self] _ in
                // Move album to selected category
                self.moveCategory(intoCategory: albumData)
            }

        case .setAlbumThumbnail:
            // Ask user to confirm
            let title = NSLocalizedString("categoryImageSet_title", comment:"Album Thumbnail")
            let message = String(format: NSLocalizedString("categoryImageSet_message", comment:"Are you sure you want to set this image for the album \"%@\"?"), albumData.name)
            requestConfirmation(withTitle: title, message: message,
                                forCategory: albumData, at: indexPath, handler: { [self] _ in
                // Set image as thumbnail of selected album
                self.setRepresentative(for: albumData)
            })

        case .setAutoUploadAlbum:
            // Do nothing if this is the root album
            if albumData.pwgID == 0 { return }
            
            // Return the selected album ID
            delegate?.didSelectCategory(withId: albumData.pwgID)
            navigationController?.popViewController(animated: true)
            
        case .copyImage:
            // Do nothing if this is the root album
            if albumData.pwgID == 0 { return }
            // Do nothing if the image already belongs to the selected album
            if commonCatIDs.contains(albumData.pwgID) { return }

            // Ask user to confirm
            let title = NSLocalizedString("copyImage_title", comment:"Copy to Album")
            let imageTitle = inputImages.first?.titleStr ?? inputImages.first?.fileName ?? ""
            let message = String(format: NSLocalizedString("copySingleImage_message", comment:"Are you sure you want to copy the photo \"%@\" to the album \"%@\"?"), imageTitle.isEmpty ? inputImages.first?.fileName ?? "-?-" : imageTitle, albumData.name)
            requestConfirmation(withTitle: title, message: message,
                                forCategory: albumData, at: indexPath) { [self] _ in
                // Display HUD
                self.showHUD(withTitle: NSLocalizedString("copySingleImageHUD_copying", comment:"Copying Photo…"))

                // Copy single image to selected album
                if NetworkVars.shared.usesSetCategory {
                    self.associateImages(toAlbum: albumData)
                } else {
                    self.copyImages(toAlbum: albumData)
                }
            }

        case .moveImage:
            // Do nothing if this is the root album
            if albumData.pwgID == 0 { return }
            // Do nothing if the image already belongs to the selected album
            if commonCatIDs.contains(albumData.pwgID) { return }

            // Ask user to confirm
            let title = NSLocalizedString("moveImage_title", comment:"Move to Album")
            let imageTitle = inputImages.first?.titleStr ?? inputImages.first?.fileName ?? ""
            let message = String(format: NSLocalizedString("moveSingleImage_message", comment:"Are you sure you want to move the photo \"%@\" to the album \"%@\"?"), imageTitle.isEmpty ? inputImages.first?.fileName ?? "-?-" : imageTitle, albumData.name)
            requestConfirmation(withTitle: title, message: message,
                                forCategory: albumData, at: indexPath) { [self] _ in
                // Display HUD
                self.showHUD(withTitle: NSLocalizedString("moveSingleImageHUD_moving", comment:"Moving Photo…"))

                // Move single image to selected album
                if NetworkVars.shared.usesSetCategory {
                    self.associateImages(toAlbum: albumData, andDissociateFromPreviousAlbum: true)
                } else {
                    self.moveImages(toAlbum: albumData)
                }
            }

        case .copyImages:
            // Do nothing if this is the root album
            if albumData.pwgID == 0 { return }
            // Do nothing if the images already belong to the selected album
            if commonCatIDs.contains(albumData.pwgID) { return }

            // Ask user to confirm
            let title = NSLocalizedString("copyImage_title", comment:"Copy to Album")
            let message = String(format: NSLocalizedString("copySeveralImages_message", comment:"Are you sure you want to copy the photos to the album \"%@\"?"), albumData.name)
            requestConfirmation(withTitle: title, message: message,
                                forCategory: albumData, at: indexPath) { [self] _ in
                // Display HUD
                self.showHUD(withTitle: NSLocalizedString("copySeveralImagesHUD_copying", comment: "Copying Photos…"),
                             inMode: NetworkVars.shared.usesSetCategory ? .indeterminate : .determinate)
                
                // Copy several images to selected album
                if NetworkVars.shared.usesSetCategory {
                    self.associateImages(toAlbum: albumData)
                } else {
                    self.copyImages(toAlbum: albumData)
                }
            }

        case .moveImages:
            // Do nothing if this is the root album
            if albumData.pwgID == 0 { return }
            // Do nothing if the images already belong to the selected album
            if commonCatIDs.contains(albumData.pwgID) { return }

            // Ask user to confirm
            let title = NSLocalizedString("moveImage_title", comment:"Move to Album")
            let message = String(format: NSLocalizedString("moveSeveralImages_message", comment:"Are you sure you want to move the photos to the album \"%@\"?"), albumData.name)
            requestConfirmation(withTitle: title, message: message,
                                forCategory: albumData, at: indexPath) { [self] _ in
                // Display HUD
                self.showHUD(withTitle: NSLocalizedString("moveSeveralImagesHUD_moving", comment: "Moving Photos…"),
                             inMode: NetworkVars.shared.usesSetCategory ? .indeterminate : .determinate)

                // Move several images to selected album
                if NetworkVars.shared.usesSetCategory {
                    self.associateImages(toAlbum: albumData, andDissociateFromPreviousAlbum: true)
                } else {
                    self.moveImages(toAlbum: albumData)
                }
            }

        default:
            break
        }
    }
    
    @MainActor
    private func requestConfirmation(withTitle title:String, message:String,
                                     forCategory albumData: Album, at indexPath:IndexPath,
                                     handler:((UIAlertAction) -> Void)? = nil) -> Void {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        let cancelAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
                                         style: .cancel, handler: {_ in
                                            // Forget the choice
                                            self.selectedCategoryId = Int32.min
                                         })
        let performAction = UIAlertAction(title: NSLocalizedString("alertYesButton", comment: "Yes"), style: .default, handler:handler)
    
        // Add actions
        alert.addAction(cancelAction)
        alert.addAction(performAction)

        // Present popover view
        alert.view.tintColor = PwgColor.tintColor
        alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        alert.popoverPresentationController?.sourceView = categoriesTableView
        alert.popoverPresentationController?.sourceRect = categoriesTableView.rectForRow(at: indexPath)
        alert.popoverPresentationController?.permittedArrowDirections = [.down, .up]
        present(alert, animated: true, completion: {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = PwgColor.tintColor
        })
    }
}
