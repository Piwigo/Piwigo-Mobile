//
//  AlbumViewController+FlowLayout.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

// MARK: - UICollectionViewDelegateFlowLayout
extension AlbumViewController: UICollectionViewDelegateFlowLayout
{
    func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        if (elementKind == UICollectionView.elementKindSectionHeader) ||
            (elementKind == UICollectionView.elementKindSectionFooter) {
            view.layer.zPosition = 0 // Below scroll indicator
            view.backgroundColor = UIColor.piwigoColorBackground().withAlphaComponent(0.75)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize
    {
        switch section {
        case 0 /* Section 0 — Album collection */:
            // Header height?
            guard !albumData.comment.string.isEmpty else {
                return CGSize.zero
            }
            let desc = attributedComment()
            let context = NSStringDrawingContext()
            context.minimumScaleFactor = 1.0
            let headerRect = desc.boundingRect(with: CGSize(width: collectionView.frame.size.width - 30.0,
                                                            height: CGFloat.greatestFiniteMagnitude),
                                               options: .usesLineFragmentOrigin, context: context)
            return CGSize(width: collectionView.frame.size.width - 30.0,
                          height: ceil(headerRect.size.height + 8.0))
        default:
              break
        }
        return CGSize.zero
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        switch indexPath.section {
        case 0 /* Albums (see XIB file) */:
            return albumCellSize
        default /* Images */:
            return imageCellSize
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize
    {
        switch section {
        case 0 /* Albums */:
            return CGSize.zero
        default /* Images */:
            // Get number of images and status
            let footer = getImageCount()
            if footer.isEmpty { return CGSize.zero }
            
            let attributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13, weight: .light)]
            let context = NSStringDrawingContext()
            context.minimumScaleFactor = 1.0
            let footerRect = footer.boundingRect(
                with: CGSize(width: collectionView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude),
                options: .usesLineFragmentOrigin,
                attributes: attributes, context: context)
            return CGSize(width: collectionView.frame.size.width - 30.0,
                          height: ceil(footerRect.size.height + 8.0))
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets
    {
        switch section {
        case 0 /* Albums */:
            return UIEdgeInsets.zero
        default /* Images */:
            return UIEdgeInsets.zero
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        switch section {
        case 0 /* Albums */:
            return 0.0
        default /* Images */:
            return AlbumUtilities.imageCellVerticalSpacing(forCollectionType: .full)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        switch section {
        case 0 /* Albums */:
            return AlbumUtilities.kAlbumCellSpacing
        default /* Images */:
            return AlbumUtilities.imageCellHorizontalSpacing(forCollectionType: .full)
        }
    }
}
