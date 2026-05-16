//
//  ShareViewController+DataSource.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/05/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import UIKit
import PwgKit

// MARK: - UITableView - Diffable Data Source
extension ShareViewController
{
//    func configDataSource() -> DataSource {
//        let dataSource = DataSource(tableView: queueTableView) { [self] (tableView, indexPath, objectID) -> UITableViewCell? in
//            // Get data source item
//            guard let upload = try? self.mainContext.existingObject(with: objectID) as? Upload else {
//                preconditionFailure("Managed item should be available")
//            }
//            // Configure cell
//            guard let cell = tableView.dequeueReusableCell(withIdentifier: "UploadImageTableViewCell", for: indexPath) as? UploadImageTableViewCell
//            else { preconditionFailure("Error: tableView.dequeueReusableCell does not return a UploadImageTableViewCell!") }
//            cell.configure(with: upload, availableWidth: Int(tableView.bounds.size.width))
//            return cell
//        }
//        dataSource.defaultRowAnimation = .fade
//        return dataSource
//    }
}


// MARK: - UITableViewDataSource Methods
// Exclusively for iOS 12.x
extension ShareViewController: UITableViewDataSource
{
    func numberOfSections(in tableView: UITableView) -> Int {
        // Present recent albums if any
        let objects = recentAlbums.fetchedObjects ?? []
        return 1 + (objects.isEmpty ? 0 : 1)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Present recent albums if any
        if ((recentAlbums.fetchedObjects ?? []).count > 0) && (section == 0) {
            return (recentAlbums.fetchedObjects ?? []).count
        } else {
            return (albums.fetchedObjects ?? []).count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "CategoryTableViewCell", for: indexPath) as? CategoryTableViewCell
        else { preconditionFailure("Error: tableView.dequeueReusableCell does not return a CategoryTableViewCell!") }
        var depth = 0
        let albumData: Album
        let hasRecentAlbums = (recentAlbums.fetchedObjects ?? []).isEmpty == false
        switch indexPath.section {
        case 0:
            if hasRecentAlbums {
                // Recent albums
                albumData = recentAlbums.object(at: indexPath)
            } else {
                // All albums
                albumData = albums.object(at: indexPath)
                if albumData.parentId > 0 {
                    depth += albumData.upperIds.components(separatedBy: ",")
                        .filter({ Int32($0) != albumData.pwgID }).count
                }
            }
        default:
            let albumIndexPath = IndexPath(item: indexPath.item, section: 0)
            albumData = albums.object(at: albumIndexPath)
            if albumData.parentId > 0 {
                depth += albumData.upperIds.components(separatedBy: ",")
                    .filter({ Int32($0) != albumData.pwgID }).count
            }
        }
        
        // No button if the user does not have upload rights
        var buttonState: pwgCategoryCellButtonState = .none
        let allAlbums: [Album] = albums.fetchedObjects ?? []
        let filteredCat = allAlbums.filter({ user.hasAdminRights ||
                                             userUploadRights.contains($0.pwgID) })
        if filteredCat.count > 0 {
            buttonState = albumsShowingSubAlbums.contains(albumData.pwgID) ? .hideSubAlbum : .showSubAlbum
        }

        // How should we present the category
        cell.delegate = self
        // Don't present sub-albums in first section
        if indexPath.section == 0 {
            cell.configure(with: albumData, atDepth: depth, andButtonState: .none)
        } else {
            cell.configure(with: albumData, atDepth: depth, andButtonState: buttonState)
        }
        
        cell.isAccessibilityElement = true
        return cell
    }
}
