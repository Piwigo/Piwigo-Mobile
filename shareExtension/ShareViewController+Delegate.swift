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
                ? Localized.recentAlbums
                : String(localized: "tabBar_albums", bundle: .pwgKit, comment: "Albums")
        } else {
            // 2nd section
            return String(localized: "categorySelection_allAlbums", comment: "All Albums")
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
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        // Retrieve album data
        let albumData: Album
        let hasRecentAlbums = (recentAlbums.fetchedObjects ?? []).count > 0
        switch indexPath.section {
        case 0:
            if hasRecentAlbums {
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
        
        // The root album is not selectable (should not be presented but in case…)
        return albumData.pwgID == 0 ? false : true
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)

        // Get selected category
        let albumData: Album
        let hasRecentAlbums = (recentAlbums.fetchedObjects ?? []).count > 0
        switch indexPath.section {
        case 0:
            if hasRecentAlbums {
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
        
        // Do nothing if this is the root album
        if albumData.pwgID == 0 { return }

        // Ask user to confirm
        let title = String(localized: "uploadToAlbum_title", comment:"Upload to Album")
        let strFormat = String(localized: "uploadToAlbum_message", comment:"Are you sure you want to upload the photos to the album \"%@\"?")
        let message = unsafe String(format: strFormat, albumData.name)
        Task { @MainActor in
            let confirmed = await requestConfirmation(withTitle: title, message: message,
                                                      forCategory: albumData, at: indexPath)
            if confirmed {
                // Launch the app to select options
                
            }
            
            // Job done
            cancelSelect()
        }
    }
    
    @MainActor
    private func requestConfirmation(withTitle title:String, message:String,
                                     forCategory albumData: Album, at indexPath:IndexPath) async -> Bool {
        await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
            let cancelAction = UIAlertAction(title: Localized.cancel,
                                             style: .cancel, handler: {_ in
                // Forget the choice
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
}
