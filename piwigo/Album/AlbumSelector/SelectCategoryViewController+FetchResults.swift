//
//  SelectCategoryViewController+FetchResults.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 01/01/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import UIKit
import piwigoKit

// MARK: - NSFetchedResultsControllerDelegate
extension SelectCategoryViewController: NSFetchedResultsControllerDelegate
{
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                    didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
//        // Expected controller?
//        guard controller == uploads else { return }
//        
//        // Data source configured?
//        guard let dataSource = queueTableView.dataSource as? UITableViewDiffableDataSource<String, NSManagedObjectID>
//        else { preconditionFailure("The data source has not implemented snapshot support while it should") }
//        
//        // Loop over all items
//        var snapshot = snapshot as NSDiffableDataSourceSnapshot<String, NSManagedObjectID>
//        let currentSnapshot = dataSource.snapshot() as NSDiffableDataSourceSnapshot<String, NSManagedObjectID>
//        var reloadIdentifiers: [NSManagedObjectID] = snapshot.itemIdentifiers
//        snapshot.itemIdentifiers.forEach({ itemIdentifier in
//            // Will this item keep the same indexPath?
//            guard let currentRow = currentSnapshot.indexOfItem(itemIdentifier),
//                  let row = snapshot.indexOfItem(itemIdentifier),
//                  row == currentRow,
//                  let currentSectionIdentifier = currentSnapshot.sectionIdentifier(containingItem: itemIdentifier),
//                  let currentSection = currentSnapshot.indexOfSection(currentSectionIdentifier),
//                  let sectionIdentifier = snapshot.sectionIdentifier(containingItem: itemIdentifier),
//                  let section = snapshot.indexOfSection(sectionIdentifier),
//                  section == currentSection
//            else { return }
//            reloadIdentifiers.removeAll(where: {$0 == itemIdentifier})
//            // Update upload state
//            let indexPath = IndexPath(row: row, section: section)
//            if let upload = try? controller.managedObjectContext.existingObject(with: itemIdentifier) as? Upload,
//               let cell = queueTableView.cellForRow(at: indexPath) as? UploadImageTableViewCell {
//                // Only update label
//                cell.uploadInfoLabel.text = upload.stateLabel
//            }
//        })
//
//        // Any item to reload/reconfigure?
//        if reloadIdentifiers.isEmpty == false {
//            // Animate only a non-empty UI
//            let shouldAnimate = queueTableView.numberOfSections != 0
//            snapshot.reconfigureItems(Array(reloadIdentifiers))
//            dataSource.apply(snapshot as NSDiffableDataSourceSnapshot<String, NSManagedObjectID>,
//                             animatingDifferences: shouldAnimate)
//        }
//        
//        // Update the navigation bar
//        self.updateNavBar()
//        
//        // If all upload requests are done, delete all temporary files (in case some would not be deleted)
//        if snapshot.numberOfItems == 0 {
//            // Delete remaining files from Upload directory (if any)
//            UploadManager.shared.backgroundQueue.async {
//                UploadManager.shared.deleteFilesInUploadsDirectory()
//            }
//            // Close the view when there is no more upload request to display
//            self.dismiss(animated: true, completion: nil)
//        }
    }
    
    // Exclusively for iOS 12.x
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Check that this update should be managed by this view controller
        if (wantedAction == .setAlbumThumbnail) && (controller == recentAlbums) {
            return
        }
        // Reset operation list
        updateOperations = []
        // Begin the update
        categoriesTableView?.beginUpdates()
    }
    
    // Exclusively for iOS 12.x
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

        // Check that this update should be managed by this view controller
        if (wantedAction == .setAlbumThumbnail) && (controller == recentAlbums) {
            return
        }

        // Initialisation
        var hasAlbumsInSection1 = false
        if controller == albums, categoriesTableView.numberOfSections == 2 {
            hasAlbumsInSection1 = true
        }

        // Collect operation changes
        switch type {
        case .insert:
            guard var newIndexPath = newIndexPath else { return }
            if hasAlbumsInSection1 { newIndexPath.section = 1 }
            updateOperations.append( BlockOperation { [weak self] in
                debugPrint("••> Insert category item at \(newIndexPath)")
                self?.categoriesTableView?.insertRows(at: [newIndexPath], with: .automatic)
            })
        case .update:
            guard var indexPath = indexPath else { return }
            if hasAlbumsInSection1 { indexPath.section = 1 }
            updateOperations.append( BlockOperation {  [weak self] in
                debugPrint("••> Update category item at \(indexPath)")
                self?.categoriesTableView?.reloadRows(at: [indexPath], with: .automatic)
            })
        case .move:
            guard var indexPath = indexPath,  var newIndexPath = newIndexPath else { return }
            if hasAlbumsInSection1 {
                indexPath.section = 1
                newIndexPath.section = 1
            }
            updateOperations.append( BlockOperation { [weak self] in
                debugPrint("••> Move category item from \(indexPath) to \(newIndexPath)")
                self?.categoriesTableView?.moveRow(at: indexPath, to: newIndexPath)
            })
        case .delete:
            guard var indexPath = indexPath else { return }
            if hasAlbumsInSection1 { indexPath.section = 1 }
            updateOperations.append( BlockOperation { [weak self] in
                debugPrint("••> Delete category item at \(indexPath)")
                self?.categoriesTableView?.deleteRows(at: [indexPath], with: .automatic)
            })
        @unknown default:
            debugPrint("SelectCategoryViewController: unknown NSFetchedResultsChangeType")
        }
    }
    
    // Exclusively for iOS 12.x
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Check that this update should be managed by this view controller
        if (wantedAction == .setAlbumThumbnail) && (controller == recentAlbums) {
            return
        }

        // Perform all updates
        categoriesTableView?.performBatchUpdates { [weak self] in
            self?.updateOperations.forEach { $0.start() }
        }
        
        // End updates
        categoriesTableView?.endUpdates()
    }
}
