//
//  LocalImagesViewController+Select.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/08/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import PwgKit
import PwgCacheKit

// MARK: Select Images
extension LocalImagesViewController
{
    @objc func cancelSelect() {
        // Clear list of selected images
        selection.removeAll()

        // Update navigation bar
        updateNavBar()

        // Deselect visible cells
        updateVisibleCells()
        
        // Update select buttons
        updateVisibleSelectButtons()
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
                if selection.contains(index) {
                    // Deselect the cell
                    selection.remove(index)
                    cell.update(selected: false, state: uploadState)
                } else {
                    // Can we upload or re-upload this image?
                    if (uploadState == nil) || reUploadAllowed {
                        // Select the cell
                        selection.insert(index)
                        cell.update(selected: true, state: uploadState)
                    }
                }

                // Update navigation bar
                updateNavBar()
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

    /// State of the Select button of a section, from the selection and the images already uploaded or queued.
    /// Nothing is stored: the state is computed from the ranges of positions, however large the section is.
    func updateSelectButton(ofSection section: Int) -> SelectButtonState {
        // The positions of the images in the upload queue must be known to tell what can be selected
        if isIndexingUploads || section >= layout.sectionCount { return .none }
        let state = selection.selectState(of: layout.range(ofSection: section),
                                          queued: queuedPositions, reUploadAllowed: reUploadAllowed)
        switch state {
        case .none:     return .none
        case .select:   return .select
        case .deselect: return .deselect
        }
    }
}
