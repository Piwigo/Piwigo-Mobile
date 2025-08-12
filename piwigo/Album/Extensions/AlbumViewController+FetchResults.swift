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
                    if let cell = collectionView.cellForItem(at: indexPath) as? AlbumCollectionViewCell {
                        cell.config(withAlbumData: album)
                    }
                    else if let cell = collectionView.cellForItem(at: indexPath) as? AlbumCollectionViewCellOld {
                        cell.tableView?.reloadData()
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
                    cell.config(withImageData: image, size: self.imageSize, sortOption: self.sortOption)
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
        let hasItems = (categoryId == pwgSmartAlbum.search.rawValue) || (currentSnapshot.numberOfItems != 0)
        noAlbumLabel.isHidden = hasItems
        
        // Disable menu if there are no more images
        if self.categoryId != 0, self.albumData.nbImages == 0 {
            self.inSelectionMode = false
            self.initBarsInPreviewMode()
            self.setTitleViewFromAlbumData()
        }
    }
}
