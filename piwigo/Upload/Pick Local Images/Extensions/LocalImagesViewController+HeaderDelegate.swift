//
//  LocalImagesViewController+HeaderDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/03/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

extension LocalImagesViewController: LocalImagesHeaderDelegate
{
    // MARK: - LocalImagesHeaderReusableView Delegate Methods
    func didSelectImagesOfSection(_ section: Int) {
        let nberOfImagesInSection = localImagesCollection.numberOfItems(inSection: section)
//        let start = CFAbsoluteTimeGetCurrent()
        if selectedSections[section] == .select {
            // Loop over all images in section to select them
            for item in 0..<nberOfImagesInSection {
                // Images in the upload queue cannot be selected
                let index = getImageIndex(for: IndexPath(item: item, section: section))
                if (indexedUploadsInQueue[index] == nil) || (reUploadAllowed) {
                    // Select image
                    selectedImages[index] = UploadProperties(localIdentifier: self.fetchedImages[index].localIdentifier,
                                                             category: self.categoryId)
                    // Update cell if needed
                    let indexPath = IndexPath(item: item, section: section)
                    if let cell = localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell {
                        // Select or deselect the cell
                        let uploadState = getUploadStateOfImage(at: index, for: cell)
                        cell.update(selected: true, state: uploadState)
                    }
                }
            }
            // Change section button state
            selectedSections[section] = .deselect
        }
        else {
            // Loop over all images in section to deselect them
            for item in 0..<nberOfImagesInSection {
                // Images in the upload queue cannot be selected
                let index = getImageIndex(for: IndexPath(item: item, section: section))
                if (indexedUploadsInQueue[index] == nil) || (reUploadAllowed) {
                    // Select image
                    selectedImages[index] = nil
                    // Update cell if needed
                    let indexPath = IndexPath(item: item, section: section)
                    if let cell = localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell {
                        // Select or deselect the cell
                        let uploadState = getUploadStateOfImage(at: index, for: cell)
                        cell.update(selected: false, state: uploadState)
                    }
                }
            }
            // Change section button state
            selectedSections[section] = .select
        }
//        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//        print("=> Select/Deselect \(localImagesCollection.numberOfItems(inSection: section)) images of section \(section) took \(diff) ms")
        
        // Update navigation bar
        self.updateNavBar()
        
        // Update button
        localImagesCollection.indexPathsForVisibleSupplementaryElements(ofKind: UICollectionView.elementKindSectionHeader).forEach { indexPath in
            if indexPath.section == section,
               let header = localImagesCollection.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPath) as? LocalImagesHeaderReusableView {
                header.selectButton.setTitle(forState: selectedSections[section])
            }
        }
    }
}
