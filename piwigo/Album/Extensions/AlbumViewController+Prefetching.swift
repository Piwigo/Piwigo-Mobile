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
//        debugPrint("••> prefetchingItemsAt \(indexPaths.debugDescription)")
        let scale = max(traitCollection.displayScale, 1.0)
        let albumCellSize = getAlbumCellSize()
        let albumThumbnailCellSize = CGSizeMake(albumCellSize.width * scale, albumCellSize.height * scale)
        let imageCellSize = getImageCellSize()
        let imageThumbnailCellSize = CGSizeMake(imageCellSize.width * scale, imageCellSize.height * scale)
        
        for indexPath in indexPaths {
            if #available(iOS 13.0, *) {
                if let objectID = self.diffableDataSource.itemIdentifier(for: indexPath) {
                    if let album = try? self.mainContext.existingObject(with: objectID) as? Album {
                        // Download image if needed
                        PwgSession.shared.getImage(withID: album.thumbnailId, ofSize: thumbSize,
                                                   atURL: album.thumbnailUrl as? URL,
                                                   fromServer: album.user?.server?.uuid,
                                                   placeHolder: albumPlaceHolder) { cachedImageURL in
                            let _ = ImageUtilities.downsample(imageAt: cachedImageURL, to: albumThumbnailCellSize)
                        } failure: { _ in }
                    } else if let image = try? self.mainContext.existingObject(with: objectID) as? Image {
                        // Download image if needed
                        PwgSession.shared.getImage(withID: image.pwgID, ofSize: imageSize,
                                                   atURL: ImageUtilities.getURL(image, ofMinSize: imageSize),
                                                   fromServer: image.server?.uuid, fileSize: image.fileSize,
                                                   placeHolder: imagePlaceHolder) { cachedImageURL in
                            let _ = ImageUtilities.downsample(imageAt: cachedImageURL, to: imageThumbnailCellSize)
                        } failure: { _ in }
                    }
                }
            } else {
                // Fallback on earlier versions
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
                        let _ = ImageUtilities.downsample(imageAt: cachedImageURL, to: albumThumbnailCellSize)
                    } failure: { _ in }
                default /* Images */:
                    // Retrieve image data
                    let imageIndexPath = IndexPath(item: indexPath.item, section: indexPath.section - 1)
                    guard let sections = images.sections,
                          imageIndexPath.section < sections.count,
                          imageIndexPath.item < sections[indexPath.section - 1].numberOfObjects
                    else { return }
                    let imageData = images.object(at: imageIndexPath)

                    // Download image if needed
                    PwgSession.shared.getImage(withID: imageData.pwgID, ofSize: imageSize,
                                               atURL: ImageUtilities.getURL(imageData, ofMinSize: imageSize),
                                               fromServer: imageData.server?.uuid, fileSize: imageData.fileSize,
                                               placeHolder: imagePlaceHolder) { cachedImageURL in
                        let _ = ImageUtilities.downsample(imageAt: cachedImageURL, to: imageThumbnailCellSize)
                    } failure: { _ in }
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
//        debugPrint("••> cancelPrefetchingForItemsAt \(indexPaths.debugDescription)")
        for indexPath in indexPaths {
            if #available(iOS 13.0, *) {
                if let objectID = self.diffableDataSource.itemIdentifier(for: indexPath) {
                    if let album = try? self.mainContext.existingObject(with: objectID) as? Album,
                       let imageURL = album.thumbnailUrl as? URL {
                        // Cancel download if needed
                        PwgSession.shared.cancelDownload(atURL: imageURL)
                    }
                    else if let image = try? self.mainContext.existingObject(with: objectID) as? Image,
                            let imageURL = ImageUtilities.getURL(image, ofMinSize: imageSize) {
                        // Cancel download if needed
                        PwgSession.shared.cancelDownload(atURL: imageURL)
                    }
                }
            } else {
                // Fallback on earlier versions
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
}
