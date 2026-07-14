//
//  PasteboardImagesViewController+DataSource.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/03/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import MobileCoreServices
import UIKit
import UniformTypeIdentifiers
import PwgKit

// MARK: UICollectionViewDataSource Methods
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
            debugPrint("Error: collectionView.dequeueReusableCell does not return a LocalImageCollectionViewCell!")
            return LocalImageCollectionViewCell()
        }
        
        // Configure cell with the thumbnail prepared in the background
        // from the pasteboard data stored in the Uploads directory
        let identifier = pbObjects[indexPath.item].identifier

        // Configure cell
        let (image, md5sum) = getImageAndMd5sumOfPbObject(atIndex: indexPath.item)
        cell.configure(with: image, identifier: identifier)
        cell.md5sum = md5sum
        
        // Cell state
        let uploadState = getUploadStateOfImage(at: indexPath.item, for: cell)
        cell.update(selected: selectedImages[indexPath.item] != nil, state: uploadState)

        return cell
    }

    func getImageAndMd5sumOfPbObject(atIndex index: Int) -> (UIImage, String) {
        // Returns the thumbnail and MD5 checksum prepared in the background.
        // Objects not stored yet get a placeholder and an empty checksum:
        // the cell is refreshed as soon as the preparation completes.
        let pbObject = pbObjects[index]
        if [.stored, .ready].contains(pbObject.state) {
            return (pbObject.image, pbObject.md5Sum)
        }
        return (pwgImageType.image.placeHolder, "")
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
