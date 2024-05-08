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
            let indexPath = IndexPath(item: 0, section: 1)
            if let footer = collectionView?.supplementaryView(forElementKind: UICollectionView.elementKindSectionFooter, at: indexPath) as? ImageFooterReusableView {
                footer.nberImagesLabel?.text = getImageCount()
            }
        }
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0 /* Albums */:
            let objects = albums.fetchedObjects
            return objects?.count ?? 0
            
        default /* Images */:
            let objects = images.fetchedObjects
            return objects?.count ?? 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView
    {
        switch indexPath.section {
        case 0 /* Albums */:
            if kind == UICollectionView.elementKindSectionHeader {
                guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "AlbumHeaderReusableView", for: indexPath) as? AlbumHeaderReusableView else { preconditionFailure("Could not load AlbumHeaderReusableView")}
                header.commentLabel?.attributedText = attributedComment()
                return header
            }
        default /* Images */:
            if kind == UICollectionView.elementKindSectionFooter {
                guard let footer = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "ImageFooterReusableView", for: indexPath) as? ImageFooterReusableView else { preconditionFailure("Could not load ImageFooterReusableView")}
                footer.nberImagesLabel?.textColor = UIColor.piwigoColorHeader()
                footer.nberImagesLabel?.text = getImageCount()
                return footer
            }
        }
        let view = UICollectionReusableView(frame: CGRect.zero)
        return view
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
            let imageIndexPath = IndexPath(item: indexPath.item, section: 0)
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
            cell.config(with: image, placeHolder: imagePlaceHolder, size: imageSize)
//            debugPrint("••> Adds image cell at \(indexPath.item): \(cell.bounds.size)")
            return cell
        }
    }
    
//    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
//        switch indexPath.section {
//        case 0 /* Albums (see XIB file) */:
//            // Retrieve album data
//            guard let cell = cell as? AlbumCollectionViewCell,
//                  let imageURL = cell.albumData?.thumbnailUrl as? URL
//            else { preconditionFailure("AlbumCollectionViewCell class expected") }
//
//            // Cancel download if needed
//            ImageSession.shared.cancelDownload(atURL: imageURL)
//            break
//        default /* Images */:
//            // Retrieve image data
//            guard let cell = cell as? ImageCollectionViewCell
//            else { preconditionFailure("ImageCollectionViewCell class expected") }
//            
//            // Cancel download if needed
//            guard let imageURL = ImageUtilities.getURL(cell.imageData, ofMinSize: imageSize)
//            else { return }
//            ImageSession.shared.cancelDownload(atURL: imageURL)
//        }
//    }
}
