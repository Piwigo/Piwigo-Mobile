//
//  SelectCategoryViewController+DataSource.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 01/01/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

// MARK: - UITableView - Diffable Data Source
extension SelectCategoryViewController
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
extension SelectCategoryViewController: UITableViewDataSource
{
    func numberOfSections(in tableView: UITableView) -> Int {
        switch wantedAction {
        case .setAlbumThumbnail:
            return 2
        default:    // Present recent albums if any
            let objects = recentAlbums.fetchedObjects ?? []
            return 1 + (objects.isEmpty ? 0 : 1)
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch wantedAction {
        case .setAlbumThumbnail:
            if section == 0 {
                return inputImages.first?.albums?.filter({$0.pwgID > 0}).count ?? 0
            } else {
                return (albums.fetchedObjects ?? []).count
            }
        default:    // Present recent albums if any
            if ((recentAlbums.fetchedObjects ?? []).count > 0) && (section == 0) {
                return (recentAlbums.fetchedObjects ?? []).count
            } else {
                return (albums.fetchedObjects ?? []).count
            }
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
            if wantedAction == .setAlbumThumbnail {
                // Albums in which this image belongs to
                var catId = inputAlbum.pwgID     // This album always exists in cache
                if let catIds = inputImages.first?.albums?.compactMap({$0.pwgID}).filter({$0 > 0}),
                   catIds.count > indexPath.row {
                    catId = catIds[indexPath.row]
                }
                guard let selectedAlbum = try? AlbumProvider().getAlbum(ofUser: user, withId: catId)
                else { return cell }
                albumData = selectedAlbum
            } else if hasRecentAlbums {
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
        switch wantedAction {
        case .setDefaultAlbum:
            // The current default category is not selectable
            if albumData.pwgID == inputAlbum.pwgID {
                cell.configure(with: albumData, atDepth: depth, andButtonState: .none)
                cell.albumLabel.textColor = PwgColor.rightLabel
            } else {
                // Don't present sub-albums in Recent Albums section
                if hasRecentAlbums && (indexPath.section == 0) {
                    cell.configure(with: albumData, atDepth: depth, andButtonState: .none)
                } else {
                    cell.configure(with: albumData, atDepth: depth, andButtonState: buttonState)
                }
            }
        case .moveAlbum:
            // User cannot move album to current parent album or in itself
            if albumData.pwgID == 0 {  // Special case: upperCategories is nil for root
                // Root album => No button
                cell.configure(with: albumData, atDepth: depth, andButtonState: .none)
                // Is the root album parent of the input album?
                if inputAlbum.parentId == 0 {
                    // Yes => Change text colour
                    cell.albumLabel.textColor = PwgColor.rightLabel
                }
            }
            else if hasRecentAlbums && (indexPath.section == 0) {
                // Don't present sub-albums in Recent Albums section
                cell.configure(with: albumData, atDepth: depth, andButtonState: .none)
            }
            else if albumData.pwgID == inputAlbum.parentId {
                // This album is the parent of the input album => Change text colour
                cell.configure(with: albumData, atDepth: depth, andButtonState: buttonState)
                cell.albumLabel.textColor = PwgColor.rightLabel
            }
            else if albumData.upperIds.components(separatedBy: ",")
                .compactMap({Int32($0)}).contains(inputAlbum.pwgID) {
                // This album is a sub-album of the input album => No button
                cell.configure(with: albumData, atDepth: depth, andButtonState: .none)
                cell.albumLabel.textColor = PwgColor.rightLabel
            } else {
                // Not a parent of a sub-album of the input album
                cell.configure(with: albumData, atDepth: depth, andButtonState: buttonState)
            }
        case .setAlbumThumbnail:
            // Don't present sub-albums in first section
            if indexPath.section == 0 {
                cell.configure(with: albumData, atDepth: depth, andButtonState: .none)
            } else {
                cell.configure(with: albumData, atDepth: depth, andButtonState: buttonState)
            }
        case .setAutoUploadAlbum:
            // Don't present sub-albums in Recent Albums section
            if hasRecentAlbums && (indexPath.section == 0) {
                cell.configure(with: albumData, atDepth: depth, andButtonState: .none)
            } else {
                cell.configure(with: albumData, atDepth: depth, andButtonState: buttonState)
            }
        case .copyImage, .copyImages, .moveImage, .moveImages:
            // Don't present sub-albums in Recent Albums section
            if hasRecentAlbums && (indexPath.section == 0) {
                cell.configure(with: albumData, atDepth: depth, andButtonState: .none)
            } else {
                cell.configure(with: albumData, atDepth: depth, andButtonState: buttonState)
            }
            // Albums containing the image are not selectable
            if commonCatIDs.contains(albumData.pwgID) {
                cell.albumLabel.textColor = PwgColor.rightLabel
            }

        default:
            break
        }

        cell.isAccessibilityElement = true
        return cell
    }
}
