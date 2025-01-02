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
    @available(iOS 13.0, *)
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
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
            if #available(iOS 15.0, *) {
                snapshot.reconfigureItems(Array(reloadIdentifiers))
            } else {
                snapshot.reloadItems(Array(reloadIdentifiers))
            }
            dataSource.apply(snapshot as Snaphot, animatingDifferences: shouldAnimate)
        }
        
        // Update the navigation bar
        self.updateNavBar()
        
        // If all upload requests are done, delete all temporary files (in case some would not be deleted)
        if snapshot.numberOfItems == 0 {
            // Delete remaining files from Upload directory (if any)
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.deleteFilesInUploadsDirectory()
            }
            // Close the view when there is no more upload request to display
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    // Exclusively for iOS 12.x
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        queueTableView.beginUpdates()
    }
    
    // Exclusively for iOS 12.x
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        debugPrint("    > sectionInfo:", sectionInfo)

        switch type {
        case .insert:
            debugPrint("insert section… at", sectionIndex)
            queueTableView.insertSections(IndexSet(integer: sectionIndex), with: .automatic)
        case .delete:
            debugPrint("delete section… at", sectionIndex)
            queueTableView.deleteSections(IndexSet(integer: sectionIndex), with: .automatic)
        case .move, .update:
            fallthrough
        @unknown default:
                fatalError("UploadQueueViewControllerOld: unknown NSFetchedResultsChangeType")
        }
    }

    // Exclusively for iOS 12.x
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        switch type {
        case .insert:
            guard let newIndexPath = newIndexPath else { return }
            debugPrint("insert… at", newIndexPath)
            queueTableView.insertRows(at: [newIndexPath], with: .automatic)
        case .delete:
            guard let oldIndexPath = indexPath else { return }
            debugPrint("delete… at", oldIndexPath)
            queueTableView.deleteRows(at: [oldIndexPath], with: .automatic)
        case .move:
            guard let oldIndexPath = indexPath else { return }
            guard let newIndexPath = newIndexPath else { return }
            debugPrint("move… from", oldIndexPath, "to", newIndexPath)
            queueTableView.deleteRows(at: [oldIndexPath], with: .fade)
            queueTableView.insertRows(at: [newIndexPath], with: .fade)
        case .update:
            guard let oldIndexPath = indexPath, let upload = anObject as? Upload,
                  let cell = queueTableView.cellForRow(at: oldIndexPath) as? UploadImageTableViewCell
            else { return }
            debugPrint("update… at", oldIndexPath)
            if (newIndexPath == nil) || (newIndexPath == oldIndexPath) {        // Regular update
                cell.uploadInfoLabel.text = upload.stateLabel
                if [.preparingError, .preparingFail, .formatError,
                    .uploadingError, .uploadingFail, .finishingError].contains(upload.state) {
                    // Display error message
                    cell.imageInfoLabel.text = cell.errorDescription(for: upload)
                }
            } else {
                queueTableView.deleteRows(at: [oldIndexPath], with: .automatic)
                queueTableView.insertRows(at: [newIndexPath!], with: .automatic)
            }
        @unknown default:
            fatalError("UploadQueueViewControllerOld: unknown NSFetchedResultsChangeType")
        }
    }
    
    // Exclusively for iOS 12.x
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Perform tableView updates
        queueTableView.endUpdates()
        queueTableView.layoutIfNeeded()

        // If all upload requests are done, delete all temporary files (in case some would not be deleted)
        if (uploads.fetchedObjects ?? []).count == 0 {
            // Delete remaining files from Upload directory (if any)
            UploadManager.shared.deleteFilesInUploadsDirectory()
            // Close the view when there is no more upload request to display
            self.dismiss(animated: true, completion: nil)
        } else {
            updateNavBar()
        }
    }
}
