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

// MARK: UICollectionViewDelegateFlowLayout Methods
extension AlbumViewController: UICollectionViewDelegateFlowLayout
{
    func getAlbumCellSize() -> CGSize {
        if AlbumVars.shared.displayAlbumDescriptions {
            let albumWidth = AlbumUtilities.albumWidth(forView: collectionView, maxWidth: 384.0)
//            debugPrint("••> getAlbumCellSize: \(albumWidth) x 156.5 points")
            return CGSize(width: albumWidth, height: 156.5)
        } else {
            let albumWidth = AlbumUtilities.albumWidth(forView: collectionView, maxWidth: 200.0)
            let albumHeight = albumWidth * 2 / 3 + 50
//            debugPrint("••> getAlbumCellSize: \(albumWidth) x \(albumHeight) points")
            return CGSize(width: albumWidth, height: albumHeight)
        }
    }
    
    func getImageCellSize() -> CGSize {
        let nbImages = AlbumVars.shared.thumbnailsPerRowInPortrait  // from Settings
        let size = AlbumUtilities.imageSize(forView: collectionView, imagesPerRowInPortrait: nbImages)
//        debugPrint("••> getImageCellSize: \(size) x \(size) points")
        return CGSize(width: size, height: size)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        if (elementKind == UICollectionView.elementKindSectionHeader) ||
            (elementKind == UICollectionView.elementKindSectionFooter) {
            view.layer.zPosition = 0 // Below scroll indicator
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
            // Are images sorted by date?
            if let sortKey = images.fetchRequest.sortDescriptors?.first?.key,
               [#keyPath(Image.dateCreated), #keyPath(Image.datePosted)].contains(sortKey) == false {
                return CGSize.zero
            }
            
            // Images are sorted by date ► Presents menu or segmented controller
            if #available(iOS 14, *) {
                // Grouping options accessible from menu ► Display date and location (see XIB)
                return CGSize(width: collectionView.frame.size.width, height: 49)
            }
            else {
                // First section shows a segmented controller for selecting grouping option on iOS 12 - 13.x (see XIB)
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
            // Number of images shown in footer of root album
            if categoryId != Int32.zero {
                return CGSize.zero
            }
            
        default /* Images */:
            // Number of images shown at the bottom of the collection
            guard section == images.sections?.count ?? 0
            else { return CGSize.zero }
        }
        
        // Get number of images and status
        let footer = getImageCount()        
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
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets
    {
        switch section {
        case 0 /* Albums */:
            if AlbumVars.shared.displayAlbumDescriptions {
                return UIEdgeInsets.zero
            } else {
                return UIEdgeInsets(top: 0, left: AlbumUtilities.kAlbumMarginsSpacing,
                                    bottom: 0, right: AlbumUtilities.kAlbumMarginsSpacing)
            }
        default /* Images */:
            return UIEdgeInsets.zero
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        switch section {
        case 0 /* Albums */:
            if AlbumVars.shared.displayAlbumDescriptions {
                return 0.0
            } else {
                return AlbumUtilities.kAlbumCellVertSpacing
            }
        default /* Images */:
            return AlbumUtilities.imageCellVerticalSpacing(forCollectionType: .full)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        switch section {
        case 0 /* Albums */:
            if AlbumVars.shared.displayAlbumDescriptions {
                return AlbumUtilities.kAlbumOldCellSpacing
            } else {
                return AlbumUtilities.kAlbumCellSpacing
            }
        default /* Images */:
            return AlbumUtilities.imageCellHorizontalSpacing(forCollectionType: .full)
        }
    }
}
