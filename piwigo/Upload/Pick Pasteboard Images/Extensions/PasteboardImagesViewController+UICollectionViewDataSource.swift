//
//  PasteboardImagesViewController+UICollectionViewDataSource.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/03/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import MobileCoreServices
import UIKit

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers        // Requires iOS 14
#endif

extension PasteboardImagesViewController: UICollectionViewDataSource
{
    // MARK: - Headers & Footers
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        // Header with place name
        if kind == UICollectionView.elementKindSectionHeader {
            // Pasteboard header
            guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "PasteboardImagesHeaderReusableView", for: indexPath) as? PasteboardImagesHeaderReusableView else {
                let view = UICollectionReusableView(frame: CGRect.zero)
                return view
            }
            
            // Configure the header
            updateSelectButton()
            header.configure(with: sectionState)
            header.headerDelegate = self
            return header
        }
        else if kind == UICollectionView.elementKindSectionFooter {
            // Footer with number of images
            guard let footer = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "LocalImagesFooterReusableView", for: indexPath) as? LocalImagesFooterReusableView else {
                let view = UICollectionReusableView(frame: CGRect.zero)
                return view
            }
            footer.configure(with: localImagesCollection.numberOfItems(inSection: indexPath.section))
            return footer
        }
        
        let view = UICollectionReusableView(frame: CGRect.zero)
        return view
    }
    
    
    // MARK: - Sections
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    
    // MARK: - Items i.e. Images
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // Number of items depends on image sort type and date order
        return pbObjects.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Create cell
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LocalImageCollectionViewCell", for: indexPath) as? LocalImageCollectionViewCell else {
            print("Error: collectionView.dequeueReusableCell does not return a LocalImageCollectionViewCell!")
            return LocalImageCollectionViewCell()
        }
        
        // Configure cell with image in pasteboard or stored in Uploads directory
        // (the content of the pasteboard may not last forever)
        let identifier = pbObjects[indexPath.item].identifier

        // Get thumbnail of image if available
        var image: UIImage! = imagePlaceholder
        if [.stored, .ready].contains(pbObjects[indexPath.row].state) {
            image = pbObjects[indexPath.row].image
            cell.md5sum = pbObjects[indexPath.row].md5Sum
        }
        else {
            var imageType = ""
            if #available(iOS 14.0, *) {
                imageType = UTType.image.identifier
            } else {
                // Fallback on earlier version
                imageType = kUTTypeImage as String
            }
            if let data = UIPasteboard.general.data(forPasteboardType: imageType,
                                                    inItemSet: IndexSet(integer: indexPath.row))?.first {
                image = UIImage(data: data) ?? imagePlaceholder
                cell.md5sum = ""
            }
        }

        // Configure cell
        let thumbnailSize = AlbumUtilities.imageSize(forView: self.localImagesCollection, imagesPerRowInPortrait: AlbumVars.shared.thumbnailsPerRowInPortrait, collectionType: .popup)
        cell.configure(with: image, identifier: identifier, thumbnailSize: CGFloat(thumbnailSize))
        
        // Add pan gesture recognition
        let imageSeriesRocognizer = UIPanGestureRecognizer(target: self, action: #selector(touchedImages(_:)))
        imageSeriesRocognizer.minimumNumberOfTouches = 1
        imageSeriesRocognizer.maximumNumberOfTouches = 1
        imageSeriesRocognizer.cancelsTouchesInView = false
        imageSeriesRocognizer.delegate = self
        cell.addGestureRecognizer(imageSeriesRocognizer)
        cell.isUserInteractionEnabled = true

        // Cell state
        let uploadState = getUploadStateOfImage(at: indexPath.item, for: cell)
        cell.update(selected: selectedImages[indexPath.item] != nil, state: uploadState)

        return cell
    }

    @objc func applyUploadProgress(_ notification: Notification) {
        if let visibleCells = localImagesCollection.visibleCells as? [LocalImageCollectionViewCell],
           let localIdentifier =  notification.userInfo?["localIdentifier"] as? String, !localIdentifier.isEmpty,
           let cell = visibleCells.first(where: {$0.localIdentifier == localIdentifier}),
           let progressFraction = notification.userInfo?["progressFraction"] as? Float {
            cell.setProgress(progressFraction, withAnimation: true)
        }
    }
}
