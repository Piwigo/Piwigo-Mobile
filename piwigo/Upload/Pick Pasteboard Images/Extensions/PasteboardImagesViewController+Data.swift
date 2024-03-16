//
//  PasteboardImagesViewController+PHPhotoLibraryChangeObserver.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/03/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import CoreData
import Photos
import piwigoKit

extension PasteboardImagesViewController: NSFetchedResultsControllerDelegate
{
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

        switch type {
        case .insert:
            print("••> PasteboardImagesViewController: insert pending upload request…")
            // Add upload request to cache and update cell
            guard let upload:Upload = anObject as? Upload else { return }

            // Get index of selected image, deselect it and add request to cache
            if let index = selectedImages.firstIndex(where: {$0?.localIdentifier == upload.localIdentifier}) {
                // Deselect image
                selectedImages[index] = nil
                // Add upload request to cache
                indexedUploadsInQueue[index] = (upload.localIdentifier, upload.md5Sum, upload.state)
            }
            
            // Update corresponding cell
            updateCellAndSectionHeader(for: upload)
        case .delete:
            print("••> PasteboardImagesViewController: delete pending upload request…")
            // Delete upload request from cache and update cell
            guard let upload:Upload = anObject as? Upload else { return }

            // Remove image from indexed upload queue
            if let index = indexedUploadsInQueue.firstIndex(where: {$0?.0 == upload.localIdentifier}) {
                indexedUploadsInQueue[index] = nil
            }
            // Remove image from selection if needed
            if let index = selectedImages.firstIndex(where: {$0?.localIdentifier == upload.localIdentifier}) {
                // Deselect image
                selectedImages[index] = nil
            }
            // Update corresponding cell
            updateCellAndSectionHeader(for: upload)
        case .move:
            assertionFailure("••> PasteboardImagesViewController: Unexpected move!")
        case .update:
            print("••• PasteboardImagesViewController controller:update...")
            // Update upload request and cell
            guard let upload:Upload = anObject as? Upload else { return }

            // Update upload in indexed upload queue
            if let indexOfUploadedImage = indexedUploadsInQueue.firstIndex(where: {$0?.0 == upload.localIdentifier}) {
                indexedUploadsInQueue[indexOfUploadedImage]?.1 = upload.md5Sum
                indexedUploadsInQueue[indexOfUploadedImage]?.2 = upload.state
            }
            // Update corresponding cell
            updateCellAndSectionHeader(for: upload)
        @unknown default:
            assertionFailure("••> PasteboardImagesViewController: unknown NSFetchedResultsChangeType!")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
//        print("••• PasteboardImagesViewController controller:didChangeContent...")
        // Update navigation bar
        updateNavBar()
    }

    func updateCellAndSectionHeader(for upload: Upload) {
        DispatchQueue.main.async {
            if let visibleCells = self.localImagesCollection.visibleCells as? [LocalImageCollectionViewCell],
               let cell = visibleCells.first(where: {$0.localIdentifier == upload.localIdentifier}) {
                // Update cell
                cell.update(selected: false, state: upload.state)
                cell.reloadInputViews()

                // The section will be refreshed only if the button content needs to be changed
                self.updateSelectButton()
                if let header = self.localImagesCollection.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: 0)) as? PasteboardImagesHeaderReusableView {
                    header.setButtonTitle(forState: self.sectionState)
                }
            }
        }
    }
}
