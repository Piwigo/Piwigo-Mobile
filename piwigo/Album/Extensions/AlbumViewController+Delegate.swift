//
//  AlbumViewController+Delegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

// MARK: UICollectionViewDelegate Methods
extension AlbumViewController: UICollectionViewDelegate
{
    // MARK: - Present Album or Image
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0 /* Albums */:
            // Push new album view
            let albumData = albums.object(at: indexPath)
            let albumSB = UIStoryboard(name: "AlbumViewController", bundle: nil)
            guard let subAlbumVC = albumSB.instantiateViewController(withIdentifier: "AlbumViewController") as? AlbumViewController
            else { preconditionFailure("Could not load AlbumViewController") }
            subAlbumVC.categoryId = albumData.pwgID
            pushAlbumView(subAlbumVC, completion: {_ in })
            
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
    
    
    // MARK: - Context Menus
    @available(iOS, introduced: 13.0, deprecated: 16.0, message: "")
    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        // Only admins can rename, move and delete albums
        if indexPath.section == 0, user.hasAdminRights,
           let _ = collectionView.cellForItem(at: indexPath) as? AlbumCollectionViewCell {
            // Return context menu configuration
            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
                return self.albumContextMenu(indexPath)
            }
        }
        else if indexPath.section > 0,
                let cell = collectionView.cellForItem(at: indexPath) as? ImageCollectionViewCell,
                let imageData = cell.imageData {
            // Return context menu configuration
            let identifier = NSString(string: "\(imageData.pwgID)")
            return UIContextMenuConfiguration(identifier: identifier,
                                              previewProvider: {
                // Create preview view controller
                return ImagePreviewViewController(imageData: imageData)
            },
                                              actionProvider: { suggestedActions in
                // Present context menu
                return self.imageContextMenu(forCell: cell, imageData: imageData, at: indexPath)
            })
        }
        return nil
    }
    
    @available(iOS 16.0, *)
    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemsAt indexPaths: [IndexPath],
                        point: CGPoint) -> UIContextMenuConfiguration? {
        // Only admins can rename, move and delete albums
        if indexPaths.count == 1, let indexPath = indexPaths.first,
           indexPath.section == 0, user.hasAdminRights,
           let _ = collectionView.cellForItem(at: indexPath) as? AlbumCollectionViewCell {
            // Return context menu configuration
            return UIContextMenuConfiguration(actionProvider: { suggestedActions in
                return self.albumContextMenu(indexPath)
            })
        }
        else if indexPaths.count == 1, let indexPath = indexPaths.first, indexPath.section > 0,
                let cell = collectionView.cellForItem(at: indexPath) as? ImageCollectionViewCell,
                let imageData = cell.imageData {
            // Return context menu configuration
            return UIContextMenuConfiguration(identifier: nil,
                                              previewProvider: {
                // Create preview view controller
                return ImagePreviewViewController(imageData: imageData)
            },
                                              actionProvider: { suggestedActions in
                // Present context menu
                return self.imageContextMenu(forCell: cell, imageData: imageData, at: indexPath)
            })
        }
        return nil
    }
    
    
    // MARK: - Album Context Menu
    @available(iOS 13.0, *)
    private func albumContextMenu(_ indexPath: IndexPath) -> UIMenu {
        let renameAction = self.renameAlbumAction(indexPath)
        let moveAction = self.moveAlbumAction(indexPath)
        let deleteAction = self.deleteAlbumAction(indexPath)
        return UIMenu(title: "", children: [renameAction, moveAction, deleteAction])
    }
    
    @available(iOS 13.0, *)
    private func renameAlbumAction(_ indexPath: IndexPath) -> UIAction {
        return UIAction(title: NSLocalizedString("categoryCellOption_rename", comment: "Rename"),
                        image: UIImage(systemName: "character.cursor.ibeam")) { action in
            guard let topViewController = self.navigationController
            else { return }
            let albumData = self.albums.object(at: indexPath)
            let rename = AlbumRenaming(albumData: albumData, user: self.user, mainContext: self.mainContext,
                                       topViewController: topViewController)
            rename.displayAlert { _ in }
        }
    }
    
    @available(iOS 13.0, *)
    private func moveAlbumAction(_ indexPath: IndexPath) -> UIAction {
        return UIAction(title: NSLocalizedString("categoryCellOption_move", comment: "Move"),
                        image: UIImage(systemName: "arrowshape.turn.up.left")) { action in
            let moveSB = UIStoryboard(name: "SelectCategoryViewController", bundle: nil)
            guard let moveVC = moveSB.instantiateViewController(withIdentifier: "SelectCategoryViewController") as? SelectCategoryViewController else { return }
            let albumData = self.albums.object(at: indexPath)
            if moveVC.setInput(parameter: albumData, for: .moveAlbum) {
                moveVC.user = self.user
                self.pushAlbumView(moveVC) { _ in }
            }
        }
    }
    
    @available(iOS 13.0, *)
    private func deleteAlbumAction(_ indexPath: IndexPath) -> UIAction {
        return UIAction(title: NSLocalizedString("categoryCellOption_delete", comment: "Delete"),
                        image: UIImage(systemName: "trash"),
                        attributes: .destructive) { action in
            guard let topViewController = self.navigationController
            else { return }
            let albumData = self.albums.object(at: indexPath)
            let delete = AlbumDeletion(albumData: albumData, user: self.user,
                                       topViewController: topViewController)
            delete.displayAlert { _ in }
        }
    }
    
    // MARK: - Image Context Menu
    @available(iOS 13.0, *)
    private func imageContextMenu(forCell cell: ImageCollectionViewCell, imageData: Image,
                                  at indexPath: IndexPath) -> UIMenu {
        var children = [UIMenuElement]()
        if let imageID = cell.imageData?.pwgID {
            if self.selectedImageIds.contains(imageID) {
                // Image not selected ► Propose to select it
                children.append(deselectImageAction(forCell: cell, imageID: imageID, at: indexPath))
            } else {
                // Image selected ► Propose to deselect it
                children.append(selectImageAction(forCell: cell, imageID: imageID, at: indexPath))
            }
            children.append(deleteImageMenu(forImageID: imageID))
        }
        return UIMenu(title: "", children: children)
    }
    
    @available(iOS 13.0, *)
    private func selectImageAction(forCell cell: ImageCollectionViewCell, imageID: Int64,
                                   at indexPath: IndexPath) -> UIAction {
        // Image not selected ► Propose to select it
        return UIAction(title: NSLocalizedString("categoryImageList_selectButton", comment: "Select"),
                        image: UIImage(systemName: "checkmark.circle")) { _ in
            // Select image
            self.selectedImageIds.insert(imageID)
            cell.isSelection = true
            if cell.isFavorite {
                self.selectedFavoriteIds.insert(imageID)
            }
            if cell.imageData.isVideo {
                self.selectedVideosIds.insert(imageID)
            }
            
            // Check if the selection mode is active
            if self.isSelect {
                // Update the navigation bar and title view
                self.updateBarsInSelectMode()
            } else {
                // Enable the selection mode
                self.isSelect = true
                self.hideButtons()
                self.initBarsInSelectMode()
            }
            
            // Update state of Select button if needed
            let selectState = self.updateSelectButton(ofSection: indexPath.section)
            let indexPath = IndexPath(item: 0, section: indexPath.section)
            if let header = self.collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPath) as? ImageHeaderReusableView {
                header.selectButton.setTitle(forState: selectState)
            } else if let header = self.collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPath) as? ImageOldHeaderReusableView {
                header.selectButton.setTitle(forState: selectState)
            }
        }
    }
    
    @available(iOS 13.0, *)
    private func deselectImageAction(forCell cell: ImageCollectionViewCell, imageID: Int64,
                                     at indexPath: IndexPath) -> UIAction {
        // Image selected ► Propose to deselect it
        var image: UIImage?
        if #available(iOS 16, *) {
            image = UIImage(systemName: "checkmark.circle.badge.xmark")
        } else {
            image = UIImage(systemName: "checkmark.circle")
        }
        return UIAction(title: NSLocalizedString("categoryImageList_deselectButton", comment: "Deselect"),
                        image: image) { _ in
            // Deselect image
            cell.isSelection = false
            self.selectedImageIds.remove(imageID)
            self.selectedFavoriteIds.remove(imageID)
            self.selectedVideosIds.remove(imageID)
            
            // Check if the selection mode should be disabled
            if self.selectedImageIds.isEmpty {
                // Disable the selection mode
                self.cancelSelect()
            } else {
                // Update the navigation bar and title view
                self.updateBarsInSelectMode()
            }
            
            // Update state of Select button if needed
            let selectState = self.updateSelectButton(ofSection: indexPath.section)
            let indexPath = IndexPath(item: 0, section: indexPath.section)
            if let header = self.collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPath) as? ImageHeaderReusableView {
                header.selectButton.setTitle(forState: selectState)
            } else if let header = self.collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPath) as? ImageOldHeaderReusableView {
                header.selectButton.setTitle(forState: selectState)
            }
        }
    }
    
    @available(iOS 13.0, *)
    private func deleteImageMenu(forImageID imageID: Int64) -> UIMenu {
        let delete = deleteImageAction(forImageID: imageID)
        let menuId = UIMenu.Identifier("org.piwigo.removeFromCameraRoll")
        return UIMenu(identifier: menuId, options: UIMenu.Options.displayInline, children: [delete])
    }
    
    @available(iOS 13.0, *)
    private func deleteImageAction(forImageID imageID: Int64) -> UIAction {
        // Image selected ► Propose to deselect it
        return UIAction(title: NSLocalizedString("deleteSingleImage_title", comment: "Delete Photo"),
                        image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
            self.askDeleteConfirmation(for: Set([imageID]))
        }
    }
}
