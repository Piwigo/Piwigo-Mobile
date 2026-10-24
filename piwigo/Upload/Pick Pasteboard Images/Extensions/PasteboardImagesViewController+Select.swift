//
//  PasteboardImagesViewController+Select.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 05/08/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import PwgKit
import PwgCacheKit

// MARK: - Select Images
extension PasteboardImagesViewController
{
    @objc func cancelSelect() {
        // Clear list of selected images
        selection.removeAll()

        // Update navigation bar
        updateNavBar()

        // Deselect visible cells, keeping the state of their upload request
        updateVisibleCells()
        
        // Update button
        let headers = localImagesCollection.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader)
        headers.forEach { header in
            if let header = header as? PasteboardImagesHeaderReusableView {
                header.selectButton.setTitle(forState: selectState())
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
                if selection.contains(indexPath.item) {
                    selection.remove(indexPath.item)
                    cell.update(selected: false, state: uploadState)
                } else {
                    // Can we upload or re-upload this image?
                    if (uploadState == nil) || reUploadAllowed {
                        // Select the cell
                        selection.insert(indexPath.item)
                        cell.update(selected: true, state: uploadState)
                    }
                }
                
                // Update navigation bar
                updateNavBar()
            }
        }

        // Is this the end of the gesture?
        if gestureRecognizer?.state == .ended {
            // Clear list of touched images
            imagesBeingTouched = []
            
            // Update state of Select button if needed
            updateSelectButtonOfHeader()
        }
    }
}
