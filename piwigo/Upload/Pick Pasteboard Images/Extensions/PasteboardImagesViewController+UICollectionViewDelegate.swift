//
//  PasteboardImagesViewController+UICollectionViewDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/03/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

extension PasteboardImagesViewController: UICollectionViewDelegate
{
    // MARK: - Headers & Footers
    func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        if (elementKind == UICollectionView.elementKindSectionHeader) || (elementKind == UICollectionView.elementKindSectionFooter) {
            view.layer.zPosition = 0 // Below scroll indicator
        }
    }
    
    
    // MARK: - Sections
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return CGFloat(AlbumUtilities.imageCellVerticalSpacing(forCollectionType: .popup))
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return CGFloat(AlbumUtilities.imageCellHorizontalSpacing(forCollectionType: .popup))
    }
    
    
    // MARK: - Items i.e. Images
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Calculate the optimum image size
        let size = CGFloat(AlbumUtilities.imageSize(forView: collectionView, imagesPerRowInPortrait: AlbumVars.shared.thumbnailsPerRowInPortrait, collectionType: .popup))

        return CGSize(width: size, height: size)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? LocalImageCollectionViewCell else {
            return
        }

        // Get upload state of image
        let uploadState = getUploadStateOfImage(at: indexPath.item, for: cell)

        // Update cell and selection
        if let _ = selectedImages[indexPath.item] {
            // Deselect the cell
            selectedImages[indexPath.item] = nil
            cell.update(selected: false, state: uploadState)
        } else {
            // Can we upload or re-upload this image?
            if (uploadState == nil) || reUploadAllowed {
                // Select the image
                selectedImages[indexPath.item] = UploadProperties(localIdentifier: cell.localIdentifier,
                                                                  category: categoryId)
                cell.update(selected: true, state: uploadState)
            }
        }

        // Update navigation bar
        updateNavBar()

        // Refresh cell
        cell.reloadInputViews()

        // Update state of Select button if needed
        updateSelectButton()
        if let header = self.localImagesCollection.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: 0)) as? PasteboardImagesHeaderReusableView {
            header.setButtonTitle(forState: sectionState)
        }
    }
}
