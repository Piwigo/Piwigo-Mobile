//
//  LocalAlbumsViewController+Delegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/09/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import Photos

// MARK: - UITableViewDelegate Methods
extension LocalAlbumsViewController: UITableViewDelegate {
    
    // MARK: - UITableView - Headers
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // Get title of section
        let albumType = albumTypeFor(section: section)
        let title = LocalAlbumsProvider.shared.titleForFooterInSectionOf(albumType: albumType)
        return TableViewUtilities.heightOfHeader(withTitle: title,
                                                        width: tableView.frame.size.width)
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // Get title of section
        let albumType = albumTypeFor(section: section)
        let title = LocalAlbumsProvider.shared.titleForHeaderInSectionOf(albumType: albumType)
        return TableViewUtilities.viewOfHeader(withTitle: title)
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        // First section added for pasteboard?
        if hasImagesInPasteboard && (section == 0) { return }
        view.layer.zPosition = 0
    }
    
    
    // MARK: - UITableView - Rows    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        var assetCollections = [PHAssetCollection]()
        let albumType = albumTypeFor(section: indexPath.section)
        let isLimited = hasLimitedNberOfAlbums[albumType]!
        switch albumType {
        case .pasteboard:
            let pasteboardImagesSB = UIStoryboard(name: "PasteboardImagesViewController", bundle: nil)
            guard let pasteboardImagesVC = pasteboardImagesSB.instantiateViewController(withIdentifier: "PasteboardImagesViewController") as? PasteboardImagesViewController else { return }
            pasteboardImagesVC.categoryId = categoryId
            pasteboardImagesVC.categoryCurrentCounter = categoryCurrentCounter
            pasteboardImagesVC.albumDelegate = albumDelegate
            pasteboardImagesVC.user = user
            navigationController?.pushViewController(pasteboardImagesVC, animated: true)
            return
        case .localAlbums:
            assetCollections = LocalAlbumsProvider.shared.localAlbums
        case .eventsAlbums:
            assetCollections = LocalAlbumsProvider.shared.eventsAlbums
        case .syncedAlbums:
            assetCollections = LocalAlbumsProvider.shared.syncedAlbums
        case .facesAlbums:
            assetCollections = LocalAlbumsProvider.shared.facesAlbums
        case .sharedAlbums:
            assetCollections = LocalAlbumsProvider.shared.sharedAlbums
        case .mediaTypes:
            assetCollections = LocalAlbumsProvider.shared.mediaTypes
        case .otherAlbums:
            assetCollections = LocalAlbumsProvider.shared.otherAlbums
        }
        
        // Did tap "expand" button at the bottom of section —> release remaining albums
        if isLimited && indexPath.row == maxNberOfAlbumsInSection {
            // Release album list
            hasLimitedNberOfAlbums[albumType] = false
            // Add remaining albums
            let indexPaths: [IndexPath] = Array(maxNberOfAlbumsInSection+1..<assetCollections.count)
                                                .map { IndexPath(row: $0, section: indexPath.section)}
            tableView.insertRows(at: indexPaths, with: .automatic)
            // Replace button
            tableView.reloadRows(at: [indexPath], with: .automatic)
            return
        }
        
        // Case of an album
        let albumID = assetCollections[indexPath.row].localIdentifier
        let albumName = assetCollections[indexPath.row].localizedTitle ?? NSLocalizedString("categoryUpload_LocalAlbums", comment: "Local Albums")
        if wantedAction == .setAutoUploadAlbum {
            // Return the selected album ID
            delegate?.didSelectPhotoAlbum(withId: albumID)
            navigationController?.popViewController(animated: true)
        } else {
            // Presents local images of the selected album
            let localImagesSB = UIStoryboard(name: "LocalImagesViewController", bundle: nil)
            guard let localImagesVC = localImagesSB.instantiateViewController(withIdentifier: "LocalImagesViewController") as? LocalImagesViewController
            else { return }
            localImagesVC.categoryId = categoryId
            localImagesVC.categoryCurrentCounter = categoryCurrentCounter
            localImagesVC.albumDelegate = albumDelegate
            localImagesVC.imageCollectionId = albumID
            localImagesVC.imageCollectionName = albumName
            localImagesVC.user = user
            navigationController?.pushViewController(localImagesVC, animated: true)
        }
    }

    
    // MARK: - UITableView - Footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        // Get footer of section
        let albumType = albumTypeFor(section: section)
        let footer = LocalAlbumsProvider.shared.titleForFooterInSectionOf(albumType: albumType)
        return TableViewUtilities.heightOfFooter(withText: footer,
                                                        width: tableView.frame.width)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        // Get footer of section
        let albumType = albumTypeFor(section: section)
        let footer = LocalAlbumsProvider.shared.titleForFooterInSectionOf(albumType: albumType)
        return TableViewUtilities.viewOfFooter(withText: footer, alignment: .center)
    }
}
