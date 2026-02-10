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
        
        // Find items that exist in both snapshots and stayed in same position
        var itemsToReconfigure: [NSManagedObjectID] = []
        for itemIdentifier in newSnapshot.itemIdentifiers {
            // Check if item exists in current snapshot at same position
            guard let currentRow = currentSnapshot.indexOfItem(itemIdentifier),
                  let row = newSnapshot.indexOfItem(itemIdentifier),
                  row == currentRow,
                  let currentSectionIdentifier = currentSnapshot.sectionIdentifier(containingItem: itemIdentifier),
                  let currentSection = currentSnapshot.indexOfSection(currentSectionIdentifier),
                  let sectionIdentifier = newSnapshot.sectionIdentifier(containingItem: itemIdentifier),
                  let section = newSnapshot.indexOfSection(sectionIdentifier),
                  section == currentSection
            else {
                // Item moved or is new - let diffable data source handle it
                continue
            }
            
            // Mark for reconfiguration
            itemsToReconfigure.append(itemIdentifier)
        }

        // Reconfigure items that stayed in place
        if !itemsToReconfigure.isEmpty {
            newSnapshot.reconfigureItems(itemsToReconfigure)
        }

        // Apply the new snapshot (this handles deletions, insertions, moves)
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
