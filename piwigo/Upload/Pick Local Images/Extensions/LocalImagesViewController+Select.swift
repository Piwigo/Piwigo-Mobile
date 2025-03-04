//
//  LocalImagesViewController+Select.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/08/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

// MARK: - Select Images
extension LocalImagesViewController
{
    @objc func cancelSelect() {
        // Clear list of selected sections
        selectedSections = .init(repeating: .select, count: fetchedImages.count)

        // Clear list of selected images
        selectedImages = .init(repeating: nil, count: fetchedImages.count)

        // Update navigation bar
        updateNavBar()

        // Deselect visible cells
        localImagesCollection.visibleCells.forEach { cell in
            if let cell = cell as? LocalImageCollectionViewCell {
                cell.update(selected: false)
            }
        }
        
        // Update select buttons
        let headers = localImagesCollection.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader)
        headers.forEach { header in
            if let header = header as? LocalImagesHeaderReusableView {
                header.selectButton.setTitle(forState: .select)
            }
        }
    }
}


// MARK: - UIGestureRecognizerDelegate Methods
extension LocalImagesViewController: UIGestureRecognizerDelegate
{
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Will interpret touches only in horizontal direction
        if (gestureRecognizer is UIPanGestureRecognizer) {
            let gPR = gestureRecognizer as? UIPanGestureRecognizer
            let translation = gPR?.translation(in: localImagesCollection)
            if abs(translation?.x ?? 0.0) > abs(translation?.y ?? 0.0) {
                return true
            }
        }
        return false
    }

    @objc func touchedImages(_ gestureRecognizer: UIPanGestureRecognizer?) {
        // Just in case…
        guard let gestureRecognizerState = gestureRecognizer?.state,
              let point = gestureRecognizer?.location(in: localImagesCollection),
              let indexPath = localImagesCollection.indexPathForItem(at: point)
        else { return }
        
        // Select/deselect the cell or scroll the view
        if [.began, .changed].contains(gestureRecognizerState) {

            // Get cell at touch position
            guard let cell = localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell
            else { return }

            // Update the selection if not already done
            if !imagesBeingTouched.contains(indexPath) {

                // Store that the user touched this cell during this gesture
                imagesBeingTouched.append(indexPath)

                // Get index and upload state of image
                let index = getImageIndex(for: indexPath)
                let uploadState = getUploadStateOfImage(at: index, for: cell)

                // Update the selection state
                if let _ = selectedImages[index] {
                    // Deselect the cell
                    selectedImages[index] = nil
                    cell.update(selected: false, state: uploadState)
                } else {
                    // Can we upload or re-upload this image?
                    if (uploadState == nil) || reUploadAllowed {
                        // Select the cell
                        selectedImages[index] = UploadProperties(localIdentifier: cell.localIdentifier,
                                                                 category: categoryId)
                        cell.update(selected: true, state: uploadState)
                    }
                }

                // Update navigation bar
                updateNavBar()

                // Refresh cell
                cell.reloadInputViews()
            }
        }

        // Is this the end of the gesture?
        if gestureRecognizerState == .ended {
            // Clear list of touched images
            imagesBeingTouched = []

            // Update state of Select button if needed
            let selectState = updateSelectButton(ofSection: indexPath.section)
            let indexPath = IndexPath(item: 0, section: indexPath.section)
            if let header = self.localImagesCollection.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPath) as? LocalImagesHeaderReusableView {
                header.selectButton.setTitle(forState: selectState)
            }
        }
    }

    func updateSelectButton(ofSection section: Int) -> SelectButtonState {
        // Number of images in section
        let nberOfImagesInSection = localImagesCollection.numberOfItems(inSection: section)
        if nberOfImagesInSection == 0 {
            if section < selectedSections.count {
                selectedSections[section] = .none
            }
            return .none
        }

        // Get start and last indices of section
        let firstIndex: Int, lastIndex: Int
        if UploadVars.shared.localImagesSort == .dateCreatedDescending {
            firstIndex = getImageIndex(for: IndexPath(item: 0, section: section))
            lastIndex = getImageIndex(for: IndexPath(item: nberOfImagesInSection - 1, section: section))
        } else {
            firstIndex = getImageIndex(for: IndexPath(item: nberOfImagesInSection - 1, section: section))
            lastIndex = getImageIndex(for: IndexPath(item: 0, section: section))
        }
        
        // Number of selected images
        let nberOfSelectedImagesInSection = selectedImages.count > lastIndex ?
            selectedImages[firstIndex...lastIndex].compactMap{ $0 }.count : 0

        // Can we calculate the number of images already in the upload queue?
        if queue.operationCount != 0 {
            // Keep Select button disabled
            if section < selectedSections.count {
                selectedSections[section] = .none
            }
            return .none
        }

        // Number of images already in the upload queue
        var nberOfImagesOfSectionInUploadQueue = 0
        if reUploadAllowed == false {
            nberOfImagesOfSectionInUploadQueue = indexedUploadsInQueue.count > lastIndex ?  indexedUploadsInQueue[firstIndex...lastIndex].compactMap{ $0 }.count : 0
        }

        // Update state of Select button only if needed
        if nberOfImagesInSection == nberOfImagesOfSectionInUploadQueue {
            // All images are in the upload queue or already uploaded
            if section < selectedSections.count {
                selectedSections[section] = .none
            }
            return .none
        } else if nberOfImagesInSection == nberOfSelectedImagesInSection + nberOfImagesOfSectionInUploadQueue {
            // All images are either selected or in the upload queue
            if section < selectedSections.count {
                selectedSections[section] = .deselect
            }
            return .deselect
        } else {
            // Not all images are either selected or in the upload queue
            if section < selectedSections.count {
                selectedSections[section] = .select
            }
            return .select
        }
    }
}
