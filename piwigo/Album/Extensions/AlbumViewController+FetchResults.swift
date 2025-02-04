//
//  AlbumViewController+FetchResults.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import piwigoKit
import UIKit

// MARK: NSFetchedResultsControllerDelegate Methods
extension AlbumViewController: NSFetchedResultsControllerDelegate
{
    @available(iOS 13.0, *)
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                    didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
        // Data source configured?
        guard let dataSource = collectionView?.dataSource as? DataSource
        else {
            debugPrint("The data source has not implemented snapshot support while it should.")
            return
        }
        
        // Album or Image controller?
        let snapshot = snapshot as Snaphot
        var currentSnapshot = dataSource.snapshot() as Snaphot
        var updatedItems = Set<NSManagedObjectID>()
        if controller == albums {
            // Remove existing album section if any
            if let firstSection = currentSnapshot.sectionIdentifiers.first,
               firstSection == pwgAlbumGroup.none.sectionKey {
                // Remember old items
                updatedItems = Set(currentSnapshot.itemIdentifiers(inSection: firstSection))
                // Delete album section
                currentSnapshot.deleteSections([pwgAlbumGroup.none.sectionKey])
            }
            
            // Add new non-empty sub-album section ID
            if snapshot.itemIdentifiers.count > 0 {
                // Add album section in front position
                if let firstSection = currentSnapshot.sectionIdentifiers.first {
                    currentSnapshot.insertSections(snapshot.sectionIdentifiers, beforeSection: firstSection)
                } else {
                    currentSnapshot.appendSections(snapshot.sectionIdentifiers)
                }
                // Add sub-album IDs
                currentSnapshot.appendItems(snapshot.itemIdentifiers, toSection: pwgAlbumGroup.none.sectionKey)
            }
            
            // Update non-inserted, moved or deleted visible cells
            updatedItems.formIntersection(snapshot.itemIdentifiers)
            collectionView.indexPathsForVisibleItems.forEach { indexPath in
                if let objectID = diffableDataSource.itemIdentifier(for: indexPath), updatedItems.contains(objectID),
                   let album = try? self.mainContext.existingObject(with: objectID) as? Album {
                    if let cell = collectionView.cellForItem(at: indexPath) as? AlbumCollectionViewCellOld {
                        cell.albumData = album
                    } else if let cell = collectionView.cellForItem(at: indexPath) as? AlbumCollectionViewCell {
                        cell.config(withAlbumData: album)
                    }
                }
            }
        }
        else if controller == images {
            // Remove existing image sections if any
            let sectionsToRemove = currentSnapshot.sectionIdentifiers.filter({ $0 != pwgAlbumGroup.none.sectionKey })
            sectionsToRemove.forEach { sectionID in
                // Remember old items
                updatedItems.formUnion(Set(currentSnapshot.itemIdentifiers(inSection: sectionID)))
            }
            currentSnapshot.deleteSections(sectionsToRemove)
            
            // Append new non-empty image sections
            currentSnapshot.appendSections(snapshot.sectionIdentifiers)
            for sectionID in snapshot.sectionIdentifiers {
                currentSnapshot.appendItems(snapshot.itemIdentifiers(inSection: sectionID), toSection: sectionID)
            }

            // Update non-inserted, moved or deleted visible cells
            updatedItems.formIntersection(snapshot.itemIdentifiers)
            collectionView.indexPathsForVisibleItems.forEach { indexPath in
                if let objectID = diffableDataSource.itemIdentifier(for: indexPath), updatedItems.contains(objectID),
                   let image = try? self.mainContext.existingObject(with: objectID) as? Image,
                   let cell = collectionView.cellForItem(at: indexPath) as? ImageCollectionViewCell {
                    // Update image title
                    cell.config(withImageData: image, size: self.imageSize, sortOption: self.sortOption)

                    // pwg.users.favorites… methods available from Piwigo version 2.10
                    if hasFavorites {
                        cell.isFavorite = (image.albums ?? Set<Album>())
                            .contains(where: {$0.pwgID == pwgSmartAlbum.favorites.rawValue})
                    }
                }
            }
        }
        
        // Animate only a non-empty UI
        let shouldAnimate = (collectionView?.numberOfSections ?? 0) != 0
        dataSource.apply(currentSnapshot as Snaphot, animatingDifferences: shouldAnimate)
        
        // Update headers if needed
        self.updateHeaders()

        // Update footer if needed
        self.updateNberOfImagesInFooter()

        // Show/hide "No album in your Piwigo" (e.g. after clearing the cache)
        let hasItems = currentSnapshot.numberOfItems != 0
        noAlbumLabel.isHidden = hasItems

        // Disable menu if there are no more images
        if self.categoryId != 0, self.albumData.nbImages == 0 {
            self.isSelect = false
            self.initBarsInPreviewMode()
        }
    }

    // Exclusively for iOS 12.x
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Reset operation list
        updateOperations = []
        // Ensure that the layout is updated before calling performBatchUpdates(_:completion:)
        collectionView?.layoutIfNeeded()
    }
    
    // Exclusively for iOS 12.x
    func controller(_ controller: NSFetchedResultsController<any NSFetchRequestResult>, didChange sectionInfo: any NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        
        // Collect operation changes
        switch controller {
        case albums:
            break
        case images:
            let collectionSectionIndex = sectionIndex + 1
            switch type {
            case .insert:
                updateOperations.append( BlockOperation { [weak self] in
                    guard let self = self else { return }
//                    debugPrint("••> Insert image section #\(collectionSectionIndex)")
                    self.collectionView?.insertSections(IndexSet(integer: collectionSectionIndex))
                })
            case .delete:
                updateOperations.append( BlockOperation { [weak self] in
                    guard let self = self else { return }
//                    debugPrint("••> Delete image section #\(collectionSectionIndex)")
                    self.collectionView?.deleteSections(IndexSet(integer: collectionSectionIndex))
                })
            case .move:
//                debugPrint("••> Move image section #\(collectionSectionIndex)")
            case .update:
//                debugPrint("••> Update image section #\(collectionSectionIndex)")
            @unknown default:
                assertionFailure("Unknown NSFetchedResultsChangeType of section in AlbumViewController")
            }
        default:
            return
        }
    }
    
    // Exclusively for iOS 12.x
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        // Collect operation changes
        switch controller {
        case albums:
            switch type {
            case .insert:
                guard let newIndexPath = newIndexPath else { return }
                updateOperations.append( BlockOperation { [weak self] in
                    guard let self = self else { return }
//                    debugPrint("••> Insert sub-album at \(newIndexPath) of album #\(self.categoryId)")
                    self.collectionView?.insertItems(at: [newIndexPath])
                })
            case .delete:
                guard let indexPath = indexPath else { return }
                updateOperations.append( BlockOperation { [weak self] in
                    guard let self = self else { return }
//                    debugPrint("••> Delete sub-album at \(indexPath) of album #\(self.categoryId)")
                    self.collectionView?.deleteItems(at: [indexPath])
                })
            case .move:
                guard let indexPath = indexPath, let newIndexPath = newIndexPath,
                      indexPath != newIndexPath else { return }
                updateOperations.append( BlockOperation { [weak self] in
                    guard let self = self else { return }
//                    debugPrint("••> Move sub-album of album #\(self.categoryId) from \(indexPath) to \(newIndexPath)")
                    self.collectionView?.moveItem(at: indexPath, to: newIndexPath)
                })
            case .update:
                guard let indexPath = indexPath else { return }
                updateOperations.append( BlockOperation {  [weak self] in
                    guard let self = self else { return }
//                    debugPrint("••> Update sub-album at \(indexPath) of album #\(self.categoryId)")
                    self.collectionView?.reloadItems(at: [indexPath])
                })
            @unknown default:
                debugPrint("Unknown NSFetchedResultsChangeType of object in AlbumViewController")
            }
        case images:
            switch type {
            case .insert:
                guard var newIndexPath = newIndexPath, anObject is Image
                else { return }
                newIndexPath.section += 1
                updateOperations.append( BlockOperation { [weak self] in
                    // Insert image
                    guard let self = self else { return }
//                    debugPrint("••> Insert image of album #\(self.categoryId) at \(newIndexPath)")
                    self.collectionView?.insertItems(at: [newIndexPath])
                    // Enable menu if this is the first added image
                    if self.albumData.nbImages == 1 {
                        debugPrint("••> First added image ► enable menu")
                        self.initBarsInPreviewMode()
                    }
                })
            case .delete:
                guard var indexPath = indexPath, let image = anObject as? Image
                else { return }
                indexPath.section += 1
                // Deselect image
                selectedImageIDs.remove(image.pwgID)
                selectedFavoriteIDs.remove(image.pwgID)
                selectedVideosIDs.remove(image.pwgID)
                // Delete image
                updateOperations.append( BlockOperation {  [weak self] in
                    guard let self = self else { return }
//                    debugPrint("••> Delete image of album #\(self.categoryId) at \(indexPath)")
                    self.collectionView?.deleteItems(at: [indexPath])
                })
            case .move:
                guard var indexPath = indexPath, var newIndexPath = newIndexPath,
                      anObject is Image else { return }
                indexPath.section += 1
                newIndexPath.section += 1
                // Move image
                updateOperations.append( BlockOperation {  [weak self] in
                    guard let self = self else { return }
//                    debugPrint("••> Move item of album #\(self.categoryId) from \(indexPath) to \(newIndexPath)")
                    self.collectionView?.moveItem(at: indexPath, to: newIndexPath)
                })
            case .update:
                guard var indexPath = indexPath, let image = anObject as? Image
                else { return }
                indexPath.section += 1
                // Update image
                updateOperations.append( BlockOperation { [weak self] in
                    guard let self = self else { return }
//                    debugPrint("••> Update image at \(indexPath) of album #\(self.categoryId)")
                    if let cell = self.collectionView?.cellForItem(at: indexPath) as? ImageCollectionViewCell {
                        // Re-configure image cell
                        cell.config(withImageData: image, size: self.imageSize, sortOption: self.sortOption)
                        // pwg.users.favorites… methods available from Piwigo version 2.10
                        if hasFavorites {
                            cell.isFavorite = (image.albums ?? Set<Album>())
                                .contains(where: {$0.pwgID == pwgSmartAlbum.favorites.rawValue})
                        }
                    }
                })
            @unknown default:
                debugPrint("Unknown NSFetchedResultsChangeType of object in AlbumViewController")
            }
        default:
            return
        }
    }
    
    // Exclusively for iOS 12.x
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Update objects in a single animated operation
        collectionView?.performBatchUpdates({ [weak self] in
            guard let self = self else { return }
            self.updateOperations.forEach({ $0.start()})
        }) { [weak self] _ in
            guard let self = self else { return }
            // Update headers if needed
            self.updateHeaders()
            // Update footer
            self.updateNberOfImagesInFooter()
            // Disable menu if no image left
            if self.categoryId != 0, self.albumData.nbImages == 0 {
//                debugPrint("••> No image ► disable menu")
                self.isSelect = false
                self.initBarsInPreviewMode()
            }
        }
    }
}
