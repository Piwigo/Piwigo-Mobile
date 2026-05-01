//
//  LocalAlbumsViewController+DataSource.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/09/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import Photos

// MARK: - UITableViewDataSource Methods
extension LocalAlbumsViewController: UITableViewDataSource {
    
    // MARK: - UITableView — Sections
    func numberOfSections(in tableView: UITableView) -> Int {
        var count = Int.zero

        // Consider non-empty collections
        count += self.localAlbumsProvider.localAlbums.isEmpty ? 0 : 1
        count += self.localAlbumsProvider.eventsAlbums.isEmpty ? 0 : 1
        count += self.localAlbumsProvider.syncedAlbums.isEmpty ? 0 : 1
        count += self.localAlbumsProvider.facesAlbums.isEmpty ? 0 : 1
        count += self.localAlbumsProvider.sharedAlbums.isEmpty ? 0 : 1
        count += self.localAlbumsProvider.mediaTypes.isEmpty ? 0 : 1
        count += self.localAlbumsProvider.otherAlbums.isEmpty ? 0 : 1
        
        // First section added for pasteboard if necessary
        return count + (hasImagesInPasteboard ? 1 : 0)
    }


    // MARK: - UITableView — Rows
    func albumTypeFor(section: Int) -> LocalAlbumType {
        // First section added for pasteboard?
        var activeSection: Int = section
        if hasImagesInPasteboard {
            switch section {
            case 0:
                return .pasteboard
            default:
                activeSection -= 1
            }
        }

        var counter: Int = -1
        counter += self.localAlbumsProvider.localAlbums.isEmpty ? 0 : 1
        if activeSection == counter { return .localAlbums }
        counter += self.localAlbumsProvider.eventsAlbums.isEmpty ? 0 : 1
        if activeSection == counter { return .eventsAlbums }
        counter += self.localAlbumsProvider.syncedAlbums.isEmpty ? 0 : 1
        if activeSection == counter { return .syncedAlbums }
        counter += self.localAlbumsProvider.facesAlbums.isEmpty ? 0 : 1
        if activeSection == counter { return .facesAlbums }
        counter += self.localAlbumsProvider.sharedAlbums.isEmpty ? 0 : 1
        if activeSection == counter { return .sharedAlbums }
        counter += self.localAlbumsProvider.mediaTypes.isEmpty ? 0 : 1
        if activeSection == counter { return .mediaTypes }
        counter += self.localAlbumsProvider.otherAlbums.isEmpty ? 0 : 1
        return .otherAlbums
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let albumType = albumTypeFor(section: section)
        var nberOfAlbums = 0
        switch albumType {
        case .pasteboard:
            return 1
        case .localAlbums:
            nberOfAlbums = self.localAlbumsProvider.localAlbums.count
        case .eventsAlbums:
            nberOfAlbums = self.localAlbumsProvider.eventsAlbums.count
        case .syncedAlbums:
            nberOfAlbums = self.localAlbumsProvider.syncedAlbums.count
        case .facesAlbums:
            nberOfAlbums = self.localAlbumsProvider.facesAlbums.count
        case .sharedAlbums:
            nberOfAlbums = self.localAlbumsProvider.sharedAlbums.count
        case .mediaTypes:
            nberOfAlbums = self.localAlbumsProvider.mediaTypes.count
        case .otherAlbums:
            nberOfAlbums = self.localAlbumsProvider.otherAlbums.count
        }
        return hasLimitedNberOfAlbums[albumType]! ? min(maxNberOfAlbumsInSection, nberOfAlbums) + 1 : nberOfAlbums
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var assetCollection: PHAssetCollection?
        let albumType = albumTypeFor(section: indexPath.section)
        let isLimited = hasLimitedNberOfAlbums[albumType]!
        switch albumType {
        case .pasteboard:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LocalAlbumsNoDatesTableViewCell", for: indexPath) as? LocalAlbumsNoDatesTableViewCell
            else { preconditionFailure("Could not load a LocalAlbumsNoDatesTableViewCell!") }
            let title = NSLocalizedString("categoryUpload_pasteboard", comment: "Clipboard")
            let nberPhotos = UIPasteboard.general.itemSet(withPasteboardTypes: pasteboardTypes)?.count ?? NSNotFound
            cell.configure(with: title, nberPhotos: Int64(nberPhotos))
            cell.isAccessibilityElement = true
            return cell
        case .localAlbums:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = self.localAlbumsProvider.localAlbums[indexPath.row]
            }
        case .eventsAlbums:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = self.localAlbumsProvider.eventsAlbums[indexPath.row]
            }
        case .syncedAlbums:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = self.localAlbumsProvider.syncedAlbums[indexPath.row]
            }
        case .facesAlbums:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = self.localAlbumsProvider.facesAlbums[indexPath.row]
            }
        case .sharedAlbums:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = self.localAlbumsProvider.sharedAlbums[indexPath.row]
            }
        case .mediaTypes:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = self.localAlbumsProvider.mediaTypes[indexPath.row]
            }
        case .otherAlbums:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = self.localAlbumsProvider.otherAlbums[indexPath.row]
            }
        }

        // Display [+] button at the bottom of section presenting a limited number of albums
        guard let aCollection = assetCollection else {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LocalAlbumsMoreTableViewCell", for: indexPath) as? LocalAlbumsMoreTableViewCell
            else { preconditionFailure("Could not load a LocalAlbumsMoreTableViewCell!") }
            cell.configure()
            cell.isAccessibilityElement = true
            return cell
        }
        
        // Case of an album
        let title = aCollection.localizedTitle ?? "— ? —"
        let nberPhotos = Int64(aCollection.estimatedAssetCount)

        if let startDate = aCollection.startDate, let endDate = aCollection.endDate {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LocalAlbumsTableViewCell", for: indexPath) as? LocalAlbumsTableViewCell
            else { preconditionFailure("Could not load a LocalAlbumsTableViewCell!") }
            cell.configure(with: title, nberPhotos: nberPhotos, startDate: startDate, endDate: endDate, preferredContenSize: traitCollection.preferredContentSizeCategory, width: localAlbumsTableView.frame.width - 2 * TableViewUtilities.rowCornerRadius)
            cell.accessoryType = wantedAction == .setAutoUploadAlbum ? .none : .disclosureIndicator
            if aCollection.assetCollectionType == .smartAlbum,
               aCollection.assetCollectionSubtype == .smartAlbumUserLibrary {
                cell.accessibilityIdentifier = "Recent"
            }
            cell.isAccessibilityElement = true
            return cell
        }
        else {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LocalAlbumsNoDatesTableViewCell", for: indexPath) as? LocalAlbumsNoDatesTableViewCell
            else { preconditionFailure("Could not load a LocalAlbumsNoDatesTableViewCell!") }
            cell.configure(with: title, nberPhotos: nberPhotos)
            cell.accessoryType = wantedAction == .setAutoUploadAlbum ? .none : .disclosureIndicator
            if aCollection.assetCollectionType == .smartAlbum,
               aCollection.assetCollectionSubtype == .smartAlbumUserLibrary {
                cell.accessibilityIdentifier = "Recent"
            }
            cell.isAccessibilityElement = true
            return cell
        }
    }
}
