//
//  PasteboardImagesViewController+Menus.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 17/08/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import PwgKit
import PwgCacheKit

// MARK: Menus
extension PasteboardImagesViewController {
    
    // MARK: - Re-upload Images
    func getMenuForReuploadingPhotos() -> UIMenu? {
        // Check if there are uploaded photos to re-upload
        if !canReUploadImages() { return nil }
        
        // Propose option for re-uploading photos
        let reUpload = UIAction(title: String(localized: "localImages_reUploadTitle", comment: "Re-upload"),
                                image: reUploadAllowed ? UIImage(systemName: "checkmark") : nil, handler: { [weak self] _ in
            self?.swapReuploadOption()
        })
        reUpload.accessibilityIdentifier = "Re-upload"

        return UIMenu(title: "", image: nil,
                      identifier: UIMenu.Identifier("org.piwigo.localImages.reupload"),
                      options: .displayInline,
                      children: [reUpload])
    }
    
    private func swapReuploadOption() {
        // Swap "Re-upload" option
        reUploadAllowed = !reUploadAllowed
        updateActionButton()
        
        // No further operation if re-uploading is allowed
        if reUploadAllowed { return }
        
        // Deselect already uploaded photos if needed
        let uploaded = IndexSet(queuedPositions.filter { position in
            guard let state = uploadState(at: position) else { return false }
            return [.finished, .moderated].contains(state)
        })
        let didChangeSelection = selection.positions.intersection(uploaded).isEmpty == false
        selection.remove(uploaded)
        
        // Refresh collection view if necessary
        if didChangeSelection {
            self.updateNavBar()
            self.localImagesCollection.reloadData()
        }
    }
    
    private func canReUploadImages() -> Bool {
        // Don't provide access to the re-upload button until the preparation work is not done
        if !pendingOperations.preparationsInProgress.isEmpty { return false }

        // Check if there are already uploaded photos
        return queuedPositions.contains { position in
            guard let state = uploadState(at: position) else { return false }
            return [.finished, .moderated].contains(state)
        }
    }
}
