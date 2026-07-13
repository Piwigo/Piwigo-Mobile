//
//  ShareViewController+Delegate.swift
//  shareExtension
//
//  Created by Eddy Lelièvre-Berna on 19/05/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import UIKit
import PwgKit
import PwgCacheKit
import PwgUIKit

// MARK: - UITableViewDelegate Methods
extension ShareViewController: UITableViewDelegate
{
    // MARK: - UITableView - Headers
    private func getContentOfHeader(inSection section: Int) -> (String) {
        // 1st section —> Recent albums?
        if section == 0 {
            // Do we have recent albums to show?
            return (recentAlbums.fetchedObjects ?? []).count > 0
                ? Localized.recentAlbums : Localized.tabBar_albums
        } else {
            // 2nd section
            return Localized.allAlbums
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let title = getContentOfHeader(inSection: section)
        return TableViewUtilities.heightOfHeader(withTitle: title, text: "",
                                                 width: tableView.frame.size.width)
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let title = getContentOfHeader(inSection: section)
        return TableViewUtilities.viewOfHeader(withTitle: title, text: "")
    }
    
    
    // MARK: - UITableView - Rows
    private func album(at indexPath: IndexPath) -> Album {
        let hasRecentAlbums = (recentAlbums.fetchedObjects ?? []).count > 0
        switch indexPath.section {
        case 0:
            if hasRecentAlbums {
                // Recent albums
                return recentAlbums.object(at: indexPath)
            } else {
                // All albums
                return albums.object(at: indexPath)
            }
        default:
            let albumIndexPath = IndexPath(item: indexPath.item, section: 0)
            return albums.object(at: albumIndexPath)
        }
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        // Retrieve album data
        let albumData: Album = album(at: indexPath)
        
        // The root album is not selectable (should not be presented but in case…)
        return albumData.pwgID == 0 ? false : true
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Deselect album
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Get selected category
        let albumData: Album = album(at: indexPath)
        
        // Do nothing if this is the root album
        if albumData.pwgID == 0 { return }
        
        // Ask user to confirm
        let title = String(localized: "uploadToAlbum_title", comment:"Upload to Album")
        let strFormat = String(localized: "uploadToAlbum_message", comment:"Are you sure you want to upload the photos to the album \"%@\"?")
        let message = unsafe String(format: strFormat, albumData.name)
        Task { @MainActor in
            if await requestConfirmation(withTitle: title, message: message,
                                         forCategory: albumData, at: indexPath) {
                // Wait until all shared items have been copied to the Uploads folder
                if itemsAreReady == false {
                    showHUD()
                }
                let nbCopiedItems = await copyItemsTask?.value ?? 0
                hideHUD()

                // Tell the user when no item could be copied
                if nbCopiedItems == 0 {
                    presentShareFailAlert()
                    return
                }
                
                // Launch the app to select options
                openMainApp(withAlbumIDs: albumData.upperIds, forItemsSharedAt: shareDate)
            }
        }
    }
    
    @MainActor
    private func requestConfirmation(withTitle title:String, message:String,
                                     forCategory albumData: Album, at indexPath:IndexPath) async -> Bool {
        await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
            let cancelAction = UIAlertAction(title: Localized.cancel,
                                             style: .cancel, handler: {_ in
                continuation.resume(returning: false)
            })
            let performAction = UIAlertAction(title: Localized.yes, style: .default, handler: { _ in
                continuation.resume(returning: true)
            })
            
            // Add actions
            alert.addAction(cancelAction)
            alert.addAction(performAction)
            
            // Present popover view
            alert.view.tintColor = PwgColor.tintColor
            alert.overrideUserInterfaceStyle = InterfaceVars.shared.isDarkPaletteActive ? .dark : .light
            alert.popoverPresentationController?.sourceView = categoriesTableView
            alert.popoverPresentationController?.sourceRect = categoriesTableView.rectForRow(at: indexPath)
            alert.popoverPresentationController?.permittedArrowDirections = [.down, .up]
            present(alert, animated: true, completion: {
                // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                alert.view.tintColor = PwgColor.tintColor
            })
        }
    }
    
    @MainActor
    private func presentShareFailAlert() {
        let alert = UIAlertController(title: String(localized: "shareFailError_title", comment: "Share Failed"),
                                      message: String(localized: "shareFailError_message", comment: "Failed to retrieve the shared photos and videos."),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: Localized.dismiss,
                                      style: .cancel, handler: { [weak self] _ in
            // Nothing to upload —> delete stray files and close the share sheet
            self?.cancelSelect()
        }))
        
        // Present alert
        alert.view.tintColor = PwgColor.tintColor
        alert.overrideUserInterfaceStyle = InterfaceVars.shared.isDarkPaletteActive ? .dark : .light
        present(alert, animated: true, completion: {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = PwgColor.tintColor
        })
    }
    
    private func openMainApp(withAlbumIDs upperIds: String, forItemsSharedAt shareDate: String) {
        // Prepare URL
        var comps = URLComponents()
        comps.scheme = "piwigo"
        comps.host = "share-extension"
        comps.queryItems = [URLQueryItem(name: "albumIDs", value: upperIds),
                            URLQueryItem(name: "date", value: shareDate)]
        guard let url = comps.url else { return }
        
        // Send album IDs and date of share to main app
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                // Open main app
                application.open(url, options: [:]) { _ in
                    // Job completed
                    self.context?.completeRequest(returningItems: nil, completionHandler: nil)
                }
                return
            }
            responder = responder?.next
        }
    }
}
