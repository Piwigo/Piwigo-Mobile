//
//  PasteboardImagesViewController+Menus.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 17/08/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

// MARK: Menus
extension PasteboardImagesViewController {
    
    // MARK: - Re-upload Images
    func getMenuForReuploadingPhotos() -> UIMenu? {
        // Check if there are uploaded photos to re-upload
        if !canReUploadImages() { return nil }
        
        // Propose option for re-uploading photos
        let reUpload = UIAction(title: NSLocalizedString("localImages_reUploadTitle", comment: "Re-upload"),
                                image: reUploadAllowed ? UIImage(systemName: "checkmark") : nil, handler: { _ in
            self.swapReuploadOption()
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
        var didChangeSelection = false
        if pendingOperations.preparationsInProgress.isEmpty,
           selectedImages.count < indexedUploadsInQueue.count {
            for index in 0..<selectedImages.count {
                // Indexed uploads available
                if let upload = indexedUploadsInQueue[index],
                   [.finished, .moderated].contains(upload.2) {
                    // Deselect cell
                    selectedImages[index] = nil
                    didChangeSelection = true
                }
            }
        } else {
            // Use non-indexed data (might be quite slow)
            let completed = (uploads.fetchedObjects ?? []).filter({[.finished, .moderated].contains($0.state)})
            for index in 0..<selectedImages.count {
                if let localIdentifier = selectedImages[index]?.localIdentifier,
                   let _ = completed.firstIndex(where: { $0.localIdentifier == localIdentifier }) {
                    selectedImages[index] = nil
                    didChangeSelection = true
                }
            }
        }
        
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
        let indexedUploads = self.indexedUploadsInQueue.compactMap({$0})
        let completed = (uploads.fetchedObjects ?? []).filter({[.finished, .moderated].contains($0.state)})
        for index in 0..<indexedUploads.count {
            if let _ = completed.first(where: {$0.md5Sum == indexedUploads[index].1}) {
                return true
            }
        }
        return false
    }
}
