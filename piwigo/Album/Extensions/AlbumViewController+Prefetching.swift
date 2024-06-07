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
        print("••> prefetchingItemsAt \(indexPaths.debugDescription)")
        let scale = self.traitCollection.displayScale
        for indexPath in indexPaths {
            switch indexPath.section {
            case 0 /* Albums (see XIB file) */:
                // Retrieve album data
                if indexPath.item >= albums.fetchedObjects?.count ?? 0 { return }
                let album = albums.object(at: indexPath)
                
                // Download image if needed
                PwgSession.shared.getImage(withID: album.thumbnailId, ofSize: thumbSize,
                                           atURL: album.thumbnailUrl as? URL,
                                           fromServer: album.user?.server?.uuid,
                                           placeHolder: albumPlaceHolder) { cachedImageURL in
                    let _ = ImageUtilities.downsample(imageAt: cachedImageURL, to: self.albumCellSize, scale: scale)
                } failure: { _ in }
            default /* Images */:
                // Retrieve image data
                let imageIndexPath = IndexPath(item: indexPath.item, section: indexPath.section - 1)
                if imageIndexPath.section >= (images.sections?.count ?? 0) { return }
                guard let sections = images.sections else { return }
                if imageIndexPath.item > sections[imageIndexPath.section].numberOfObjects { return }
                let imageData = images.object(at: imageIndexPath)

                // Download image if needed
                PwgSession.shared.getImage(withID: imageData.pwgID, ofSize: imageSize,
                                           atURL: ImageUtilities.getURL(imageData, ofMinSize: imageSize),
                                           fromServer: imageData.server?.uuid, fileSize: imageData.fileSize,
                                           placeHolder: imagePlaceHolder) { cachedImageURL in
                    let _ = ImageUtilities.downsample(imageAt: cachedImageURL, to: self.imageCellSize, scale: scale)
                } failure: { _ in }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        print("••> cancelPrefetchingForItemsAt \(indexPaths.debugDescription)")
        for indexPath in indexPaths {
            switch indexPath.section {
            case 0 /* Albums (see XIB file) */:
                // Retrieve album data
                if indexPath.item >= albums.fetchedObjects?.count ?? 0 { return }
                let album = albums.object(at: indexPath)

                // Cancel download if needed
                guard let imageURL = album.thumbnailUrl as? URL
                else { return }
                PwgSession.shared.cancelDownload(atURL: imageURL)
                
            default /* Images */:
                // Retrieve image data
                let imageIndexPath = IndexPath(item: indexPath.item, section: indexPath.section - 1)
                if imageIndexPath.section >= (images.sections?.count ?? 0) { return }
                guard let sections = images.sections else { return }
                if imageIndexPath.item >= sections[imageIndexPath.section].numberOfObjects { return }
                let image = images.object(at: imageIndexPath)
                
                // Cancel download if needed
                guard let imageURL = ImageUtilities.getURL(image, ofMinSize: imageSize)
                else { return }
                PwgSession.shared.cancelDownload(atURL: imageURL)
            }
        }
    }
}
