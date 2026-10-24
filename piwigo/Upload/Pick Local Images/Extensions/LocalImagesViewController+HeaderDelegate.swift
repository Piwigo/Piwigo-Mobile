//
//  LocalImagesViewController+HeaderDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/03/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import UIKit
import PwgKit
import PwgCacheKit

// MARK: LocalImagesHeaderDelegate Methods
extension LocalImagesViewController: LocalImagesHeaderDelegate
{
    func didSelectImagesOfSection(_ section: Int) {
        // Select or deselect the whole section at once: one range of positions, whatever its size.
        // Images already in the upload queue cannot be selected, unless re-uploading is allowed.
        let range = layout.range(ofSection: section)
        switch updateSelectButton(ofSection: section) {
        case .select:
            selection.select(range: range, excluding: reUploadAllowed ? IndexSet() : queuedPositions)
        case .deselect:
            selection.deselect(range: range)
        case .none:
            return      // Nothing to do (yet)
        }
        
        // Update the cells shown
        updateVisibleCells()
        
        // Update navigation bar
        self.updateNavBar()
        
        // Update button
        updateVisibleSelectButtons()
    }
}
