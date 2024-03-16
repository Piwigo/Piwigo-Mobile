//
//  LocalImagesViewController+LocalImagesHeaderDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/03/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import piwigoKit

extension LocalImagesViewController: LocalImagesHeaderDelegate
{
    // MARK: - LocalImagesHeaderReusableView Delegate Methods
    func didSelectImagesOfSection(_ section: Int) {
        let nberOfImagesInSection = localImagesCollection.numberOfItems(inSection: section)
        let firstIndex: Int, lastIndex: Int
        if UploadVars.localImagesSort == .dateCreatedDescending {
            firstIndex = getImageIndex(for: IndexPath(item: 0, section: section))
            lastIndex = getImageIndex(for: IndexPath(item: nberOfImagesInSection - 1, section: section))
        } else {
            firstIndex = getImageIndex(for: IndexPath(item: nberOfImagesInSection - 1, section: section))
            lastIndex = getImageIndex(for: IndexPath(item: 0, section: section))
        }
        let start = CFAbsoluteTimeGetCurrent()
        if selectedSections[section] == .select {
            // Loop over all images in section to select them (70356 images takes 150.6 ms with iPhone 11 Pro)
            // Here, we exploit the cached local IDs
            for index in firstIndex...lastIndex {
                // Images in the upload queue cannot be selected
                if (indexedUploadsInQueue[index] == nil) || (reUploadAllowed) {
                    // Select image
                    selectedImages[index] = UploadProperties(localIdentifier: self.fetchedImages[index].localIdentifier,
                                                             category: self.categoryId)
                    // Update cell if needed
                    let indexPath = IndexPath(item: index - firstIndex, section: section)
                    if let cell = localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell {
                        // Select or deselect the cell
                        let uploadState = getUploadStateOfImage(at: index, for: cell)
                        cell.update(selected: true, state: uploadState)
                    }
                }
            }
            // Change section button state
            selectedSections[section] = .deselect
        } else {
            // Deselect images of section (70356 images takes 52.2 ms with iPhone 11 Pro)
            selectedImages[firstIndex...lastIndex] = .init(repeating: nil, count: lastIndex - firstIndex + 1)
            
            // Update cells if needed
            for index in 0..<nberOfImagesInSection {
                let indexPath = IndexPath(item: index, section: section)
                if let cell = localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell {
                    // Select or deselect the cell
                    let uploadState = getUploadStateOfImage(at: firstIndex + index, for: cell)
                    cell.update(selected: false, state: uploadState)
                }
            }
            
            // Change section button state
            selectedSections[section] = .select
        }
        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
        print("=> Select/Deselect \(localImagesCollection.numberOfItems(inSection: section)) images of section \(section) took \(diff) ms")
        
        // Update navigation bar
        self.updateNavBar()
        
        // Update button
        localImagesCollection.indexPathsForVisibleSupplementaryElements(ofKind: UICollectionView.elementKindSectionHeader).forEach { indexPath in
            if indexPath.section == section,
               let header = localImagesCollection.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPath) as? LocalImagesHeaderReusableView {
                header.setButtonTitle(forState: selectedSections[section])
            }
        }
    }
}
