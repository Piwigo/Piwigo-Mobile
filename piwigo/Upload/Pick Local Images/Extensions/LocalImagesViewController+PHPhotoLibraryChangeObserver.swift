//
//  LocalImagesViewController+PHPhotoLibraryChangeObserver.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/03/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Photos
import UIKit

extension LocalImagesViewController: PHPhotoLibraryChangeObserver
{
    // MARK: Changes occured in the Photo library
    /// Changes are not returned as expected (iOS 14.3 provides objects, not their indexes).
    /// The selection and the upload requests are therefore found again by their local identifiers.
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        // This method may be called on a background queue; use the main queue to update the UI.
        DispatchQueue.main.async {
            // Check the fetch for changes
            guard let changes = changeInstance.changeDetails(for: self.fetchedImages)
                else { return }
            
            #if DEBUG
            debugPrint(changes.fetchResultAfterChanges.count, self.fetchedImages.count)
            #endif
            // Any new photo inserted? or delete? or added to selection?
            if changes.insertedObjects.isEmpty,
               changes.removedObjects.isEmpty,
               changes.fetchResultAfterChanges.count == self.fetchedImages.count {
                return
            }

            // Show HUD during update, preventing touches
            self.showHUD(withTitle: String(localized: "editImageDetailsHUD_updatingPlural", comment: "Updating Photos…"))

            // Fetch uploads before preparing the new data
            do {
                try self.uploads.performFetch()
            } catch {
                #if DEBUG
                debugPrint("Error: \(error.localizedDescription)")
                #endif
            }
            self.uploadStates = self.currentUploadStates()
            
            // Disable sort options and actions until the new images are shown
            self.actionBarButton?.isEnabled = false
            self.uploadBarButton?.isEnabled = false

            // Prepare the new data in the background and show it all at once
            self.applyChange(to: changes.fetchResultAfterChanges)
        }
    }
}
