//
//  PasteboardImagesViewController+HeaderReusableViewDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/03/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

extension PasteboardImagesViewController: PasteboardImagesHeaderDelegate
{
    // MARK: - PasteboardImagesHeaderReusableView Delegate Methods
   func didSelectImagesOfSection() {
        let nberOfImagesInSection = localImagesCollection.numberOfItems(inSection: 0)
        if sectionState == .select {
            // Loop over all images in section to select them (70356 images takes 150.6 ms with iPhone 11 Pro)
            // Here, we exploit the cached local IDs
            for index in 0..<nberOfImagesInSection {
                // Images in the upload queue cannot be selected
                if indexedUploadsInQueue[index] == nil {
                    selectedImages[index] = UploadProperties(localIdentifier: pbObjects[index].identifier,
                                                             category: self.categoryId)
                }
            }
            // Change section button state
            sectionState = .deselect
        } else {
            // Deselect images of section (70356 images takes 52.2 ms with iPhone 11 Pro)
            selectedImages[0..<nberOfImagesInSection] = .init(repeating: nil, count: nberOfImagesInSection)
            // Change section button state
            sectionState = .select
        }

        // Update navigation bar
        self.updateNavBar()

        // Select or deselect visible cells (only one section shown)
        localImagesCollection.indexPathsForVisibleItems.forEach { indexPath in
            // Get cell at index path
            if let cell = localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell {
                // Select or deselect the cell
                let uploadState = getUploadStateOfImage(at: indexPath.item, for: cell)
                cell.update(selected: sectionState == .deselect, state: uploadState)
            }
        }
        
        // Update button (only one section shown)
        let headers = localImagesCollection.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader)
        headers.forEach { header in
            if let header = header as? PasteboardImagesHeaderReusableView {
                header.setButtonTitle(forState: sectionState)
            }
        }
    }
}
