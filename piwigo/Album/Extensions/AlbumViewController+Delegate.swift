//
//  AlbumViewController+Delegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

extension AlbumViewController: UICollectionViewDelegate
{
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0 /* Albums */:
            guard let selectedCell = collectionView.cellForItem(at: indexPath) as? AlbumCollectionViewCell,
                  indexPath.item >= 0, indexPath.item < (albums.fetchedObjects ?? []).count
            else { return }
            
            // Push new album view
            let albumData = albums.object(at: indexPath)
            let albumSB = UIStoryboard(name: "AlbumViewController", bundle: nil)
            guard let subAlbumVC = albumSB.instantiateViewController(withIdentifier: "AlbumViewController") as? AlbumViewController
            else { preconditionFailure("Could not load AlbumViewController") }
            subAlbumVC.categoryId = albumData.pwgID
            pushAlbumView(subAlbumVC, completion: {_ in })
            break
            
        default /* Images */:
            // Check data
            guard let selectedCell = collectionView.cellForItem(at: indexPath) as? ImageCollectionViewCell,
                  indexPath.item >= 0, indexPath.item < (images.fetchedObjects ?? []).count else {
                return
            }
            
            // Action depends on mode
            if isSelect {
                // Check image ID
                guard let imageId = selectedCell.imageData?.pwgID, imageId != 0 else {
                    return
                }
                
                // Selection mode active => add/remove image from selection
                if !selectedImageIds.contains(imageId) {
                    selectedImageIds.insert(imageId)
                    selectedCell.isSelection = true
                    if selectedCell.isFavorite {
                        selectedFavoriteIds.insert(imageId)
                    }
                    if selectedCell.imageData.isVideo {
                        selectedVideosIds.insert(imageId)
                    }
                } else {
                    selectedCell.isSelection = false
                    selectedImageIds.remove(imageId)
                    selectedFavoriteIds.remove(imageId)
                    selectedVideosIds.remove(imageId)
                }
                
                // Update nav buttons
                updateBarsInSelectMode()
                
                // Update state of Select button if needed
                let selectState = updateSelectButton(ofSection: indexPath.section)
                let indexPathOfHeader = IndexPath(item: 0, section: indexPath.section)
                if let header = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPathOfHeader) as? ImageHeaderReusableView {
                    header.selectButton.setTitle(forState: selectState)
                }
                else if let header = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPathOfHeader) as? ImageOldHeaderReusableView {
                    header.selectButton.setTitle(forState: selectState)
                }
                return
            }
            
            // Add category to list of recent albums
            let userInfo = ["categoryId": NSNumber(value: albumData.pwgID)]
            NotificationCenter.default.post(name: .pwgAddRecentAlbum, object: nil, userInfo: userInfo)
            
            // Selection mode not active => display full screen image
            presentImage(ofCell: selectedCell, at: indexPath, animated: true)
        }
    }
    
    func presentImage(ofCell selectedCell: ImageCollectionViewCell, at indexPath: IndexPath, animated: Bool) {
        // Create ImageViewController
        let imageDetailSB = UIStoryboard(name: "ImageViewController", bundle: nil)
        guard let imageDetailView = imageDetailSB.instantiateViewController(withIdentifier: "ImageViewController") as? ImageViewController
        else { preconditionFailure("Could not load ImageViewController") }
        imageDetailView.user = user
        imageDetailView.categoryId = albumData.pwgID
        imageDetailView.images = images
        let imageIndexPath = IndexPath(item: indexPath.item, section: indexPath.section - 1)
        imageDetailView.indexPath = imageIndexPath
        imageDetailView.imgDetailDelegate = self
        
        // Prepare image animated transitioning
        animatedCell = selectedCell
        albumViewSnapshot = view.snapshotView(afterScreenUpdates: false)
        cellImageViewSnapshot = selectedCell.snapshotView(afterScreenUpdates: false)
        navBarSnapshot = navigationController?.navigationBar.snapshotView(afterScreenUpdates: false)
        
        // Push ImageDetailView embedded in navigation controller
        let navController = UINavigationController(rootViewController: imageDetailView)
        navController.hidesBottomBarWhenPushed = true
        navController.transitioningDelegate = self
        navController.modalPresentationStyle = .custom
        navController.modalPresentationCapturesStatusBarAppearance = true
        navigationController?.present(navController, animated: animated)
        
        // Remember that user did tap this image
        imageOfInterest = indexPath
    }
    
    @available(iOS, introduced: 13.0, deprecated: 16.0, message: "")
    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        // Only admins can rename, move and delete albums
        if user.hasAdminRights == false { return nil }

        // Return context menu configuration
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
            return self.albumContextMenu(indexPath)
        }
    }
    
    @available(iOS 16.0, *)
    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemsAt indexPaths: [IndexPath],
                        point: CGPoint) -> UIContextMenuConfiguration? {
        // Only admins can rename, move and delete albums
        if user.hasAdminRights == false { return nil }

        // Return context menu configuration
        return UIContextMenuConfiguration(actionProvider: { suggestedActions in
            if indexPaths.count == 1, let indexPath = indexPaths.first {
                return self.albumContextMenu(indexPath)
            } else {
                return nil
            }
        })
    }

    @available(iOS 13.0, *)
    private func albumContextMenu(_ indexPath: IndexPath) -> UIMenu {
        let inspectAction = self.renameAlbumAction(indexPath)
        let duplicateAction = self.moveAlbumAction(indexPath)
        let deleteAction = self.deleteAlbumAction(indexPath)
        return UIMenu(title: "", children: [inspectAction, duplicateAction, deleteAction])
    }
    
    @available(iOS 13.0, *)
    private func renameAlbumAction(_ indexPath: IndexPath) -> UIAction {
        return UIAction(title: NSLocalizedString("categoryCellOption_rename", comment: "Rename"),
                        image: UIImage(systemName: "character.cursor.ibeam")) { action in
           
        }
    }
    
    @available(iOS 13.0, *)
    private func moveAlbumAction(_ indexPath: IndexPath) -> UIAction {
        return UIAction(title: NSLocalizedString("categoryCellOption_move", comment: "Move"),
                        image: UIImage(systemName: "arrowshape.turn.up.left.fill")) { action in
           
        }
    }
        
    @available(iOS 13.0, *)
    private func deleteAlbumAction(_ indexPath: IndexPath) -> UIAction {
        return UIAction(title: NSLocalizedString("categoryCellOption_delete", comment: "Delete"),
                        image: UIImage(systemName: "trash"),
                        attributes: .destructive) { action in
           
        }
    }
}
