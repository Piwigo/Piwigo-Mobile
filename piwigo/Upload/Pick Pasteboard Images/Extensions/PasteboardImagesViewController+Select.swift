//
//  PasteboardImagesViewController+Select.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 05/08/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

// MARK: - Select Images
extension PasteboardImagesViewController
{
    @objc func cancelSelect() {
        // Clear list of selected images
        selectedImages = .init(repeating: nil, count: pbObjects.count)

        // Update navigation bar
        updateNavBar()

        // Deselect visible cells
        localImagesCollection.visibleCells.forEach { cell in
            if let cell = cell as? LocalImageCollectionViewCell {
                cell.update(selected: false)
            }
        }
        
        // Update button
        let headers = localImagesCollection.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader)
        headers.forEach { header in
            if let header = header as? PasteboardImagesHeaderReusableView {
                header.setButtonTitle(forState: .select)
            }
        }
    }
}


// MARK: - UIGestureRecognizerDelegate Methods
extension PasteboardImagesViewController: UIGestureRecognizerDelegate
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
        // To prevent a crash
        if gestureRecognizer?.view == nil {
            return
        }

        // Point and direction
        let point = gestureRecognizer?.location(in: localImagesCollection)

        // Get index path at touch position
        guard let indexPath = localImagesCollection.indexPathForItem(at: point ?? CGPoint.zero) else {
            return
        }

        // Select/deselect the cell or scroll the view
        if (gestureRecognizer?.state == .began) || (gestureRecognizer?.state == .changed) {

            // Get cell at touch position
            guard let cell = localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell else {
                return
            }

            // Update the selection if not already done
            if !imagesBeingTouched.contains(indexPath) {

                // Store that the user touched this cell during this gesture
                imagesBeingTouched.append(indexPath)

                // Get upload state of image
                let uploadState = getUploadStateOfImage(at: indexPath.item, for: cell)

                // Update the selection state
                if let _ = selectedImages[indexPath.item] {
                    selectedImages[indexPath.item] = nil
                    cell.update(selected: false, state: uploadState)
                } else {
                    // Can we upload or re-upload this image?
                    if (uploadState == nil) || reUploadAllowed {
                        // Select the cell
                        selectedImages[indexPath.item] = UploadProperties(localIdentifier: cell.localIdentifier,
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
        if gestureRecognizer?.state == .ended {
            // Clear list of touched images
            imagesBeingTouched = []
        }
    }

    func updateSelectButton()
    {
        // Number of images in section
        let nberOfImagesInSection = localImagesCollection.numberOfItems(inSection: 0)

        // Job done if there is no image presented
        if nberOfImagesInSection == 0 {
            sectionState = .none
            return
        }
        
        // Number of selected images
        let nberOfSelectedImagesInSection = selectedImages[0..<nberOfImagesInSection].compactMap{ $0 }.count
        if nberOfImagesInSection == nberOfSelectedImagesInSection {
            // All images are selected
            sectionState = .deselect
            return
        }

        // Can we calculate the number of images already in the upload queue?
        if pendingOperations.preparationsInProgress.isEmpty == false {
            // Keep Select button disabled
            sectionState = .none
            return
        }

        // Number of images already in the upload queue
        var nberOfImagesOfSectionInUploadQueue = 0
        if reUploadAllowed == false {
            nberOfImagesOfSectionInUploadQueue = indexedUploadsInQueue[0..<nberOfImagesInSection]
                                                    .compactMap{ $0 }.count
        }

        // Update state of Select button only if needed
        if nberOfImagesInSection == nberOfImagesOfSectionInUploadQueue {
            // All images are in the upload queue or already downloaded
            sectionState = .none
        } else if nberOfImagesInSection == nberOfSelectedImagesInSection + nberOfImagesOfSectionInUploadQueue {
            // All images are either selected or in the upload queue
            sectionState = .deselect
        } else {
            // Not all images are either selected or in the upload queue
            sectionState = .select
        }
    }
}
