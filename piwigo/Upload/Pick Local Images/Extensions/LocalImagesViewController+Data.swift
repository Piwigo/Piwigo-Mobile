//
//  LocalImagesViewController+Data.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/03/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import CoreData
import Photos
import UIKit
import PwgKit
import PwgCacheKit
import PwgUploadKit
import PwgUIKit

// MARK: - Fetch Images
extension LocalImagesViewController
{
    func fetchImagesByCreationDate() -> Void {
        /**
         Fetch non-empty collection previously selected by user.
         We fetch a specific path of the Photo Library to reduce the workload and store the fetched collection for future use.
         The fetch is performed with descending creation date: an image is identified by its position in this
         collection, position 0 being the newest image.
         NB: do not add a predicate (e.g. on the media type): the fetch takes 8 times longer.
         */
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeHiddenAssets = false
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: #keyPath(PHAsset.creationDate), ascending: false)]

        // Fetch image collection
        let assetCollections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [self.imageCollectionId], options: nil)
                
        // Fetch images in album
        fetchedImages = PHAsset.fetchAssets(in: assetCollections.firstObject!, options: fetchOptions)
        assetCache.removeAllObjects()

        // Measured on an iPhone 16 Pro (iOS 27): 104,322 images fetched in 0.15 s
    }
    
    
    // MARK: - Sections
    /// Updates the sections shown, from the grouping and the sort order in use. The sections are an immutable value:
    /// the collection view reads it as a whole, it is never half updated.
    func updateLayout() {
        let count = fetchedImages?.count ?? 0
        let newestFirst = UploadVars.shared.localImagesSort != .dateCreatedAscending
        let ranges: [Range<Int>]
        switch sortType {
        case .none:
            ranges = [0..<count]
        case .day:
            ranges = layouts?.day ?? [0..<count]
        case .week:
            ranges = layouts?.week ?? [0..<count]
        case .month:
            ranges = layouts?.month ?? [0..<count]
        }
        layout = PhotoLibraryLayout(ranges: ranges, newestFirst: newestFirst)
        appliedGrouping = (sortType != .none && layouts == nil) ? .none : sortType
    }
    
    /// Position in the collection of the image shown at an index path, which depends on the grouping and the sort order
    func getImageIndex(for indexPath: IndexPath) -> Int {
        return layout.assetIndex(section: indexPath.section, item: indexPath.item)
    }
    
    /// The asset at a position. A cold read of a PHFetchResult loads a batch of 200 assets (4 to 12 ms): the
    /// prefetching of the collection view reads the assets ahead of the cells and keeps them here.
    func asset(at index: Int) -> PHAsset {
        if let asset = assetCache.object(forKey: index as NSNumber) { return asset }
        let asset = fetchedImages[index]
        assetCache.setObject(asset, forKey: index as NSNumber)
        return asset
    }
    
    /// Scrolls to an image after the sections changed
    func scrollTo(imageAt index: Int, animated: Bool = false) {
        guard let position = layout.position(ofAssetAt: index),
              position.section < localImagesCollection.numberOfSections,
              position.item < localImagesCollection.numberOfItems(inSection: position.section)
        else { return }
        localImagesCollection.scrollToItem(at: IndexPath(item: position.item, section: position.section),
                                           at: .top, animated: animated)
    }
    
    /// Index of the image shown at the top of the collection view
    func indexOfFirstVisibleImage() -> Int? {
        let first = localImagesCollection.visibleCells
            .compactMap { cell -> (IndexPath, CGRect)? in
                guard let indexPath = localImagesCollection.indexPath(for: cell) else { return nil }
                return (indexPath, cell.frame)
            }
            .min { ($0.1.minY, $0.1.minX) < ($1.1.minY, $1.1.minX) }
        guard let indexPath = first?.0 else { return nil }
        return getImageIndex(for: indexPath)
    }
    
    
    // MARK: - Prepare Data in the Background
    /// Starts the background jobs which complete the images shown at once: the sections of the groupings by day,
    /// week and month, and the positions of the images which already have an upload request.
    func startPreparation() {
        cancelPreparation()
        generation += 1
        let generation = self.generation
        let assets = PhotoLibraryAssets(fetchedImages)
        let collectionID = imageCollectionId
        
        // Sections of the groupings, built in windows of dates on two threads (about 1 s for 100,000 images)
        layouts = nil
        layoutsTask = Task { [weak self] in
            let built = await PhotoLibraryLayoutBuilder.build(inCollectionWithIdentifier: collectionID,
                                                              expectedCount: assets.count)
            guard !Task.isCancelled, let self, let built, self.generation == generation else { return }
            self.layouts = built
            self.didBuildSections()
        }
        
        // The images are shown ungrouped until the sections of the grouping chosen last time are ready:
        // tell the user that the final view is being prepared if it takes time
        showHUDIfSectionsAreLate()
        
        // Positions of the images which already have an upload request
        isIndexingUploads = true
        uploadPositions = [:]
        queuedPositions = IndexSet()
        deletableUploads = []
        uploadsOutsideAlbum = []
        resolvingUploads = []
        let identifiers = Array(uploadStates.keys)
        uploadsTask = Task { [weak self] in
            let found = await assets.positions(ofAssetsWithIdentifiers: identifiers)
            guard !Task.isCancelled, let self, let found, self.generation == generation else { return }
            self.uploadPositions = found.positions
            self.queuedPositions = IndexSet(found.positions.values)
            self.deletableUploads = found.deletable
            self.uploadsOutsideAlbum = Set(identifiers).subtracting(found.positions.keys)
            self.isIndexingUploads = false
            self.didIndexUploads()
        }
    }
    
    /// Stops the jobs which complete the images shown. A job preparing a change of the Photo Library is not stopped
    /// when the view disappears: it is short and its result is simply shown when ready.
    /// Shows the HUD if the sections of the grouping wanted are still not built after a short delay (they take
    /// about a second for 100,000 images), so that a fast build does not make it flash.
    private func showHUDIfSectionsAreLate(afterMilliseconds delay: UInt64 = 300) {
        guard sortType != .none, appliedGrouping != sortType else { return }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay * 1_000_000)
            guard let self, self.appliedGrouping != self.sortType, self.layouts == nil,
                  !self.isShowingHUD() else { return }
            self.isWaitingForSections = true
            self.showHUD(withTitle: String(localized: "editImageDetailsHUD_updatingPlural", comment: "Updating Photos…"))
            self.updateActionButton()
        }
    }
    
    func cancelPreparation() {
        layoutsTask?.cancel()
        uploadsTask?.cancel()
    }
    
    private func didBuildSections() {
        // Is the grouping shown the one wanted? Not if it was chosen before its sections were available,
        // by the user or by the last visit: the images were shown ungrouped meanwhile.
        guard appliedGrouping != sortType else { return }
        isWaitingForSections = false
        Task { [weak self] in
            await self?.hideHUD()
            self?.reloadCollectionAndUpdateMenu()
        }
    }
    
    private func didIndexUploads() {
        // Uploads requested in the meantime?
        resolveMissingUploads()
        
        // Enable the Select buttons and the menu entries which need the positions
        updateActionButton()
        updateNavBar()
        updateVisibleSelectButtons()
    }
    
    /// Looks for the position of the images whose upload request was created after the positions were searched,
    /// and deselects them.
    func resolveMissingUploads() {
        guard !isIndexingUploads else { return }
        let missing = uploadStates.keys.filter {
            uploadPositions[$0] == nil && !uploadsOutsideAlbum.contains($0) && !resolvingUploads.contains($0)
        }
        guard !missing.isEmpty else { return }
        resolvingUploads.formUnion(missing)
        let assets = PhotoLibraryAssets(fetchedImages)
        let generation = self.generation
        Task { [weak self] in
            let found = await assets.positions(ofAssetsWithIdentifiers: missing)
            guard let self, self.generation == generation else { return }
            self.resolvingUploads.subtract(missing)
            guard let found else { return }
            for (identifier, position) in found.positions where self.uploadStates[identifier] != nil {
                self.uploadPositions[identifier] = position
                self.queuedPositions.insert(position)
                self.selection.remove(position)
            }
            self.deletableUploads.formUnion(found.deletable)
            self.uploadsOutsideAlbum.formUnion(Set(missing).subtracting(found.positions.keys))
            self.updateVisibleCells()
            self.updateVisibleSelectButtons()
            self.updateActionButton()
            self.updateNavBar()
        }
    }
    
    
    // MARK: - Photo Library Changes
    /// Prepares the data of a new fetch of the album, in the background, and shows it all at once when it is ready:
    /// the sections, the positions of the uploaded or queued images and the selection, which refer to positions.
    func applyChange(to newImages: PHFetchResult<PHAsset>) {
        changeTask?.cancel()
        cancelPreparation()
        generation += 1
        let generation = self.generation
        let oldAssets = PhotoLibraryAssets(fetchedImages)
        let newAssets = PhotoLibraryAssets(newImages)
        let oldSelection = selection.positions
        let collectionID = imageCollectionId
        let identifiers = Array(uploadStates.keys)
        changeTask = Task { [weak self] in
            async let built = PhotoLibraryLayoutBuilder.build(inCollectionWithIdentifier: collectionID,
                                                              expectedCount: newAssets.count)
            async let found = newAssets.positions(ofAssetsWithIdentifiers: identifiers)
            async let remapped = oldAssets.remap(oldSelection, in: newAssets)
            let (layouts, positions, remappedPositions) = await (built, found, remapped)
            guard !Task.isCancelled, let self, self.generation == generation,
                  let layouts, let positions, let remappedPositions else { return }
            let newSelection = IndexSet(remappedPositions)
            
            // Show the new images
            self.fetchedImages = newImages
            self.assetCache.removeAllObjects()
            self.layouts = layouts
            self.selection = PhotoLibrarySelection(positions: newSelection)
            self.uploadPositions = positions.positions.filter { self.uploadStates[$0.key] != nil }
            self.queuedPositions = IndexSet(self.uploadPositions.values)
            self.deletableUploads = positions.deletable
            self.uploadsOutsideAlbum = Set(identifiers).subtracting(positions.positions.keys)
            self.resolvingUploads = []
            self.isIndexingUploads = false
            self.isWaitingForSections = false
            let anchor = self.indexOfFirstVisibleImage()
            self.updateLayout()
            await self.hideHUD()
            guard self.generation == generation else { return }
            self.resolveMissingUploads()
            self.updateActionButton()
            self.updateNavBar()
            self.localImagesCollection.reloadData()
            if let anchor { self.scrollTo(imageAt: min(anchor, max(0, newImages.count - 1))) }
        }
    }
    
    
    // MARK: - Upload States
    /// State of the upload request of each asset by local identifier. Both halves of a Live Photo share an identifier:
    /// the one which is not finished is kept, since it is the one the cell must follow.
    func currentUploadStates() -> [String: pwgUploadState] {
        var states = [String: pwgUploadState]()
        for upload in uploads.fetchedObjects ?? [] {
            if let known = states[upload.localIdentifier], ![.finished, .moderated].contains(known) { continue }
            states[upload.localIdentifier] = upload.state
        }
        return states
    }
    
    func getUploadStateOfImage(at index: Int,
                               for cell: LocalImageCollectionViewCell) -> pwgUploadState? {
        return uploadStates[cell.localIdentifier]
    }
    
    /// Updates the cells shown (selection and upload state)
    func updateVisibleCells() {
        for cell in localImagesCollection.visibleCells {
            guard let cell = cell as? LocalImageCollectionViewCell,
                  let indexPath = localImagesCollection.indexPath(for: cell) else { continue }
            let index = getImageIndex(for: indexPath)
            cell.update(selected: selection.contains(index), state: uploadStates[cell.localIdentifier])
        }
    }
    
    /// Updates the Select buttons of the section headers shown
    func updateVisibleSelectButtons() {
        let headers = localImagesCollection.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader)
        for case let header as LocalImagesHeaderReusableView in headers {
            header.selectButton.setTitle(forState: updateSelectButton(ofSection: header.section))
        }
    }
}


// MARK: - Uploads Provider NSFetchedResultsControllerDelegate
extension LocalImagesViewController: NSFetchedResultsControllerDelegate
{
    func controller(_ controller: NSFetchedResultsController<any NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

        switch type {
        case .insert, .move, .update:
            // Add or update the state of the upload request, and update the cell
            // (a move means that the user is trying re-uploading)
            guard let upload:Upload = anObject as? Upload else { return }
            if type == .insert {
                // The image is no longer selected, whether we know its position yet or not
                if let position = uploadPositions[upload.localIdentifier] {
                    selection.remove(position)
                }
            }
            uploadStates[upload.localIdentifier] = upload.state
            updateCellAndSectionHeader(for: upload)
        case .delete:
            // Delete upload request from cache and update cell
            guard let upload:Upload = anObject as? Upload else { return }

            // Both halves of a Live Photo share this localIdentifier, and the photo is uploaded
            // before its video. The cell must therefore follow the half which is still on its way
            // instead of adopting the completed state of this one, which would hide the progress
            // bar and show the uploaded badge while the video half is still being uploaded.
            /// The deleted request may still be among the fetched objects at this point.
            let remainingHalf = (uploads.fetchedObjects ?? []).first(where: {
                $0.localIdentifier == upload.localIdentifier && $0.objectID != upload.objectID })
            if let half = remainingHalf {
                uploadStates[upload.localIdentifier] = half.state
            } else {
                // Forget the image and deselect it
                uploadStates[upload.localIdentifier] = nil
                if let position = uploadPositions.removeValue(forKey: upload.localIdentifier) {
                    queuedPositions.remove(position)
                    selection.remove(position)
                }
                deletableUploads.remove(upload.localIdentifier)
                uploadsOutsideAlbum.remove(upload.localIdentifier)
            }
            updateCellAndSectionHeader(for: remainingHalf ?? upload)
        @unknown default:
            assertionFailure("••> LocalImagesViewController: unknown NSFetchedResultsChangeType!")
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
        // Find the position of the new upload requests
        resolveMissingUploads()
        
        // Update navigation bar
        updateActionButton()
        updateNavBar()
    }

    func updateCellAndSectionHeader(for upload: Upload) {
        DispatchQueue.main.async {
            if let visibleCells = self.localImagesCollection.visibleCells as? [LocalImageCollectionViewCell],
               let cell = visibleCells.first(where: {$0.localIdentifier == upload.localIdentifier}),
               let indexPath = self.localImagesCollection.indexPath(for: cell) {
                // Update cell
                cell.update(selected: self.selection.contains(self.getImageIndex(for: indexPath)),
                            state: self.uploadStates[upload.localIdentifier])

                // The section will be refreshed only if the button content needs to be changed
                let selectState = self.updateSelectButton(ofSection:  indexPath.section)
                let indexPathOfHeader = IndexPath(item: 0, section: indexPath.section)
                if let header = self.localImagesCollection.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPathOfHeader) as? LocalImagesHeaderReusableView {
                    header.selectButton.setTitle(forState: selectState)
                }
            }
        }
    }
}
