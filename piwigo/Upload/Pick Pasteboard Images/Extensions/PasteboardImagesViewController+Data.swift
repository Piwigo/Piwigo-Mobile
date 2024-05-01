//
//  PasteboardImagesViewController+PHPhotoLibraryChangeObserver.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/03/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import CoreData
import MobileCoreServices
import Photos
import UIKit
import piwigoKit
import uploadKit

extension PasteboardImagesViewController {
    // MARK: - Check Pasteboard Content
    /// Called by the notification center when the pasteboard content is updated
    @objc func checkPasteboard() {
        // Do nothing if the clipboard was emptied assuming that pasteboard objects are already stored
        if let indexSet = UIPasteboard.general.itemSet(withPasteboardTypes: pasteboardTypes),
           let types = UIPasteboard.general.types(forItemSet: indexSet) {

            // Reinitialise cached indexed uploads, deselect images
            pbObjects = []
            indexedUploadsInQueue = .init(repeating: nil, count: indexSet.count)
            selectedImages = .init(repeating: nil, count: indexSet.count)

            // Get date of retrieve
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd-HHmmssSSSS"
            let pbDateTime = dateFormatter.string(from: Date())

            // Loop over all pasteboard objects
            /// Pasteboard images are identified with identifiers of the type "Clipboard-yyyyMMdd-HHmmssSSSS-typ-#" where:
            /// - "Clipboard" is a header telling that the image/video comes from the pasteboard
            /// - "yyyyMMdd-HHmmssSSSS" is the date at which the objects were retrieved
            /// - "typ" is "img" or "mov" depending on the nature of the object
            /// - "#" is the index of the object in the pasteboard
            for idx in indexSet {
                let indexSet = IndexSet(integer: idx)
                var identifier = ""
                // Movies first because objects may contain both movies and images
                if UIPasteboard.general.contains(pasteboardTypes: [kUTTypeMovie as String], inItemSet: indexSet) {
                    identifier = String(format: "%@%@%@%ld", UploadManager.shared.kClipboardPrefix,
                                        pbDateTime, UploadManager.shared.kMovieSuffix, idx)
                } else {
                    identifier = String(format: "%@%@%@%ld", UploadManager.shared.kClipboardPrefix,
                                        pbDateTime, UploadManager.shared.kImageSuffix, idx)
                }
                let newObject = PasteboardObject(identifier: identifier, types: types[idx])
                pbObjects.append(newObject)
                
                // Retrieve data, store in Upload folder and update cache
                startOperations(for: newObject, at: IndexPath(item: idx, section: 0))
            }
        }
    }
    
    
    // MARK: - Prepare Image Files and Cache of Upload Requests
    func startOperations(for pbObject: PasteboardObject, at indexPath: IndexPath) {
        switch (pbObject.state) {
        case .new:
            startPreparation(of: pbObject, at: indexPath)
        default:
            print("Do nothing")
        }
    }

    private func startPreparation(of pbObject: PasteboardObject, at indexPath: IndexPath) {
        // Has the preparation of this object already started?
        guard pendingOperations.preparationsInProgress[indexPath] == nil else {
            return
        }

        // Create an instance of the preparation method
        let preparer = ObjectPreparation(pbObject, at: indexPath.row)
      
        // Refresh the thumbnail of the cell and update upload cache
        preparer.completionBlock = {
            // Job done if operation was cancelled
            if preparer.isCancelled { return }

            // Operation completed
            self.pendingOperations.preparationsInProgress.removeValue(forKey: indexPath)

            // Update upload cache
            if let upload = (self.uploads.fetchedObjects ?? []).first(where: {$0.md5Sum == pbObject.md5Sum}) {
                self.indexedUploadsInQueue[indexPath.row] = (upload.localIdentifier, upload.md5Sum, upload.state)
            }

            // Update cell image if operation was successful
            switch (pbObject.state) {
            case .stored:
                // Refresh the thumbnail of the cell
                DispatchQueue.main.async {
                    if let cell = self.localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell {
                        cell.cellImage.image = pbObject.image
                        self.reloadInputViews()
                    }
                }
            case .failed:
                if self.pendingOperations.preparationsInProgress.isEmpty {
                    var newSetOfObjects = [PasteboardObject]()
                    for index in 0..<self.pbObjects.count {
                        switch self.pbObjects[index].state {
                        case .stored, .ready:
                            newSetOfObjects.append(self.pbObjects[index])
                        case .failed:
                            self.indexedUploadsInQueue.remove(at: index)
                        default:
                            print("Do nothing")
                        }
                    }
                    self.pbObjects = newSetOfObjects
                }
            default:
              NSLog("do nothing")
            }
                
            // If all images are ready:
            /// - refresh section to display the select button
            /// - restart UplaodManager activity
            if self.pendingOperations.preparationsInProgress.isEmpty {
                DispatchQueue.main.async {
                    self.updateSelectButton()
                    if let header = self.localImagesCollection.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: 0)) as? PasteboardImagesHeaderReusableView {
                        header.setButtonTitle(forState: .select)
                    }
                }
                if UploadManager.shared.isPaused {
                    UploadManager.shared.isPaused = false
                    UploadManager.shared.backgroundQueue.async {
                        UploadManager.shared.findNextImageToUpload()
                    }
                }
            }
        }
        
        // Add the operation to help keep track of things
        pendingOperations.preparationsInProgress[indexPath] = preparer
        
        // Add the operation to the download queue
        pendingOperations.preparationQueue.addOperation(preparer)
    }

    func getUploadStateOfImage(at index: Int,
                               for cell: LocalImageCollectionViewCell) -> pwgUploadState? {
        var state: pwgUploadState? = nil
        if pendingOperations.preparationsInProgress.isEmpty,
           index < indexedUploadsInQueue.count {
            // Indexed uploads available
            state = indexedUploadsInQueue[index]?.2
        } else {
            // Use non-indexed data (might be quite slow)
            state = (uploads.fetchedObjects ?? []).first(where: { $0.md5Sum == cell.md5sum })?.state
        }
        return state
    }
}

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
