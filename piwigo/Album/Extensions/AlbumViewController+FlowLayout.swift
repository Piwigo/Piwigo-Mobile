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
        let headerRect = desc.boundingRect(with: CGSize(width: collectionView.frame.size.width - 30.0,
                                                        height: CGFloat.greatestFiniteMagnitude),
                                           options: .usesLineFragmentOrigin, context: context)
        return CGSize(width: collectionView.frame.size.width - 30.0,
                      height: ceil(headerRect.size.height + 4.0))
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize
    {
        if #available(iOS 13.0, *) {
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
                
                // Images are sorted by date ► Presents menu or segmented controller
                let hasAlbumSection = self.diffableDataSource.snapshot().sectionIdentifiers.contains(pwgAlbumGroup.none.sectionKey)
                if #available(iOS 14, *) {
                    // Grouping options accessible from menu ► Display date and location (see XIB)
                    if section == 0, hasAlbumSection == false {
                        return CGSize(width: collectionView.frame.size.width,
                                      height: 49 + self.getAlbumDescriptionSize().height)
                    } else {
                        return CGSize(width: collectionView.frame.size.width, height: 49)
                    }
                }
                else {  // for iOS 12 - 13.x
                    // Display segmented controller in first section for selecting grouping option
                    if section == 0, hasAlbumSection == false {
                        return CGSize(width: collectionView.frame.size.width,
                                      height: 88 + self.getAlbumDescriptionSize().height)
                    } else {
                        return CGSize(width: collectionView.frame.size.width, height: 49)
                    }
                }
            }
        } else {
            // Fallback on earlier versions
            switch section {
            case 0 /* Section 0 — Album collection */:
                // Header height?
                let descriptionSize = self.getAlbumDescriptionSize()
                if descriptionSize.height == 0 {
                    return CGSize.zero
                } else {
                    return CGSize(width: collectionView.frame.size.width,
                                  height: 8 + self.getAlbumDescriptionSize().height)
                }
                
            default: /* Images */
                // Are images sorted by date?
                if let sortKey = images.fetchRequest.sortDescriptors?.first?.key,
                   [#keyPath(Image.dateCreated), #keyPath(Image.datePosted)].contains(sortKey) == false {
                    // Images not sorted by date
                    // First section shows the album description
                    if section == 1 {
                        return CGSize(width: collectionView.frame.size.width,
                                      height: 10 + self.getAlbumDescriptionSize().height)
                    } else {
                        return CGSize.zero
                    }
                }
                
                // Images are sorted by date ► Presents menu or segmented controller
                // First section shows a segmented controller for selecting grouping option on iOS 12 - 13.x (see XIB)
                if section == 1 {
                    return CGSize(width: collectionView.frame.size.width, height: 88)
                } else {
                    return CGSize(width: collectionView.frame.size.width, height: 49)
                }
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
//            debugPrint("••> getAlbumCellSize: \(albumWidth) x 156.5 points")
            return CGSize(width: albumWidth, height: 156.5)
        } else {
            let albumWidth = AlbumUtilities.albumWidth(forSafeAreaSize: safeAreaSize, maxCellWidth: CGFloat(200))
            let albumHeight = albumWidth * 2 / 3 + 50
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
        if #available(iOS 13.0, *) {
            guard let itemID = diffableDataSource.itemIdentifier(for: indexPath)
            else { return CGSize.zero }
            // Album or image?
            if let _ = try? self.mainContext.existingObject(with: itemID) as? Album {
                return getAlbumCellSize()
            } else {
                return getImageCellSize()
            }
        } else {
            // Fallback on earlier versions
            switch indexPath.section {
            case 0 /* Albums (see XIB file) */:
                return getAlbumCellSize()
            default /* Images */:
                return getImageCellSize()
            }
        }
    }
    
    
    // MARK: - Footers
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize
    {
        if #available(iOS 13.0, *) {
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
        } else {
            // Fallback on earlier versions
            switch section {
            case 0 /* Albums */:
                // Number of images shown in footer of root album
                // or a spacer between albums and images
                if categoryId != Int32.zero {
                    if collectionView.numberOfItems(inSection: 0) == 0 {
                        return  CGSize.zero
                    } else {
                        return CGSize(width: collectionView.frame.width, height: 8.0)
                    }
                }
                
            default /* Images */:
                // Number of images shown at the bottom of the collection
                guard categoryId != Int32.zero, section == images.sections?.count ?? 0
                else { return CGSize.zero }
            }
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
    
    
    // MARK: - Inset & Spacing for Sections
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets
    {
        if #available(iOS 13.0, *) {
            // Album or image?
            if let index = diffableDataSource.snapshot().indexOfSection(pwgAlbumGroup.none.sectionKey),
               index == section {       /* Album collection */
                if AlbumVars.shared.displayAlbumDescriptions {
                    return UIEdgeInsets.zero
                } else {
                    let margin = AlbumUtilities.kAlbumMarginsSpacing
                    return UIEdgeInsets(top: CGFloat.zero, left: margin,
                                        bottom: CGFloat.zero, right: margin)
                }
            } else {                    /* Image collection */
                return UIEdgeInsets.zero
            }
        } else {
            // Fallback on earlier versions
            switch section {
            case 0 /* Albums */:
                if AlbumVars.shared.displayAlbumDescriptions {
                    return UIEdgeInsets.zero
                } else {
                    return UIEdgeInsets(top: CGFloat.zero, left: AlbumUtilities.kAlbumMarginsSpacing,
                                        bottom: CGFloat.zero, right: AlbumUtilities.kAlbumMarginsSpacing)
                }
            default /* Images */:
                return UIEdgeInsets.zero
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        if #available(iOS 13.0, *) {
            // Album or image?
            if let index = diffableDataSource.snapshot().indexOfSection(pwgAlbumGroup.none.sectionKey),
               index == section {       /* Album collection */
                if AlbumVars.shared.displayAlbumDescriptions {
                    return 0.0
                } else {
                    return AlbumUtilities.kAlbumCellVertSpacing
                }
            } else {                    /* Image collection */
                return AlbumUtilities.imageCellVerticalSpacing(forCollectionType: .full)
            }
        } else {
            // Fallback on earlier versions
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
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        if #available(iOS 13.0, *) {
            // Album or image?
            if let index = diffableDataSource.snapshot().indexOfSection(pwgAlbumGroup.none.sectionKey),
               index == section {       /* Album collection */
                if AlbumVars.shared.displayAlbumDescriptions {
                    return AlbumUtilities.kAlbumOldCellSpacing
                } else {
                    return AlbumUtilities.kAlbumCellSpacing
                }
            } else {                    /* Image collection */
                return AlbumUtilities.imageCellHorizontalSpacing(forCollectionType: .full)
            }
        } else {
            // Fallback on earlier versions
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
}
