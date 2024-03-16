//
//  LocalImagesViewController+UICollectionViewDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/03/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import piwigoKit

extension LocalImagesViewController: UICollectionViewDelegate
{
    // MARK: - Headers & Footers
    func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        if (elementKind == UICollectionView.elementKindSectionHeader) || (elementKind == UICollectionView.elementKindSectionFooter) {
            view.layer.zPosition = 0 // Below scroll indicator
        }
    }

    
    // MARK: - Sections
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 10, left: AlbumUtilities.kImageMarginsSpacing,
                            bottom: 10, right: AlbumUtilities.kImageMarginsSpacing)
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
        
        // Get index and upload state of image
        let index = getImageIndex(for: indexPath)
        let uploadState = getUploadStateOfImage(at: index, for: cell)

        // Update cell and selection
        if let _ = selectedImages[index] {
            // Deselect the cell
            selectedImages[index] = nil
            cell.update(selected: false, state: uploadState)
        } else {
            // Can we upload or re-upload this image?
            if (uploadState == nil) || reUploadAllowed {
                // Select the image
                selectedImages[index] = UploadProperties(localIdentifier: cell.localIdentifier,
                                                         category: categoryId)
                cell.update(selected: true, state: uploadState)
            }
        }

        // Update navigation bar
        updateNavBar()

        // Refresh cell
        cell.reloadInputViews()

        // Update state of Select button if needed
        let selectState = updateSelectButton(ofSection: indexPath.section)
        let indexPathOfHeader = IndexPath(item: 0, section: indexPath.section)
        if let header = self.localImagesCollection.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPathOfHeader) as? LocalImagesHeaderReusableView {
            header.setButtonTitle(forState: selectState)
        }
    }
}
