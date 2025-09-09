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

// MARK: UICollectionView - Diffable Data Source
extension AlbumViewController
{
    func configDataSource() -> DataSource {
        // Cell provider
        let dataSource = DataSource(collectionView: collectionView) { [self] collectionView, indexPath, objectID in
            // Is this item an album or an image?
            if let album = try? self.mainContext.existingObject(with: objectID) as? Album {
                // Configure album cell
                if AlbumVars.shared.displayAlbumDescriptions {
                    // Dequeue reusable cell with album description
                    guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AlbumCollectionViewCellOld", for: indexPath) as? AlbumCollectionViewCellOld
                    else { preconditionFailure("Could not load AlbumCollectionViewCellOld") }
                    
                    // Configure cell with album data
                    cell.albumData = album
                    cell.pushAlbumDelegate = self
                    
                    // Disable album cells in Image selection mode
                    cell.contentView.alpha = self.inSelectionMode ? 0.5 : 1.0
                    cell.isUserInteractionEnabled = !self.inSelectionMode
                    return cell
                }
                else {
                    // Dequeue reusable cell w/o album description
                    guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AlbumCollectionViewCell", for: indexPath) as? AlbumCollectionViewCell
                    else { preconditionFailure("Could not load AlbumCollectionViewCell") }
                    
                    // Configure cell with album data
                    cell.config(withAlbumData: album)
                    
                    // Disable album cells in Image selection mode
                    cell.contentView.alpha = self.inSelectionMode ? 0.5 : 1.0
                    cell.isUserInteractionEnabled = !self.inSelectionMode
                    return cell
                }
            }
            else if let image = try? self.mainContext.existingObject(with: objectID) as? Image {
                // Configure image cell
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCollectionViewCell", for: indexPath) as? ImageCollectionViewCell
                else { preconditionFailure("Could not load ImageCollectionViewCell") }
                
                // Add pan gesture recognition if needed
                if cell.gestureRecognizers == nil {
                    let imageSeriesRocognizer = UIPanGestureRecognizer(target: self, action: #selector(self.touchedImages(_:)))
                    imageSeriesRocognizer.minimumNumberOfTouches = 1
                    imageSeriesRocognizer.maximumNumberOfTouches = 1
                    imageSeriesRocognizer.cancelsTouchesInView = false
                    imageSeriesRocognizer.delegate = self
                    cell.addGestureRecognizer(imageSeriesRocognizer)
                    cell.isUserInteractionEnabled = true
                }
                
                // Is this cell selected?
                cell.isSelection = self.selectedImageIDs.contains(image.pwgID)
                
                // pwg.users.favorites… methods available from Piwigo version 2.10
                if self.hasFavorites {
                    cell.isFavorite = (image.albums ?? Set<Album>())
                        .contains(where: {$0.pwgID == pwgSmartAlbum.favorites.rawValue})
                }
                
                // The image being retrieved in a background task,
                // config() must be called after setting all other parameters
                cell.config(withImageData: image, size: self.imageSize, sortOption: self.sortOption)
                //                debugPrint("••> Adds image cell at \(indexPath.item): \(cell.bounds.size)")
                return cell
            } else {
                preconditionFailure("Item of uknown type!")
            }
        }
        
        // Header / footer provider
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            let emptyView = UICollectionReusableView(frame: CGRect.zero)
            // Album or image?
            if let index = self.diffableDataSource.snapshot().indexOfSection(pwgAlbumGroup.none.sectionKey),
               index == indexPath.section {       /* Album collection */
                switch kind {
                case UICollectionView.elementKindSectionHeader:
                    guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "AlbumHeaderReusableView", for: indexPath) as? AlbumHeaderReusableView else { preconditionFailure("Could not load AlbumHeaderReusableView")}
                    header.config(withDescription: self.attributedComment(), size: self.getAlbumDescriptionSize())
                    return header
                case UICollectionView.elementKindSectionFooter:
                    guard let footer = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "ImageFooterReusableView", for: indexPath) as? ImageFooterReusableView
                    else { preconditionFailure("Could not load ImageFooterReusableView")}
                    if self.categoryId == Int64.zero {
                        footer.nberImagesLabel?.textColor = PwgColor.header
                        footer.nberImagesLabel?.text = self.getImageCount()
                    } else {
                        footer.nberImagesLabel?.text = " "
                    }
                    return footer
                default:
                    break
                }
            } else {                    /* Image collection */
                switch kind {
                case UICollectionView.elementKindSectionHeader:
                    // Retrieve up to 20 images in that section
                    let imagesInSection = self.getImagesInSection(at: indexPath)
                    
                    // Determine state of Select button
                    let selectState = self.updateSelectButton(ofSection: indexPath.section)
                    
                    // Images are grouped by day, week or month ► Only display date and location
                    let hasAlbumSection = self.diffableDataSource.snapshot().sectionIdentifiers.contains(pwgAlbumGroup.none.sectionKey)
                    guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "ImageHeaderReusableView", for: indexPath) as? ImageHeaderReusableView,
                          let sortKey = self.images.fetchRequest.sortDescriptors?.first?.key
                    else { preconditionFailure("Could not load ImageHeaderReusableView") }
                    
                    if indexPath.section == 0, hasAlbumSection == false {
                        header.config(with: imagesInSection, sortKey: sortKey, section: indexPath.section, selectState: selectState,
                                      album: self.attributedComment(), size: self.getAlbumDescriptionSize())
                    } else {
                        header.config(with: imagesInSection, sortKey: sortKey, section: indexPath.section, selectState: selectState)
                    }
                    header.imageHeaderDelegate = self
                    return header
                case UICollectionView.elementKindSectionFooter:
                    guard let footer = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "ImageFooterReusableView", for: indexPath) as? ImageFooterReusableView
                    else { preconditionFailure("Could not load ImageFooterReusableView")}
                    footer.nberImagesLabel?.textColor = PwgColor.header
                    footer.nberImagesLabel?.text = self.getImageCount()
                    return footer
                default:
                    break
                }
            }
            return emptyView
        }
        return dataSource
    }
    
    
    // MARK: - Headers
    func attributedComment() -> NSAttributedString {
        if albumData.commentHTML.string.isEmpty {
            let desc = NSMutableAttributedString(attributedString: albumData.comment)
            let wholeRange = NSRange(location: 0, length: albumData.comment.string.count)
            let style = NSMutableParagraphStyle()
            style.alignment = NSTextAlignment.center
            let attributes = [
                NSAttributedString.Key.foregroundColor: PwgColor.header,
                NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .subheadline),
                NSAttributedString.Key.paragraphStyle: style
            ]
            desc.addAttributes(attributes, range: wholeRange)
            return desc
        } else {
            return albumData.commentHTML
        }
    }
    
    func updateHeaders() {
        // Are images sorted by date?
        guard let sortKey = images.fetchRequest.sortDescriptors?.first?.key,
              [#keyPath(Image.dateCreated), #keyPath(Image.datePosted)].contains(sortKey),
              let collectionView = collectionView
        else { return }

        // Images are grouped by day, week or month: section header visible?
        let indexPaths = collectionView.indexPathsForVisibleSupplementaryElements(ofKind: UICollectionView.elementKindSectionHeader)
        indexPaths.forEach { indexPath in
            // Retrieve up to 20 images in that section
            let imagesInSection = getImagesInSection(at: indexPath)
            
            // Retrieve the appropriate section header
            let selectState = updateSelectButton(ofSection: indexPath.section)
            let hasAlbumSection = self.diffableDataSource.snapshot().sectionIdentifiers.contains(pwgAlbumGroup.none.sectionKey)
            if let header = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPath) as? ImageHeaderReusableView {
                if indexPath.section == 0, hasAlbumSection == false {
                    header.config(with: imagesInSection, sortKey: sortKey, section: indexPath.section, selectState: selectState,
                                  album: self.attributedComment(), size: self.getAlbumDescriptionSize())
                } else {
                    header.config(with: imagesInSection, sortKey: sortKey, section: indexPath.section, selectState: selectState)
                }
            }
        }
    }
    
    
    // MARK: - Footers
    private func getImagesInSection(at indexPath: IndexPath) -> [Image] {
        var imagesInSection = [Image]()
        let snapshot = self.diffableDataSource.snapshot()
        let sectionID = snapshot.sectionIdentifiers[indexPath.section]
        let sectionItems = snapshot.itemIdentifiers(inSection: sectionID)
        let nberOfImageInSection = sectionItems.count
        if nberOfImageInSection <= 20 {
            // Collect all images
            for index in 0..<min(nberOfImageInSection, 20) {
                autoreleasepool {
                    if let image = try? self.mainContext.existingObject(with: sectionItems[index]) as? Image {
                        imagesInSection.append(image)
                    }
                }
            }
        } else {
            // Collect first 10 images
            for index in 0..<10 {
                autoreleasepool {
                    if let image = try? self.mainContext.existingObject(with: sectionItems[index]) as? Image {
                        imagesInSection.append(image)
                    }
                }
            }
            // Collect last 10 images
            for index in (nberOfImageInSection - 10)..<nberOfImageInSection {
                autoreleasepool {
                    if let image = try? self.mainContext.existingObject(with: sectionItems[index]) as? Image {
                        imagesInSection.append(image)
                    }
                }
            }
        }
        return imagesInSection
    }

    func getImageCount() -> String {
        // Get total number of images
        var totalCount = Int64.zero
        if albumData.pwgID == 0 {
            // Root Album only contains albums  => calculate total number of images
            let snapshot = diffableDataSource.snapshot() as Snaphot
            if let albumSection = snapshot.sectionIdentifiers.first {
                snapshot.itemIdentifiers(inSection: albumSection).forEach { objectID in
                    guard let album = try? self.mainContext.existingObject(with: objectID) as? Album
                    else { return }
                    totalCount += album.totalNbImages
                }
            }
        } else {
            // Number of images in current album
            totalCount = albumData.nbImages
        }
        
        // Build footer content
        var legend = " "
        if totalCount == Int64.min {
            // Is loading…
            legend = NSLocalizedString("loadingHUD_label", comment:"Loading…")
        }
        else if totalCount == Int64.zero {
            // Not loading and no images
            if albumData.pwgID == Int64.zero {
                legend = NSLocalizedString("categoryMainEmtpy", comment: "No albums in your Piwigo yet. You may pull down to refresh or re-login.")
            } else {
                legend = NSLocalizedString("noImages", comment:"No Images")
            }
        }
        else {
            // Display number of images…
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            if let number = numberFormatter.string(from: NSNumber(value: totalCount)) {
                // Prepare legend
                let format:String = totalCount > 1
                    ? String(localized: "severalImagesCount", bundle: piwigoKit, comment: "%@ photos")
                    : String(localized: "singleImageCount", bundle: piwigoKit, comment: "%@ photo")
                legend = String(format: format, number)

                // Show/hide "No album in your Piwigo"
                let hasItems = (categoryId == pwgSmartAlbum.search.rawValue) || (totalCount != 0)
                noAlbumLabel.isHidden = hasItems
            }
            else {
                legend = String(format: String(localized: "severalImagesCount", bundle: piwigoKit, comment: "%@ photos"), "?")
            }
        }
        return legend
    }
    
    @MainActor
    func updateNberOfImagesInFooter() {
        // Determine index path
        var indexPath: IndexPath?
        if categoryId == Int32.zero {
            // Number of images in footer of album collection
            let snapShot = self.diffableDataSource.snapshot()
            if let section = snapShot.indexOfSection(pwgAlbumGroup.none.sectionKey) {
                indexPath = IndexPath(item: 0, section: section)
            }
        }
        else {
            // Number of images in footer of image collection
            let snapShot = self.diffableDataSource.snapshot()
            if let sectionID = snapShot.sectionIdentifiers.last,
               let section = snapShot.indexOfSection(sectionID) {
                indexPath = IndexPath(item: 0, section: section)
            }
        }
        
        // Update footer if needed
        guard let indexPath = indexPath else { return }
        if let footer = collectionView?.supplementaryView(forElementKind: UICollectionView.elementKindSectionFooter, at: indexPath) as? ImageFooterReusableView {
            footer.nberImagesLabel?.text = getImageCount()
        }
    }
}
