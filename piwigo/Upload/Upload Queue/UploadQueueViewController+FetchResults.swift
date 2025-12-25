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
        
        // Loop over all items
        var snapshot = snapshot as Snaphot
        let currentSnapshot = dataSource.snapshot() as Snaphot
        var reloadIdentifiers: [NSManagedObjectID] = snapshot.itemIdentifiers
        snapshot.itemIdentifiers.forEach({ itemIdentifier in
            // Will this item keep the same indexPath?
            guard let currentRow = currentSnapshot.indexOfItem(itemIdentifier),
                  let row = snapshot.indexOfItem(itemIdentifier),
                  row == currentRow,
                  let currentSectionIdentifier = currentSnapshot.sectionIdentifier(containingItem: itemIdentifier),
                  let currentSection = currentSnapshot.indexOfSection(currentSectionIdentifier),
                  let sectionIdentifier = snapshot.sectionIdentifier(containingItem: itemIdentifier),
                  let section = snapshot.indexOfSection(sectionIdentifier),
                  section == currentSection
            else { return }
            reloadIdentifiers.removeAll(where: {$0 == itemIdentifier})
            // Update upload state
            let indexPath = IndexPath(row: row, section: section)
            if let upload = try? controller.managedObjectContext.existingObject(with: itemIdentifier) as? Upload,
               let cell = queueTableView.cellForRow(at: indexPath) as? UploadImageTableViewCell {
                // Only update label
                cell.uploadInfoLabel.text = upload.stateLabel
            }
        })

        // Any item to reload/reconfigure?
        if reloadIdentifiers.isEmpty == false {
            // Animate only a non-empty UI
            let shouldAnimate = queueTableView.numberOfSections != 0
            snapshot.reconfigureItems(Array(reloadIdentifiers))
            dataSource.apply(snapshot as Snaphot, animatingDifferences: shouldAnimate)
        }
        
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
