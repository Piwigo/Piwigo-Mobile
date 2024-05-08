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

// MARK: - NSFetchedResultsControllerDelegate
extension AlbumViewController: NSFetchedResultsControllerDelegate
{
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Check that this update should be managed by this view controller
        if view.window == nil || [images, albums].contains(controller) == false { return }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        // Check that this update should be managed by this view controller
        guard let fetchDelegate = controller.delegate as? AlbumViewController else { return }
        if view.window == nil || [images, albums].contains(controller) == false { return }
        // Collect operation changes
        switch type.rawValue {
        case NSFetchedResultsChangeType.delete.rawValue:
            guard var indexPath = indexPath else { return }
            if let image = anObject as? Image {
                indexPath.section = 1
                selectedImageIds.remove(image.pwgID)
            }
            updateOperations.append( BlockOperation {  [weak self] in
//                debugPrint("••> Delete item of album #\(fetchDelegate.categoryId) at \(indexPath)")
                self?.collectionView.deleteItems(at: [indexPath])
            })
            // Disable menu if this is the last deleted image
            if albumData.nbImages == 0 {
                updateOperations.append( BlockOperation { [weak self] in
//                    debugPrint("••> Last removed image ► disable menu")
                    self?.isSelect = false
                    self?.initBarsInPreviewMode()
                })
            }
        case NSFetchedResultsChangeType.update.rawValue:
            guard let indexPath = indexPath else { return }
            if let image = anObject as? Image {
                let cellIndexPath = IndexPath(item: indexPath.item, section: 1)
                updateOperations.append( BlockOperation {  [self] in
//                    debugPrint("••> Update image at \(cellIndexPath) of album #\(fetchDelegate.categoryId)")
                    if let cell = self.collectionView.cellForItem(at: cellIndexPath) as? ImageCollectionViewCell {
                        // Re-configure image cell
                        cell.config(with: image, placeHolder: self.imagePlaceHolder, size: self.imageSize)
                        // pwg.users.favorites… methods available from Piwigo version 2.10
                        if hasFavorites {
                            cell.isFavorite = (image.albums ?? Set<Album>())
                                .contains(where: {$0.pwgID == pwgSmartAlbum.favorites.rawValue})
                        }
                    }
                })
            } else if let album = anObject as? Album {
                updateOperations.append( BlockOperation {  [weak self] in
//                    debugPrint("••> Update album at \(indexPath) of album #\(fetchDelegate.categoryId)")
                    if let cell = self?.collectionView.cellForItem(at: indexPath) as? AlbumCollectionViewCell {
                        // Re-configure album cell
                        cell.albumData = album
                    }
                })
            }
        case NSFetchedResultsChangeType.insert.rawValue:
            guard var newIndexPath = newIndexPath else { return }
            if anObject is Image { newIndexPath.section = 1 }
            updateOperations.append( BlockOperation { [weak self] in
//                debugPrint("••> Insert item of album #\(fetchDelegate.categoryId) at \(newIndexPath)")
                self?.collectionView.insertItems(at: [newIndexPath])
            })
            // Enable menu if this is the first added image
            if albumData.nbImages == 1 {
                updateOperations.append( BlockOperation { [weak self] in
//                    debugPrint("••> First added image ► enable menu")
                    self?.initBarsInPreviewMode()
                })
            }
        case NSFetchedResultsChangeType.move.rawValue:
            guard var indexPath = indexPath,
                  var newIndexPath = newIndexPath,
                  indexPath != newIndexPath else { return }
            if anObject is Image {
                indexPath.section = 1
                newIndexPath.section = 1
            }
            updateOperations.append( BlockOperation {  [weak self] in
//                debugPrint("••> Move item of album #\(fetchDelegate.categoryId) from \(indexPath) to \(newIndexPath)")
                self?.collectionView.moveItem(at: indexPath, to: newIndexPath)
            })
        default:
            fatalError("AlbumViewController: unknown NSFetchedResultsChangeType")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Check that this update should be managed by this view controller
        if view.window == nil || [images, albums].contains(controller) == false || updateOperations.isEmpty { return }
        // Update objects
        collectionView.performBatchUpdates({ [weak self] in
            self?.updateOperations.forEach({ $0.start()})
        }) { [weak self] _ in
            // Update footer
            self?.updateNberOfImagesInFooter()
        }
    }
}
