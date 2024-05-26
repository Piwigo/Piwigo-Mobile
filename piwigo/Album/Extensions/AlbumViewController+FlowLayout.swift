//
//  AlbumViewController+FlowLayout.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

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
        default: /* Images */
            // Are images grouped by day, week or month?
            let validSortTypes: [pwgImageSort] = [.datePostedAscending, .datePostedDescending,
                                                  .dateCreatedAscending, .dateCreatedDescending]
            if validSortTypes.contains(sortOption) == false {
                return CGSize.zero
            }
            
            // Images are grouped by day, week or month
            if #available(iOS 14, *) {
                // Grouping options accessible from menu ► Only display date and location (see XIB)
                return CGSize(width: collectionView.frame.size.width, height: 49)
            }
            else {
                // Segmented controller for selecting grouping option on iOS 12 - 13.x (see XIB)
                if section == 1 {
                    return CGSize(width: collectionView.frame.size.width, height: 88)
                } else {
                    return CGSize(width: collectionView.frame.size.width, height: 49)
                }
            }
        }
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
            // Footer only at the bottom of the collection
            if section != collectionView.numberOfSections - 1 {
                return CGSize.zero
            }
            
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
