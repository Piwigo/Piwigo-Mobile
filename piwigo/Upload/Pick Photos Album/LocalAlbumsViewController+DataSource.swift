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
        count += LocalAlbumsProvider.shared.localAlbums.isEmpty ? 0 : 1
        count += LocalAlbumsProvider.shared.eventsAlbums.isEmpty ? 0 : 1
        count += LocalAlbumsProvider.shared.syncedAlbums.isEmpty ? 0 : 1
        count += LocalAlbumsProvider.shared.facesAlbums.isEmpty ? 0 : 1
        count += LocalAlbumsProvider.shared.sharedAlbums.isEmpty ? 0 : 1
        count += LocalAlbumsProvider.shared.mediaTypes.isEmpty ? 0 : 1
        count += LocalAlbumsProvider.shared.otherAlbums.isEmpty ? 0 : 1
        
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
        counter += LocalAlbumsProvider.shared.localAlbums.isEmpty ? 0 : 1
        if activeSection == counter { return .localAlbums }
        counter += LocalAlbumsProvider.shared.eventsAlbums.isEmpty ? 0 : 1
        if activeSection == counter { return .eventsAlbums }
        counter += LocalAlbumsProvider.shared.syncedAlbums.isEmpty ? 0 : 1
        if activeSection == counter { return .syncedAlbums }
        counter += LocalAlbumsProvider.shared.facesAlbums.isEmpty ? 0 : 1
        if activeSection == counter { return .facesAlbums }
        counter += LocalAlbumsProvider.shared.sharedAlbums.isEmpty ? 0 : 1
        if activeSection == counter { return .sharedAlbums }
        counter += LocalAlbumsProvider.shared.mediaTypes.isEmpty ? 0 : 1
        if activeSection == counter { return .mediaTypes }
        counter += LocalAlbumsProvider.shared.otherAlbums.isEmpty ? 0 : 1
        return .otherAlbums
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let albumType = albumTypeFor(section: section)
        var nberOfAlbums = 0
        switch albumType {
        case .pasteboard:
            return 1
        case .localAlbums:
            nberOfAlbums = LocalAlbumsProvider.shared.localAlbums.count
        case .eventsAlbums:
            nberOfAlbums = LocalAlbumsProvider.shared.eventsAlbums.count
        case .syncedAlbums:
            nberOfAlbums = LocalAlbumsProvider.shared.syncedAlbums.count
        case .facesAlbums:
            nberOfAlbums = LocalAlbumsProvider.shared.facesAlbums.count
        case .sharedAlbums:
            nberOfAlbums = LocalAlbumsProvider.shared.sharedAlbums.count
        case .mediaTypes:
            nberOfAlbums = LocalAlbumsProvider.shared.mediaTypes.count
        case .otherAlbums:
            nberOfAlbums = LocalAlbumsProvider.shared.otherAlbums.count
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
                assetCollection = LocalAlbumsProvider.shared.localAlbums[indexPath.row]
            }
        case .eventsAlbums:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = LocalAlbumsProvider.shared.eventsAlbums[indexPath.row]
            }
        case .syncedAlbums:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = LocalAlbumsProvider.shared.syncedAlbums[indexPath.row]
            }
        case .facesAlbums:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = LocalAlbumsProvider.shared.facesAlbums[indexPath.row]
            }
        case .sharedAlbums:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = LocalAlbumsProvider.shared.sharedAlbums[indexPath.row]
            }
        case .mediaTypes:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = LocalAlbumsProvider.shared.mediaTypes[indexPath.row]
            }
        case .otherAlbums:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = LocalAlbumsProvider.shared.otherAlbums[indexPath.row]
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
        let title = aCollection.localizedTitle ?? "—> ? <——"
        let nberPhotos = Int64(aCollection.estimatedAssetCount)

        if let startDate = aCollection.startDate, let endDate = aCollection.endDate {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LocalAlbumsTableViewCell", for: indexPath) as? LocalAlbumsTableViewCell
            else { preconditionFailure("Could not load a LocalAlbumsTableViewCell!") }
            cell.configure(with: title, nberPhotos: nberPhotos, startDate: startDate, endDate: endDate)
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
