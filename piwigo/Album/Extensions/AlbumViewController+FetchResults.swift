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

// MARK: - NSFetchedResultsControllerDelegate
extension AlbumViewController: NSFetchedResultsControllerDelegate
{
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Check that this update should be managed by this view controller
//        if #available(iOS 13, *), view.window == nil { return }
    }
    
    func controller(_ controller: NSFetchedResultsController<any NSFetchRequestResult>, didChange sectionInfo: any NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        
        // Collect operation changes
        switch controller {
        case albums:
            break
        case images:
            switch type {
            case .insert:
                let collectionSectionIndex = sectionIndex + 1
                updateOperations.append( BlockOperation { [weak self] in
                    print("••> Insert image section at ", collectionSectionIndex)
                    self?.collectionView?.insertSections(IndexSet(integer: collectionSectionIndex))
                })
            case .delete:
                let collectionSectionIndex = sectionIndex + 1
                updateOperations.append( BlockOperation { [weak self] in
                    print("••> Delete image section at ", collectionSectionIndex)
                    self?.collectionView?.deleteSections(IndexSet(integer: collectionSectionIndex))
                })
            case .move:
                let collectionSectionIndex = sectionIndex + 1
                print("••> Move image section at ", collectionSectionIndex)
            case .update:
                let collectionSectionIndex = sectionIndex + 1
                print("••> Update image section at ", collectionSectionIndex)
            @unknown default:
                fatalError("Unknown NSFetchedResultsChangeType of section in AlbumViewController")
            }
        default:
            return
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        // Collect operation changes
        switch controller {
        case albums:
            switch type {
            case .insert:
                guard let newIndexPath = newIndexPath else { return }
                updateOperations.append( BlockOperation { [weak self] in
                    debugPrint("••> Insert sub-album of album #\(self?.categoryId ?? Int32.min) at \(newIndexPath)")
                    self?.collectionView?.insertItems(at: [newIndexPath])
                })
            case .delete:
                guard let indexPath = indexPath else { return }
                updateOperations.append( BlockOperation {  [weak self] in
                    debugPrint("••> Delete sub-album of album #\(self?.categoryId ?? Int32.min) at \(indexPath)")
                    self?.collectionView?.deleteItems(at: [indexPath])
                })
            case .move:
                guard let indexPath = indexPath, let newIndexPath = newIndexPath,
                      indexPath != newIndexPath else { return }
                updateOperations.append( BlockOperation {  [weak self] in
                    debugPrint("••> Move sub-album of album #\(self?.categoryId ?? Int32.min) from \(indexPath) to \(newIndexPath)")
                    self?.collectionView?.moveItem(at: indexPath, to: newIndexPath)
                })
            case .update:
                guard let indexPath = indexPath, let album = anObject as? Album
                else { return }
                updateOperations.append( BlockOperation {  [weak self] in
                    debugPrint("••> Update sub-album at \(indexPath) of album #\(self?.categoryId ?? Int32.min)")
                    if let cell = self?.collectionView?.cellForItem(at: indexPath) as? AlbumCollectionViewCell {
                        // Re-configure album cell
                        cell.config(withAlbumData: album)
                    }
                    if let cell = self?.collectionView?.cellForItem(at: indexPath) as? AlbumCollectionViewCellOld {
                        // Re-configure album cell
                        cell.albumData = album
                    }
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
                    debugPrint("••> Insert image of album #\(self?.categoryId ?? Int32.min) at \(newIndexPath)")
                    self?.collectionView?.insertItems(at: [newIndexPath])
                    // Enable menu if this is the first added image
                    if self?.albumData.nbImages == 1 {
                        debugPrint("••> First added image ► enable menu")
                        self?.initBarsInPreviewMode()
                    }
                })
            case .delete:
                guard var indexPath = indexPath, let image = anObject as? Image
                else { return }
                indexPath.section += 1
                // Deselect image
                selectedImageIds.remove(image.pwgID)
                // Delete image
                updateOperations.append( BlockOperation {  [weak self] in
                    debugPrint("••> Delete image of album #\(self?.categoryId ?? Int32.min) at \(indexPath)")
                    self?.collectionView?.deleteItems(at: [indexPath])
                    if self?.albumData.nbImages == 0 {
                        // Disable menu
                        debugPrint("••> Last removed image ► disable menu")
                        self?.isSelect = false
                        self?.initBarsInPreviewMode()
                    }
                })
            case .move:
                guard var indexPath = indexPath, var newIndexPath = newIndexPath,
                      anObject is Image else { return }
                indexPath.section += 1
                newIndexPath.section += 1
                // Move image
                updateOperations.append( BlockOperation {  [weak self] in
                    debugPrint("••> Move item of album #\(self?.categoryId ?? Int32.min) from \(indexPath) to \(newIndexPath)")
                    self?.collectionView?.moveItem(at: indexPath, to: newIndexPath)
                })
            case .update:
                guard var indexPath = indexPath, let image = anObject as? Image
                else { return }
                indexPath.section += 1
                // Update image
                updateOperations.append( BlockOperation {  [weak self] in
                    debugPrint("••> Update image at \(indexPath) of album #\(self?.categoryId ?? Int32.min)")
                    if let cell = self?.collectionView?.cellForItem(at: indexPath) as? ImageCollectionViewCell,
                       let imagePlaceHolder = self?.imagePlaceHolder, let hasFavorites = self?.hasFavorites,
                       let imageSize = self?.imageSize, let sortOption = self?.sortOption {
                        // Re-configure image cell
                        cell.config(with: image, placeHolder: imagePlaceHolder, size: imageSize, sortOption: sortOption)
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
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Check that this update should be managed by this view controller
        if updateOperations.isEmpty { return }
        
        // Update objects
        collectionView?.performBatchUpdates({ [weak self] in
            self?.updateOperations.forEach({ $0.start()})
        }) { [weak self] _ in
            // Update headers if needed
            self?.updateHeaders()
            // Update footer
            self?.updateNberOfImagesInFooter()
        }
    }
    
    func updateHeaders() {
        // Does this section exist?
        guard images.sectionNameKeyPath != nil,
              let collectionView = collectionView,
              let sortKey = images.fetchRequest.sortDescriptors?.first?.key
        else { return }

        // Images are grouped by day, week or month: section header visible?
        let indexPaths = collectionView.indexPathsForVisibleSupplementaryElements(ofKind: UICollectionView.elementKindSectionHeader)
        indexPaths.forEach { indexPath in
            // Album section?
            if indexPath.section == 0 { return }

            // Determine place names from first images
            var imagesInSection: [Image] = []
            for item in 0..<min(collectionView.numberOfItems(inSection: indexPath.section), 20) {
                let imageIndexPath = IndexPath(item: item, section: indexPath.section - 1)
                imagesInSection.append(images.object(at: imageIndexPath))
            }

            // Retrieve the appropriate section header
            let selectState = updateSelectButton(ofSection: indexPath.section)
            if let header = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPath) as? ImageHeaderReusableView {
                header.config(with: imagesInSection, sortKey: sortKey,
                              section: indexPath.section, selectState: selectState)
            }
            else if let header = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPath) as? ImageOldHeaderReusableView {
                header.config(with: imagesInSection, sortKey: sortKey, group: AlbumVars.shared.defaultGroup,
                              section: indexPath.section, selectState: selectState)
            }
        }
    }
}
