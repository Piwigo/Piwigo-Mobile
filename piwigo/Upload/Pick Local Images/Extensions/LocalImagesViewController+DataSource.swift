//
//  LocalImagesViewController+DataSource.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/03/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Photos
import UIKit
import PwgKit
import PwgCacheKit
import PwgUploadKit

// MARK: UICollectionViewDataSource Methods
extension LocalImagesViewController: UICollectionViewDataSource
{
    // MARK: - Headers & Footers
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        // Header with place name
        if kind == UICollectionView.elementKindSectionHeader {
            // Images sorted by month, week or day
            guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "LocalImagesHeaderReusableView", for: indexPath) as? LocalImagesHeaderReusableView else {
                let view = UICollectionReusableView(frame: CGRect.zero)
                return view
            }
            
            // Determine place names from first and last images
            var imagesInSection: [PHAsset] = []
            let nberOfImageInSection = collectionView.numberOfItems(inSection: indexPath.section)
            if nberOfImageInSection <= 20 {
                // Collect all images
                for item in 0..<nberOfImageInSection {
                    imagesInSection.append(asset(at: getImageIndex(for: IndexPath(item: item, section: indexPath.section))))
                }
            } else {
                // Collect first 10 images and last 10 images
                for item in Array(0..<10) + Array((nberOfImageInSection - 10)..<nberOfImageInSection) {
                    imagesInSection.append(asset(at: getImageIndex(for: IndexPath(item: item, section: indexPath.section))))
                }
            }
            
            let selectState = updateSelectButton(ofSection: indexPath.section)
            header.configure(with: imagesInSection, section: indexPath.section, selectState: selectState)
            header.headerDelegate = self
            return header
        }
        else if kind == UICollectionView.elementKindSectionFooter {
            // Footer with number of images
            guard let footer = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "LocalImagesFooterReusableView", for: indexPath) as? LocalImagesFooterReusableView else {
                let view = UICollectionReusableView(frame: CGRect.zero)
                return view
            }
            footer.configure(with: localImagesCollection.numberOfItems(inSection: indexPath.section))
            return footer
        }
        
        let view = UICollectionReusableView(frame: CGRect.zero)
        return view
    }
    
    
    // MARK: - Sections
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        // Number of sections depends on image sort type
        return layout.sectionCount
    }
    
    
    // MARK: - Items i.e. Images
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // Number of items depends on image sort type
        return layout.numberOfItems(inSection: section)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Create cell
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LocalImageCollectionViewCell", for: indexPath) as? LocalImageCollectionViewCell
        else { preconditionFailure("Error: collectionView.dequeueReusableCell does not return a LocalImageCollectionViewCell!") }
        
        // Get image asset and index which depends on image sort type and date order
        let index = getImageIndex(for: indexPath)
        let imageAsset = asset(at: index)

        // Configure cell with image asset
        let livePhotoOption = livePhotoOptionByIdentifier[imageAsset.localIdentifier]
                              ?? UploadVars.shared.uploadLivePhotoAs
        cell.configure(with: imageAsset, thumbnailSize: imageCellSize,
                       uploadLivePhotoAs: livePhotoOption)

        // Get upload state from cell data
        let uploadState = getUploadStateOfImage(at: index, for: cell)
        cell.update(selected: selection.contains(index), state: uploadState)

        return cell
    }

    @objc func applyUploadProgress(_ notification: Notification) {
        if let visibleCells = localImagesCollection.visibleCells as? [LocalImageCollectionViewCell],
           let fileKey =  notification.userInfo?["fileKey"] as? String, !fileKey.isEmpty ,
           let cell = visibleCells.first(where: {$0.localIdentifier == UploadProperties.assetIdentifier(from: fileKey)}),
           let progressFraction = notification.userInfo?["progressFraction"] as? Float {
            cell.setProgress(progressFraction, forFileKey: fileKey, withAnimation: true)
        }
    }
}


// MARK: UICollectionViewDataSourcePrefetching Methods
extension LocalImagesViewController: UICollectionViewDataSourcePrefetching
{
    /// Reads the assets of the cells about to appear in the background: a cold read of the fetch result loads
    /// 200 assets at once (4 to 12 ms), which the main thread should not wait for while scrolling.
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let indices = indexPaths.map { getImageIndex(for: $0) }
        let assets = PhotoLibraryAssets(fetchedImages)
        let cache = assetCache
        Task.detached(priority: .userInitiated) {
            for index in indices where index < assets.count {
                autoreleasepool {
                    if cache.object(forKey: index as NSNumber) == nil {
                        cache.setObject(assets.result.object(at: index), forKey: index as NSNumber)
                    }
                }
            }
        }
    }
}
