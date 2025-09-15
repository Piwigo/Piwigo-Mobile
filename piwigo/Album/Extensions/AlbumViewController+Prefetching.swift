//
//  AlbumViewController+Prefetching.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 08/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

// MARK: - UICollectionViewDataSourcePrefetching
extension AlbumViewController: UICollectionViewDataSourcePrefetching
{
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        // Download images in advance whenever necessary
//        debugPrint("••> prefetchingItemsAt \(indexPaths.debugDescription)")
        
        for indexPath in indexPaths {
            if let objectID = self.diffableDataSource.itemIdentifier(for: indexPath) {
                if let album = try? self.mainContext.existingObject(with: objectID) as? Album {
                    // Download image if needed
                    PwgSession.shared.getImage(withID: album.thumbnailId, ofSize: thumbSize, type: .album,
                                               atURL: album.thumbnailUrl as? URL,
                                               fromServer: album.user?.server?.uuid) { _ in
                    } failure: { _ in }
                } else if let image = try? self.mainContext.existingObject(with: objectID) as? Image {
                    // Download image if needed
                    PwgSession.shared.getImage(withID: image.pwgID, ofSize: imageSize, type: .image,
                                               atURL: ImageUtilities.getPiwigoURL(image, ofMinSize: imageSize),
                                               fromServer: image.server?.uuid, fileSize: image.fileSize) { _ in
                    } failure: { _ in }
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        // Pause image downloads
//        debugPrint("••> cancelPrefetchingForItemsAt \(indexPaths.debugDescription)")
        for indexPath in indexPaths {
            if let objectID = self.diffableDataSource.itemIdentifier(for: indexPath) {
                if let album = try? self.mainContext.existingObject(with: objectID) as? Album,
                   let imageURL = album.thumbnailUrl as? URL {
                    // Pause download if needed
                    PwgSession.shared.pauseDownload(atURL: imageURL)
                }
                else if let image = try? self.mainContext.existingObject(with: objectID) as? Image,
                        let imageURL = ImageUtilities.getPiwigoURL(image, ofMinSize: imageSize) {
                    // Pause download if needed
                    PwgSession.shared.pauseDownload(atURL: imageURL)
                }
            }
        }
    }
}
