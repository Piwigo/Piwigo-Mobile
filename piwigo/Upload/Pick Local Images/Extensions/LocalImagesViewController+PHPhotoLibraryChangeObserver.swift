//
//  LocalImagesViewController+PHPhotoLibraryChangeObserver.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/03/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Photos

extension LocalImagesViewController: PHPhotoLibraryChangeObserver
{
    // MARK: Changes occured in the Photo library
    /// Changes are not returned as expected (iOS 14.3 provides objects, not their indexes).
    /// The image selection is therefore updated during the sort.
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        // Check each of the fetches for changes
        guard let changes = changeInstance.changeDetails(for: self.fetchedImages)
            else { return }

        // This method may be called on a background queue; use the main queue to update the UI.
        DispatchQueue.main.async {
            debugPrint(changes.fetchResultAfterChanges.count, self.fetchedImages.count)
            // Any new photo inserted? or delete? or added to selection?
            if changes.insertedObjects.isEmpty,
               changes.removedObjects.isEmpty,
               changes.fetchResultAfterChanges.count == self.fetchedImages.count {
                return
            }

            // Show HUD during update, preventing touches
            self.showHUD(withTitle: NSLocalizedString("editImageDetailsHUD_updatingPlural", comment: "Updating Photos…"))

            // Update fetched asset collection
            self.fetchedImages = changes.fetchResultAfterChanges

            // Disable sort options and actions before sorting and caching
            self.actionBarButton?.isEnabled = false
            self.uploadBarButton?.isEnabled = false

            // Sort images in background, reset cache and image selection
            DispatchQueue.global(qos: .userInitiated).async {
                self.sortImagesAndIndexUploads()
            }
        }
    }
}
