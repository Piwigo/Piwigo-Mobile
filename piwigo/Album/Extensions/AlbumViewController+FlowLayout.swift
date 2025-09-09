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
    // MARK: - Header & Footer
    func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        if (elementKind == UICollectionView.elementKindSectionHeader) ||
            (elementKind == UICollectionView.elementKindSectionFooter) {
            view.layer.zPosition = 0    // Below Scroll Indicator
        }
    }
    
    
    // MARK: - Headers
    func getAlbumDescriptionSize() -> CGSize {
        guard !albumData.comment.string.isEmpty
        else { return CGSize.zero }
        
        let desc = attributedComment()
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let maxWidth = collectionView.frame.width - 30.0 - 2 * AlbumUtilities.kAlbumMarginsSpacing
        let headerRect = desc.boundingRect(with: CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude),
                                           options: .usesLineFragmentOrigin, context: context)
        return CGSize(width: maxWidth + 4.0, height: ceil(headerRect.size.height + 4.0))
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize
    {
        // Album or image?
        if let index = diffableDataSource.snapshot().indexOfSection(pwgAlbumGroup.none.sectionKey),
           index == section {       /* Album collection */
            // Header height?
            let descriptionSize = self.getAlbumDescriptionSize()
            if descriptionSize.height == 0 {
                return CGSize.zero
            } else {
                return CGSize(width: collectionView.frame.size.width,
                              height: 8 + self.getAlbumDescriptionSize().height)
            }
        }
        else {                    /* Image collection */
            // Are images sorted by date?
            if let sortKey = images.fetchRequest.sortDescriptors?.first?.key,
               [#keyPath(Image.dateCreated), #keyPath(Image.datePosted)].contains(sortKey) == false {
                // Images not sorted by date
                // First section shows the album description
                if section == 0 {
                    let descriptionSize = self.getAlbumDescriptionSize()
                    if descriptionSize.height == 0 {
                        return CGSize.zero
                    } else {
                        return CGSize(width: collectionView.frame.size.width,
                                      height: 10 + self.getAlbumDescriptionSize().height)
                    }
                } else {
                    return CGSize.zero
                }
            }
            
            // Images are sorted by date ► Presents menu
            let hasAlbumSection = self.diffableDataSource.snapshot().sectionIdentifiers.contains(pwgAlbumGroup.none.sectionKey)
            if section == 0, hasAlbumSection == false {
                return CGSize(width: collectionView.frame.size.width,
                              height: imageHeaderHeight + self.getAlbumDescriptionSize().height)
            } else {
                return CGSize(width: collectionView.frame.size.width, height: imageHeaderHeight)
            }
        }
    }
    
    
    // MARK: - Album & Image Cells
    func getAlbumCellSize() -> CGSize {
        // Get safe area width
        let safeAreaSize = AlbumUtilities.getSafeAreaSize(ofNavigationViewController: navigationController?.topViewController)
        
        // Calculate album cell size
        if AlbumVars.shared.displayAlbumDescriptions {
            let albumWidth = AlbumUtilities.albumWidth(forSafeAreaSize: safeAreaSize, maxCellWidth: CGFloat(384))
//            debugPrint("••> getAlbumCellSize: \(albumWidth) x \(oldAlbumHeight) points")
            return CGSize(width: albumWidth, height: oldAlbumHeight)
        } else {
            let albumWidth = AlbumUtilities.albumWidth(forSafeAreaSize: safeAreaSize, maxCellWidth: albumMaxWidth)
            let albumHeight = albumWidth * 2 / 3 + albumLabelsHeight
//            debugPrint("••> getAlbumCellSize: \(albumWidth) x \(albumHeight) points")
            return CGSize(width: albumWidth, height: albumHeight)
        }
    }
    
    func getImageCellSize() -> CGSize {
        // Get safe area width
        let safeAreaSize = AlbumUtilities.getSafeAreaSize(ofNavigationViewController: navigationController?.topViewController)
        
        // Calculate image cell size
        let nbImages = AlbumVars.shared.thumbnailsPerRowInPortrait  // from Settings
        let size = AlbumUtilities.imageSize(forSafeAreaSize: safeAreaSize, imagesPerRowInPortrait: nbImages)
//        debugPrint("••> getImageCellSize: \(size) x \(size) points")
        return CGSize(width: size, height: size)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        guard let itemID = diffableDataSource.itemIdentifier(for: indexPath)
        else { return CGSize.zero }
        // Album or image?
        if let _ = try? self.mainContext.existingObject(with: itemID) as? Album {
            return getAlbumCellSize()
        } else {
            return getImageCellSize()
        }
    }
    
    
    // MARK: - Footers
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize
    {
        let nberOfSections = diffableDataSource.numberOfSections(in: collectionView)
        // Album or image?
        if let index = diffableDataSource.snapshot().indexOfSection(pwgAlbumGroup.none.sectionKey),
           index == section {
            // Album collection
            // Show number of images shown in footer of root album and albums not containing photos
            if categoryId != Int32.zero, nberOfSections > 1 {
                return CGSize(width: collectionView.frame.width, height: 8.0)
            }
        } else {
            // Image collection
            // Number of images shown in footer of last section of images
            guard categoryId != Int32.zero, section == nberOfSections - 1, albumData.nbImages > 0
            else { return CGSize.zero }
        }
        
        // Get number of images and status
        let footer = getImageCount()
        let attributes = [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .footnote)]
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let maxWidth = collectionView.frame.width - 30.0 - 2 * AlbumUtilities.kAlbumMarginsSpacing
        let footerRect = footer.boundingRect(
            with: CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: attributes, context: context)
        return CGSize(width: maxWidth + 4.0, height: ceil(footerRect.size.height + 8.0))
    }
    
    
    // MARK: - Inset & Spacing for Sections
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets
    {
        // Album or image?
        if let index = diffableDataSource.snapshot().indexOfSection(pwgAlbumGroup.none.sectionKey),
           index == section {
            // Album collection
            let margin = AlbumUtilities.kAlbumMarginsSpacing
            return UIEdgeInsets(top: CGFloat.zero, left: margin,
                                bottom: CGFloat.zero, right: margin)
        }
        else {
            // Image collection
            return UIEdgeInsets.zero
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        // Album or image?
        if let index = diffableDataSource.snapshot().indexOfSection(pwgAlbumGroup.none.sectionKey),
           index == section {
            // Album collection
            return AlbumUtilities.kAlbumCellVertSpacing
        }
        else {
            // Image collection
            return AlbumUtilities.imageCellVerticalSpacing(forCollectionType: .full)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        // Album or image?
        if let index = diffableDataSource.snapshot().indexOfSection(pwgAlbumGroup.none.sectionKey),
           index == section {
            // Album collection
            return AlbumUtilities.kAlbumCellSpacing
        }
        else {
            // Image collection
            return AlbumUtilities.imageCellHorizontalSpacing(forCollectionType: .full)
        }
    }
}
