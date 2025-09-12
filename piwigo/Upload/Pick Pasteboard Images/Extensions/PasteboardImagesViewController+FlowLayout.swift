//
//  PasteboardImagesViewController+FlowLayout.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 05/08/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

// MARK: UICollectionViewDelegateFlowLayout Methods
extension PasteboardImagesViewController: UICollectionViewDelegateFlowLayout
{
    // MARK: - Headers
    func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        if (elementKind == UICollectionView.elementKindSectionHeader) || (elementKind == UICollectionView.elementKindSectionFooter) {
            view.layer.zPosition = 0 // Below scroll indicator
        }
    }

    // MARK: - Cells
    func getImageCellSize() -> CGSize {
        // Get safe area width
        let safeAreaSize = AlbumUtilities.getSafeAreaSize(ofNavigationViewController: navigationController?.topViewController)
        
        let nbImages = AlbumVars.shared.thumbnailsPerRowInPortrait  // from Settings
        let size = AlbumUtilities.imageSize(forSafeAreaSize: safeAreaSize, imagesPerRowInPortrait: nbImages, collectionType: .popup)
//        debugPrint("••> getImageCellSize: \(size) x \(size) points")
        return CGSize(width: size, height: size)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return imageCellSize
    }


    // MARK: - Inset & Spacing for Sections
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return CGFloat(AlbumUtilities.imageCellVerticalSpacing(forCollectionType: .popup))
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return CGFloat(AlbumUtilities.imageCellHorizontalSpacing(forCollectionType: .popup))
    }
}
