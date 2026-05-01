//
//  UploadQueueViewController+FetchResults.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 01/01/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import UIKit
import piwigoKit
import uploadKit

// MARK: - Uploads Provider NSFetchedResultsControllerDelegate
extension UploadQueueViewController: NSFetchedResultsControllerDelegate
{
    func controller(_ controller: NSFetchedResultsController<any NSFetchRequestResult>,
                    didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
        // Expected controller?
        guard controller == uploads else { return }
        
        // Data source configured?
        guard let dataSource = queueTableView.dataSource as? DataSource
        else { preconditionFailure("The data source has not implemented snapshot support while it should") }
        
        // Get old and new snapshots
        var newSnapshot = snapshot as Snapshot
        let currentSnapshot = dataSource.snapshot() as Snapshot
        
        // Find items that exist in both snapshots and stayed in same position, and have actually changed.
        var itemsToReconfigure: [NSManagedObjectID] = []
        for itemIdentifier in newSnapshot.itemIdentifiers {
            // Only reconfigure items that are already displayed (exist in the current snapshot)
            guard currentSnapshot.indexOfItem(itemIdentifier) != nil else {
                // New item — the diffable data source will insert it automatically.
                continue
            }
            
            // Check that the item hasn't moved to a different section or row.
            guard let currentRow = currentSnapshot.indexOfItem(itemIdentifier),
                  let row = newSnapshot.indexOfItem(itemIdentifier),
                  row == currentRow,
                  let currentSectionIdentifier = currentSnapshot.sectionIdentifier(containingItem: itemIdentifier),
                  let currentSection = currentSnapshot.indexOfSection(currentSectionIdentifier),
                  let sectionIdentifier = newSnapshot.sectionIdentifier(containingItem: itemIdentifier),
                  let section = newSnapshot.indexOfSection(sectionIdentifier),
                  section == currentSection
            else {
                // Item moved or is new - let diffable data source handle it via a reload/move.
                continue
            }
            
            // Only reconfigure if the underlying managed object actually has pending changes
            // (i.e. Core Data flagged it as updated in this save cycle). Without this guard
            // every stable cell is reconfigured on every notification, causing flicker.
            guard let upload = try? mainContext.existingObject(with: itemIdentifier) as? Upload,
                  upload.isUpdated || upload.hasChanges
            else { continue }
 
            // Mark for reconfiguration
            itemsToReconfigure.append(itemIdentifier)
        }
        
        // Reconfigure only the cells whose data has genuinely changed in place.
        if !itemsToReconfigure.isEmpty {
            newSnapshot.reconfigureItems(itemsToReconfigure)
        }
        
        // Apply the new snapshot (handles deletions, insertions, moves and the reconfigures above).
        let shouldAnimate = queueTableView.numberOfSections != 0
        dataSource.apply(newSnapshot, animatingDifferences: shouldAnimate)
        
        // Update the navigation bar
        self.updateNavBar()
        
        // If all upload requests are done, delete all temporary files (in case some would not be deleted)
        if snapshot.numberOfItems == 0 {
            // Delete remaining files from Upload directory (if any)
            Task { @UploadManagerActor in
                UploadManager.shared.deleteFilesInUploadsDirectory()
            }
            // Close the view when there is no more upload request to display
            self.dismiss(animated: true, completion: nil)
        }
    }
}
