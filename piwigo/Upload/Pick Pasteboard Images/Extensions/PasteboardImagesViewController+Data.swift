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
import PwgKit
import PwgCacheKit
import PwgUploadKit

extension PasteboardImagesViewController {
    // MARK: - Check Pasteboard Content
    /// Called by the notification center when the pasteboard content is updated
    @objc func checkPasteboard() {
        // Job done if the pasteboard content did not change
        // (this preserves the current selection when e.g. switching apps)
        let changeCount = UIPasteboard.general.changeCount
        if changeCount == pbChangeCount { return }
        pbChangeCount = changeCount

        // The objects retrieved before are no longer shown: stop preparing them, ignore what they would still report
        /// and forget what refers to their positions
        pendingOperations.preparationQueue.cancelAllOperations()
        pendingOperations.preparationsInProgress.removeAll()
        generation += 1
        selection.removeAll()
        queuedPositions = IndexSet()

        // Retrieve pasteboard object indexes and types, then create identifiers
        if let itemSet = UIPasteboard.general.itemSet(withPasteboardTypes: pasteboardTypes),
           let types = UIPasteboard.general.types(forItemSet: itemSet) {

            pbObjects = []

            // Get date of retrieve
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd-HHmmssSSSS"
            let pbDateTime = dateFormatter.string(from: Date())

            // Loop over all pasteboard objects
            /// Pasteboard images are identified with identifiers of the type "pwgClipboard-yyyyMMdd-HHmmssSSSS-typ-#" where:
            /// - "pwgClipboard" is a header telling that the image/video comes from the pasteboard (see kClipboardPrefix)
            /// - "yyyyMMdd-HHmmssSSSS" is the date at which the objects were retrieved
            /// - "typ" is "-img-", "-mov-", "-pdf-", "-eps-" or "-gif-" depending on the nature of the object (see kImageSuffix, kMovieSuffix, kPdfSuffix, kEpsSuffix, kGifSuffix)
            /// - "#" is the index of the object in the pasteboard
            /// The item set may not start at 0 nor be contiguous (e.g. when the pasteboard
            /// also contains text items), so the matching items are enumerated:
            /// - "idx" is the index of the item in the pasteboard,
            /// - "offset" is the index of the object in the local array and collection view.
            for (offset, idx) in itemSet.enumerated() {
                let indexSet = IndexSet(integer: idx)
                var identifier = kClipboardPrefix + pbDateTime
                // Movies first because movies may contain images
                if UIPasteboard.general.contains(pasteboardTypes: [UTType.movie.identifier], inItemSet: indexSet) {
                    identifier += kMovieSuffix + String(idx + 1)
                }
                // PDFs next because PDF documents may also provide a preview image
                // (only when the server accepts PDF files, i.e. when pasteboardTypes contains
                //  the PDF type; otherwise mixed items fall back to their image representation)
                else if pasteboardTypes.contains(UTType.pdf.identifier),
                        UIPasteboard.general.contains(pasteboardTypes: [UTType.pdf.identifier], inItemSet: indexSet) {
                    identifier += kPdfSuffix + String(idx + 1)
                }
                // EPS next, for the same reason as PDF (only when the server accepts EPS files)
                else if pasteboardTypes.contains(UTType.eps.identifier),
                        UIPasteboard.general.contains(pasteboardTypes: [UTType.eps.identifier], inItemSet: indexSet) {
                    identifier += kEpsSuffix + String(idx + 1)
                }
                // GIFs before the other image types (only when the server accepts GIF files):
                // apps often place several representations of the same image in the pasteboard
                // and the generic image branch below would adopt the first of them, losing the
                // animation. The GIF file is then uploaded as is, see prepareImageFromFile().
                else if pasteboardTypes.contains(UTType.gif.identifier),
                        UIPasteboard.general.contains(pasteboardTypes: [UTType.gif.identifier], inItemSet: indexSet) {
                    identifier += kGifSuffix + String(idx + 1)
                }
                else {
                    identifier += kImageSuffix + String(idx + 1)
                }
                let fileName = pbDateTime.dropLast(4) + "-" + String(idx + 1)
                let newObject = PasteboardObject(identifier: identifier, fileName: fileName,
                                                 types: types[offset], itemIndex: idx)
                pbObjects.append(newObject)

                // Retrieve data, store in Upload folder and update cache
                startOperations(for: newObject, at: offset)
            }
        }
        else {
            pbObjects = []
        }

        // Refresh the collection view and navigation bar
        localImagesCollection.reloadData()
        updateNavBar()
    }
    
    
    // MARK: - Prepare Image Files and Cache of Upload Requests
    func startOperations(for pbObject: PasteboardObject, at position: Int) {
        switch (pbObject.state) {
        case .new:
            startPreparation(of: pbObject, at: position)
        default:
            #if DEBUG
            debugPrint("Do nothing")
            #endif
            break
        }
    }
    
    /// Starts again the preparation of the objects which were not prepared when the view disappeared
    func resumePreparation() {
        for (position, pbObject) in pbObjects.enumerated() where pbObject.state == .new {
            startOperations(for: pbObject, at: position)
        }
    }

    private func startPreparation(of pbObject: PasteboardObject, at position: Int) {
        // Has the preparation of this object already started?
        guard pendingOperations.preparationsInProgress[position] == nil else {
            return
        }

        // Create an instance of the preparation method
        // Expansive work realised on a background queue
        let scale = CGFloat(fmax(1.0, self.view.traitCollection.displayScale))
        let preparer = ObjectPreparation(pbObject, scale: scale)
        let generation = self.generation
      
        // Refresh the thumbnail of the cell and update upload cache
        // The whole completion work is performed on the main queue so that
        // the caches are only mutated on the main thread (no data race with
        // the collection view data source and other completion blocks).
        preparer.completionBlock = {
            // Job done if operation was cancelled
            if preparer.isCancelled { return }

            DispatchQueue.main.async {
                // Ignore the objects of a previous retrieve: their positions mean nothing now
                guard generation == self.generation else { return }
                
                // Operation completed
                self.pendingOperations.preparationsInProgress.removeValue(forKey: position)

                // Update cell image if operation was successful
                if pbObject.state == .stored {
                    // The upload request of this image, if any, is known by its MD5 checksum
                    self.refreshQueuedPositions()
                    
                    // Refresh the thumbnail of the cell
                    let indexPath = IndexPath(item: position, section: 0)
                    if let cell = self.localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell {
                        cell.md5sum = pbObject.md5Sum
                        let uploadState = self.getUploadStateOfImage(at: position, for: cell)
                        cell.update(selected: self.selection.contains(position), state: uploadState)
                        cell.cellImage.image = pbObject.image
                    }
                }

                // When all images/videos are ready:
                /// - keep only stored objects
                /// - refresh section to display the select button
                /// - restart UploadManager activity
                if self.pendingOperations.preparationsInProgress.isEmpty {
                    // Some objects may not be available anymore: keep the others and the selection of the others
                    let kept = self.pbObjects.indices.filter { [.stored, .ready].contains(self.pbObjects[$0].state) }
                    let didRemoveObjects = kept.count != self.pbObjects.count
                    if didRemoveObjects {
                        var newSelection = PhotoLibrarySelection()
                        for (newPosition, oldPosition) in kept.enumerated() where self.selection.contains(oldPosition) {
                            newSelection.insert(newPosition)
                        }
                        self.pbObjects = kept.map { self.pbObjects[$0] }
                        self.selection = newSelection
                    }
                    self.refreshQueuedPositions()

                    // Update section header and action button
                    // Reload collection view if some objects were removed
                    if didRemoveObjects {
                        self.localImagesCollection.reloadData()
                    }
                    self.updateNavBar()
                    self.updateSelectButtonOfHeader()
                }
            }
        }
        
        // Add the operation to help keep track of things
        pendingOperations.preparationsInProgress[position] = preparer
        
        // Add the operation to the queue
        pendingOperations.preparationQueue.addOperation(preparer)
    }
    
    
    // MARK: - Upload States
    /// State of the upload request of each image. A request is found by the identifier of the image, which it
    /// carries from the start: its checksum is only known once the file is prepared, and is then the one of the
    /// prepared file, not of the pasteboard data. The checksum recognises an image which was uploaded earlier and
    /// is copied again (its identifier is new). The first request of an identifier or of a checksum is the one kept.
    func refreshUploadStates() {
        var byIdentifier = [String: pwgUploadState](), byMD5 = [String: pwgUploadState]()
        for upload in uploads.fetchedObjects ?? [] {
            if byIdentifier[upload.localIdentifier] == nil { byIdentifier[upload.localIdentifier] = upload.state }
            if !upload.md5Sum.isEmpty, byMD5[upload.md5Sum] == nil { byMD5[upload.md5Sum] = upload.state }
        }
        uploadStatesByIdentifier = byIdentifier
        uploadStatesByMD5 = byMD5
    }
    
    func uploadState(ofIdentifier identifier: String, md5Sum: String) -> pwgUploadState? {
        // Request of this very image
        if let state = uploadStatesByIdentifier[identifier] { return state }
        guard !md5Sum.isEmpty else { return nil }
        // Request of a copy of this image, uploaded earlier: the identifier of the request was remembered
        /// from the checksum of the pasteboard data
        if let uploadedIdentifier = uploadedImages[md5Sum], let state = uploadStatesByIdentifier[uploadedIdentifier] {
            return state
        }
        // Request whose file is the pasteboard data as is
        return uploadStatesByMD5[md5Sum]
    }
    
    /// Remembers the images whose upload was queued, so that they are recognised when the clipboard is opened again
    func rememberUploads(of requests: [UploadProperties]) {
        for request in requests {
            guard let pbObject = pbObjects.first(where: { $0.identifier == request.localIdentifier }),
                  !pbObject.md5Sum.isEmpty else { continue }
            uploadedImages[pbObject.md5Sum] = pbObject.identifier
        }
        UploadVars.shared.uploadedPasteboardImages = uploadedImages
        refreshQueuedPositions()
    }
    
    /// Forgets the images whose upload request no longer exists (completed uploads cleared by the user, etc.)
    func forgetDeletedUploads() {
        let remembered = UploadVars.shared.uploadedPasteboardImages
        uploadedImages = remembered.filter { uploadStatesByIdentifier[$0.value] != nil }
        if uploadedImages.count != remembered.count {
            UploadVars.shared.uploadedPasteboardImages = uploadedImages
        }
    }
    
    func uploadState(at position: Int) -> pwgUploadState? {
        guard position < pbObjects.count else { return nil }
        return uploadState(ofIdentifier: pbObjects[position].identifier, md5Sum: pbObjects[position].md5Sum)
    }
    
    /// Positions of the images which already have an upload request.
    func refreshQueuedPositions() {
        queuedPositions = IndexSet(pbObjects.indices.filter { uploadState(at: $0) != nil })
    }

    func getUploadStateOfImage(at index: Int,
                               for cell: LocalImageCollectionViewCell) -> pwgUploadState? {
        // By position: the checksum of a cell created before its file was prepared is still empty
        if index < pbObjects.count, pbObjects[index].identifier == cell.localIdentifier {
            return uploadState(at: index)
        }
        return uploadState(ofIdentifier: cell.localIdentifier, md5Sum: cell.md5sum)
    }
    
    /// State of the Select button of the section, from the selection and the images already in the upload queue
    func selectState() -> SelectButtonState {
        // The positions of the images in the upload queue are not known while objects are being prepared
        if pbObjects.isEmpty || !pendingOperations.preparationsInProgress.isEmpty { return .none }
        switch selection.selectState(of: 0..<pbObjects.count, queued: queuedPositions, reUploadAllowed: reUploadAllowed) {
        case .none:     return .none
        case .select:   return .select
        case .deselect: return .deselect
        }
    }
    
    func updateSelectButtonOfHeader() {
        let indexPath = IndexPath(item: 0, section: 0)
        if let header = localImagesCollection.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPath) as? PasteboardImagesHeaderReusableView {
            header.selectButton.setTitle(forState: selectState())
        }
    }
}


// MARK: - Uploads Provider NSFetchedResultsControllerDelegate
extension PasteboardImagesViewController: NSFetchedResultsControllerDelegate
{
    func controller(_ controller: NSFetchedResultsController<any NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

        switch type {
        case .insert:
            #if DEBUG
            debugPrint("••> PasteboardImagesViewController: insert pending upload request…")
            #endif
            // The image is no longer selected
            guard let upload:Upload = anObject as? Upload else { return }
            if let position = pbObjects.firstIndex(where: { $0.identifier == upload.localIdentifier }) {
                selection.remove(position)
            }
        case .delete:
            #if DEBUG
            debugPrint("••> PasteboardImagesViewController: delete pending upload request…")
            #endif
            // Remove the request from the upload requests being prepared if needed
            guard let upload:Upload = anObject as? Upload else { return }
            if let position = pbObjects.firstIndex(where: { $0.identifier == upload.localIdentifier }) {
                selection.remove(position)
            }
            uploadRequests.removeAll(where: {$0.localIdentifier == upload.localIdentifier})
        case .move:
            assertionFailure("••> PasteboardImagesViewController: Unexpected move!")
        case .update:
            #if DEBUG
            debugPrint("••• PasteboardImagesViewController controller:update...")
            #endif
        @unknown default:
            assertionFailure("••> PasteboardImagesViewController: unknown NSFetchedResultsChangeType!")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
        // States of the upload requests, once for all the changes of a batch
        refreshUploadStates()
        refreshQueuedPositions()
        
        // Update the cells shown, the Select button and the navigation bar
        for cell in localImagesCollection.visibleCells {
            guard let cell = cell as? LocalImageCollectionViewCell,
                  let indexPath = localImagesCollection.indexPath(for: cell) else { continue }
            cell.update(selected: selection.contains(indexPath.item),
                        state: getUploadStateOfImage(at: indexPath.item, for: cell))
        }
        updateSelectButtonOfHeader()
        updateNavBar()
    }
}
