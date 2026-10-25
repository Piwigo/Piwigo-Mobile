//
//  PasteboardImagesViewController+HeaderDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/03/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import UIKit
import PwgKit
import PwgCacheKit

// MARK: - PasteboardImagesHeaderDelegate Methods
extension PasteboardImagesViewController: PasteboardImagesHeaderDelegate
{
   func didSelectImagesOfSection() {
        // Select or deselect all images at once: one range of positions, whatever its size.
        // Images already in the upload queue cannot be selected, unless re-uploading is allowed.
        let range = 0..<pbObjects.count
        switch selectState() {
        case .select:
            selection.select(range: range, excluding: reUploadAllowed ? IndexSet() : queuedPositions)
        case .deselect:
            selection.deselect(range: range)
        case .none:
            return      // Nothing to do (yet)
        }

        // Update navigation bar
        self.updateNavBar()

        // Select or deselect visible cells (only one section shown)
        updateVisibleCells()
        
        // Update button (only one section shown)
        updateSelectButtonOfHeader()
    }
}
