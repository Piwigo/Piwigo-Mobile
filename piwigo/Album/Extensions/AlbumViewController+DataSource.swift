//
//  AlbumViewController+DataSource.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

extension AlbumViewController: UICollectionViewDataSource
{
    func attributedComment() -> NSMutableAttributedString {
        let desc = NSMutableAttributedString(attributedString: albumData.comment)
        let wholeRange = NSRange(location: 0, length: desc.string.count)
        let style = NSMutableParagraphStyle()
        style.alignment = NSTextAlignment.center
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorHeader(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13, weight: .light),
            NSAttributedString.Key.paragraphStyle: style
        ]
        desc.addAttributes(attributes, range: wholeRange)
        return desc
    }
    
    func getImageCount() -> String {
        // Get total number of images
        var totalCount = Int64.zero
        if albumData.pwgID == 0 {
            // Root Album only contains albums  => calculate total number of images
            (albums.fetchedObjects ?? []).forEach({ album in
                totalCount += album.totalNbImages
            })
        } else {
            // Number of images in current album
            totalCount = albumData.nbImages
        }
        
        // Build footer content
        var legend = ""
        if totalCount == Int64.min {
            // Is loading…
            legend = NSLocalizedString("loadingHUD_label", comment:"Loading…")
        }
        else if totalCount == Int64.zero {
            // Not loading and no images
            if albumData.pwgID == Int64.zero {
                legend = NSLocalizedString("categoryMainEmtpy", comment: "No albums in your Piwigo yet.\rYou may pull down to refresh or re-login.")
            } else {
                legend = NSLocalizedString("noImages", comment:"No Images")
            }
        }
        else {
            // Display number of images…
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            if let number = numberFormatter.string(from: NSNumber(value: totalCount)) {
                let format:String = totalCount > 1 ? NSLocalizedString("severalImagesCount", comment:"%@ photos") : NSLocalizedString("singleImageCount", comment:"%@ photo")
                legend = String(format: format, number)
            }
            else {
                legend = String(format: NSLocalizedString("severalImagesCount", comment:"%@ photos"), "?")
            }
        }
        return legend
    }
    
    func updateNberOfImagesInFooter() {
        // Update number of images in footer
        DispatchQueue.main.async { [self] in
            // Determine index path
            var indexPath: IndexPath
            if categoryId == Int32.zero {
                // Number of images in footer of album collection
                indexPath = IndexPath(item: 0, section: 0)
            }
            else {
                // Number of images in fotter of image collection
                indexPath = IndexPath(item: 0, section: (images.sections?.count ?? 0))
            }
            // Update footer if needed
            if let footer = collectionView?.supplementaryView(forElementKind: UICollectionView.elementKindSectionFooter, at: indexPath) as? ImageFooterReusableView {
                footer.nberImagesLabel?.text = getImageCount()
            }
        }
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return categoryId == Int32.zero ? 1 : 1 + (images.sections?.count ?? 0)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0 /* Albums */:
            let objects = albums.fetchedObjects
            return objects?.count ?? 0
            
        default /* Images */:
            guard let sections = images.sections
            else { preconditionFailure("No sections in fetchedResultsController")}
            return sections[section - 1].numberOfObjects
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView
    {
        let emptyView = UICollectionReusableView(frame: CGRect.zero)
        switch indexPath.section {
        case 0 /* Albums */:
            switch kind {
            case UICollectionView.elementKindSectionHeader:
                guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "AlbumHeaderReusableView", for: indexPath) as? AlbumHeaderReusableView else { preconditionFailure("Could not load AlbumHeaderReusableView")}
                header.commentLabel?.attributedText = attributedComment()
                header.backgroundColor = UIColor.piwigoColorBackground().withAlphaComponent(0.75)
                return header
            case UICollectionView.elementKindSectionFooter:
                if categoryId == Int32.zero {
                    guard let footer = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "ImageFooterReusableView", for: indexPath) as? ImageFooterReusableView
                    else { preconditionFailure("Could not load ImageFooterReusableView")}
                    footer.nberImagesLabel?.textColor = UIColor.piwigoColorHeader()
                    footer.nberImagesLabel?.text = getImageCount()
                    return footer
                }
            default:
                break
            }
        default /* Images */:
            switch kind {
            case UICollectionView.elementKindSectionHeader:
                // Are images grouped by day, week or month?
                if dateSortTypes.contains(sortOption) == false { return emptyView }
                
                // Determine place names from first images
                let imageSection = indexPath.section - 1
                var imagesInSection: [Image] = []
                for item in 0..<min(collectionView.numberOfItems(inSection: indexPath.section), 20) {
                    let imageIndexPath = IndexPath(item: item, section: imageSection)
                    imagesInSection.append(images.object(at: imageIndexPath))
                }

                // Determine state of Select button
                let selectState = updateSelectButton(ofSection: indexPath.section)

                // Images are grouped by day, week or month
                if #available(iOS 14, *) {
                    // Grouping options accessible from menu ► Only display date and location
                    guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "ImageHeaderReusableView", for: indexPath) as? ImageHeaderReusableView
                    else { preconditionFailure("Could not load ImageHeaderReusableView") }
                    
                    header.config(with: imagesInSection, sortOption: sortOption, section: indexPath.section, selectState: selectState)
                    header.imageHeaderDelegate = self
                    return header
                }
                else {
                    // Display segmented controller in first section for selecting grouping option on iOS 12 - 13.x
                    if indexPath.section == 1 {
                        // Display segmented controller
                        guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "ImageOldHeaderReusableView", for: indexPath) as? ImageOldHeaderReusableView
                        else { preconditionFailure("Could not load ImageOldHeaderReusableView")}
                        
                        header.config(with: imagesInSection, sortOption: sortOption, group: AlbumVars.shared.defaultGroup,
                                      section: indexPath.section, selectState: selectState)
                        header.imageHeaderDelegate = self
                        return header
                    } else {
                        // Grouping options accessible from menu ► Only display date and location
                        guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "ImageHeaderReusableView", for: indexPath) as? ImageHeaderReusableView
                        else { preconditionFailure("Could not load ImageHeaderReusableView") }
                        
                        header.config(with: imagesInSection, sortOption: sortOption,
                                      section: indexPath.section, selectState: selectState)
                        header.imageHeaderDelegate = self
                        return header
                    }
                }
            case UICollectionView.elementKindSectionFooter:
                if indexPath.section == data.imageCount() {
                    guard let footer = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "ImageFooterReusableView", for: indexPath) as? ImageFooterReusableView
                    else { preconditionFailure("Could not load ImageFooterReusableView")}
                    footer.nberImagesLabel?.textColor = UIColor.piwigoColorHeader()
                    footer.nberImagesLabel?.text = getImageCount()
                    return footer
                }
            default:
                break
            }
        }
        return emptyView
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch indexPath.section {
        case 0 /* Albums (see XIB file) */:
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AlbumCollectionViewCell", for: indexPath) as? AlbumCollectionViewCell
            else { preconditionFailure("Could not load AlbumCollectionViewCell") }
            
            // Configure cell with album data
            let album = albums.object(at: indexPath)
            if album.isFault {
                // The album is not fired yet.
                album.willAccessValue(forKey: nil)
                album.didAccessValue(forKey: nil)
            }
            cell.albumData = album
            cell.pushAlbumDelegate = self
            cell.deleteAlbumDelegate = self
            
            // Disable category cells in Image selection mode
            if isSelect {
                cell.contentView.alpha = 0.5
                cell.isUserInteractionEnabled = false
            } else {
                cell.contentView.alpha = 1.0
                cell.isUserInteractionEnabled = true
            }
//            debugPrint("••> Adds album cell at \(indexPath.item)")
            return cell
            
        default /* Images */:
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCollectionViewCell", for: indexPath) as? ImageCollectionViewCell
            else { preconditionFailure("Could not load ImageCollectionViewCell") }
            
            // Add pan gesture recognition if needed
            if cell.gestureRecognizers == nil {
                let imageSeriesRocognizer = UIPanGestureRecognizer(target: self, action: #selector(touchedImages(_:)))
                imageSeriesRocognizer.minimumNumberOfTouches = 1
                imageSeriesRocognizer.maximumNumberOfTouches = 1
                imageSeriesRocognizer.cancelsTouchesInView = false
                imageSeriesRocognizer.delegate = self
                cell.addGestureRecognizer(imageSeriesRocognizer)
                cell.isUserInteractionEnabled = true
            }

            // Retrieve image data
            let imageIndexPath = IndexPath(item: indexPath.item, section: indexPath.section - 1)
            let image = images.object(at: imageIndexPath)

            // Is this cell selected?
            cell.isSelection = selectedImageIds.contains(image.pwgID)
            
            // pwg.users.favorites… methods available from Piwigo version 2.10
            if hasFavorites {
                cell.isFavorite = (image.albums ?? Set<Album>())
                    .contains(where: {$0.pwgID == pwgSmartAlbum.favorites.rawValue})
            }
            
            // The image being retrieved in a background task,
            // config() must be called after setting all other parameters
            cell.config(with: image, placeHolder: imagePlaceHolder, size: imageSize, sortOption: sortOption)
//            debugPrint("••> Adds image cell at \(indexPath.item): \(cell.bounds.size)")
            return cell
        }
    }
}
