//
//  LocalImagesViewController+FlowLayout.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 01/08/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

// MARK: UICollectionViewDelegateFlowLayout Methods
extension LocalImagesViewController: UICollectionViewDelegateFlowLayout
{
    func getImageCellSize() -> CGSize {
        // Get safe area width
        let safeAreaSize = AlbumUtilities.getSafeAreaSize(ofNavigationViewController: navigationController?.topViewController)
        
        // Calculate image cell width
        let nbImages = AlbumVars.shared.thumbnailsPerRowInPortrait  // from Settings
        let size = AlbumUtilities.imageSize(forSafeAreaSize: safeAreaSize, imagesPerRowInPortrait: nbImages, collectionType: .popup)
//        debugPrint("••> getImageCellSize: \(size) x \(size) points")
        return CGSize(width: size, height: size)
    }

    func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        if (elementKind == UICollectionView.elementKindSectionHeader) ||
            (elementKind == UICollectionView.elementKindSectionFooter) {
            view.layer.zPosition = 0 // Below scroll indicator
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return imageCellSize
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: CGFloat(10), left: CGFloat.zero, bottom: CGFloat(10), right: CGFloat.zero)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return CGFloat(AlbumUtilities.imageCellVerticalSpacing(forCollectionType: .popup))
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return CGFloat(AlbumUtilities.imageCellHorizontalSpacing(forCollectionType: .popup))
    }
}
