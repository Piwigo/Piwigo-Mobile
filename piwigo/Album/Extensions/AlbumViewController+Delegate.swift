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
        // Retrieve object ID
        guard let objectID = self.diffableDataSource.itemIdentifier(for: indexPath)
        else { return }
        
        // Album or image?
        if let album = try? self.mainContext.existingObject(with: objectID) as? Album {
            // Push new album view
            let albumSB = UIStoryboard(name: "AlbumViewController", bundle: nil)
            guard let subAlbumVC = albumSB.instantiateViewController(withIdentifier: "AlbumViewController") as? AlbumViewController
            else { preconditionFailure("Could not load AlbumViewController") }
            subAlbumVC.categoryId = album.pwgID
            pushAlbumView(subAlbumVC, completion: {_ in })
        }
        else if let selectedCell = collectionView.cellForItem(at: indexPath) as? ImageCollectionViewCell {
            // Action depends on mode
            if inSelectionMode {
                // Check image ID
                guard let imageData = selectedCell.imageData,
                      imageData.pwgID != 0
                else { return }
                
                // Selection mode active => add/remove image from selection
                if !selectedImageIDs.contains(imageData.pwgID) {
                    selectImage(imageData, isFavorite: selectedCell.isFavorite)
                    selectedCell.isSelection = true
                } else {
                    deselectImages(withIDs: Set([imageData.pwgID]))
                    selectedCell.isSelection = false
                }
                
                // Update nav buttons
                updateBarsInSelectMode()
                
                // Update state of Select button if needed
                let selectState = updateSelectButton(ofSection: indexPath.section)
                let indexPathOfHeader = IndexPath(item: 0, section: indexPath.section)
                if let header = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPathOfHeader) as? ImageHeaderReusableView {
                    header.selectButton.setTitle(forState: selectState)
                }
                return
            }
            
            // Add category ID to list of recently used albums
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
        if let firstSectionID = diffableDataSource.snapshot().sectionIdentifiers.first,
           firstSectionID == pwgAlbumGroup.none.sectionKey {
            let imageIndexPath = IndexPath(item: indexPath.item, section: indexPath.section - 1)
            imageDetailView.indexPath = imageIndexPath
        } else {
            imageDetailView.indexPath = indexPath
        }
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
        if collectionView.cellForItem(at: indexPath) is AlbumCollectionViewCell,
           user.hasAdminRights {
            // Return context menu configuration
            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
                return self.albumContextMenu(indexPath)
            }
        }
        else if let cell = collectionView.cellForItem(at: indexPath) as? ImageCollectionViewCell,
                let imageData = cell.imageData {
            // Return context menu configuration
            let identifier = NSString(string: "\(imageData.pwgID)")
            return UIContextMenuConfiguration(identifier: identifier, previewProvider: {
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
        // Manages only one album or image
        guard indexPaths.count == 1, let indexPath = indexPaths.first
        else { return nil }
        
        // Only admins can rename, move and delete albums
        if collectionView.cellForItem(at: indexPath) is AlbumCollectionViewCell,
           user.hasAdminRights {
            // Return context menu configuration
            return UIContextMenuConfiguration(actionProvider: { suggestedActions in
                return self.albumContextMenu(indexPath)
            })
        }
        else if let cell = collectionView.cellForItem(at: indexPath) as? ImageCollectionViewCell,
                let imageData = cell.imageData {
            // Return context menu configuration
            return UIContextMenuConfiguration(identifier: nil, previewProvider: {
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
    private func albumContextMenu(_ indexPath: IndexPath) -> UIMenu {
        let addPhotos = self.addPhotosMenu(indexPath)
        let rename = self.renameAlbumAction(indexPath)
        let move = self.moveAlbumAction(indexPath)
        let delete = self.deleteAlbumMenu(indexPath)
        return UIMenu(title: "", children: [addPhotos, rename, move, delete])
    }
    
    private func addPhotosMenu(_ indexPath: IndexPath) -> UIMenu {
        let addPhotos = addPhotosAction(indexPath)
        let menuId = UIMenu.Identifier("org.piwigo.addPhotos")
        return UIMenu(identifier: menuId, options: UIMenu.Options.displayInline, children: [addPhotos])
    }
    
    private func addPhotosAction(_ indexPath: IndexPath) -> UIAction {
        let imageUpload: UIImage?
        if #available(iOS 17.0, *) {
            let imageConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            imageUpload = UIImage(systemName: "photo.badge.plus", withConfiguration: imageConfig)
        } else {
            imageUpload = UIImage(named: "photo.badge.plus")
        }
        return UIAction(title: NSLocalizedString("categoryCellOption_addPhotos", comment: "Add Photos"),
                        image: imageUpload) { action in
            // Push album view
            let albumSB = UIStoryboard(name: "AlbumViewController", bundle: nil)
            guard let objectID = self.diffableDataSource.itemIdentifier(for: indexPath),
                  let albumData = try? self.mainContext.existingObject(with: objectID) as? Album,
                  let subAlbumVC = albumSB.instantiateViewController(withIdentifier: "AlbumViewController") as? AlbumViewController
            else { preconditionFailure("Could not load AlbumViewController") }
            subAlbumVC.categoryId = albumData.pwgID
            self.pushAlbumView(subAlbumVC) { _ in }
            subAlbumVC.checkPhotoLibraryAccess()
        }
    }
    
    private func renameAlbumAction(_ indexPath: IndexPath) -> UIAction {
        return UIAction(title: NSLocalizedString("categoryCellOption_rename", comment: "Rename Album"),
                        image: UIImage(systemName: "character.cursor.ibeam")) { action in
            guard let objectID = self.diffableDataSource.itemIdentifier(for: indexPath),
                  let albumData = try? self.mainContext.existingObject(with: objectID) as? Album,
                  let topViewController = self.navigationController
            else { return }
            let rename = AlbumRenaming(albumData: albumData, user: self.user, mainContext: self.mainContext,
                                       topViewController: topViewController)
            rename.displayAlert { _ in }
        }
    }
    
    private func moveAlbumAction(_ indexPath: IndexPath) -> UIAction {
        return UIAction(title: NSLocalizedString("categoryCellOption_move", comment: "Move Album"),
                        image: UIImage(systemName: "arrowshape.turn.up.left")) { action in
            let moveSB = UIStoryboard(name: "SelectCategoryViewController", bundle: nil)
            guard let objectID = self.diffableDataSource.itemIdentifier(for: indexPath),
                  let albumData = try? self.mainContext.existingObject(with: objectID) as? Album,
                  let moveVC = moveSB.instantiateViewController(withIdentifier: "SelectCategoryViewController") as? SelectCategoryViewController
            else { return }
            if moveVC.setInput(parameter: albumData, for: .moveAlbum) {
                moveVC.user = self.user
                self.pushAlbumView(moveVC) { _ in }
            }
        }
    }
    
    private func deleteAlbumMenu(_ indexPath: IndexPath) -> UIMenu {
        let delete = deleteAlbumAction(indexPath)
        let menuId = UIMenu.Identifier("org.piwigo.deleteAlbum")
        return UIMenu(identifier: menuId, options: UIMenu.Options.displayInline, children: [delete])
    }
    
    private func deleteAlbumAction(_ indexPath: IndexPath) -> UIAction {
        return UIAction(title: NSLocalizedString("categoryCellOption_delete", comment: "Delete Album"),
                        image: UIImage(systemName: "trash"),
                        attributes: .destructive) { action in
            guard let objectID = self.diffableDataSource.itemIdentifier(for: indexPath),
                  let albumData = try? self.mainContext.existingObject(with: objectID) as? Album,
                  let topViewController = self.navigationController
            else { return }
            let delete = AlbumDeletion(albumData: albumData, user: self.user,
                                       topViewController: topViewController)
            delete.displayAlert { _ in }
        }
    }
    
    
    // MARK: - Image Context Menu
    private func imageContextMenu(forCell cell: ImageCollectionViewCell, imageData: Image,
                                  at indexPath: IndexPath) -> UIMenu {
        var children = [UIMenuElement]()
        if let imageID = cell.imageData?.pwgID {
            // Since Piwigo 14, we know whether a user is allowed to download images
            let canShareImages = user.canDownloadImages()
            if canShareImages {
                children.append(shareImageAction(withID: imageID))
            }
            
            // pwg.users.favorites… methods available from Piwigo version 2.10 for registered users
            if hasFavorites {
                if cell.isFavorite {
                    children.append(unfavoriteImageAction(withID: imageID))
                } else {
                    children.append(favoriteImageAction(withID: imageID))
                }
            }
            
            // Not all users can select/deselect images
            if canShareImages || hasFavorites || user.hasUploadRights(forCatID: categoryId) {
                if self.selectedImageIDs.contains(imageID) {
                    // Image not selected ► Propose to select it
                    children.append(deselectImageAction(forCell: cell, at: indexPath))
                } else {
                    // Image selected ► Propose to deselect it
                    children.append(selectImageAction(forCell: cell, at: indexPath))
                }
            }
            
            // User with admin or upload rights can delete images
            if user.hasUploadRights(forCatID: categoryId) {
                children.append(deleteImageMenu(forImageID: imageID))
            }
        }
        return UIMenu(title: "", children: children)
    }
    
    private func shareImageAction(withID imageID: Int64) -> UIAction {
        return UIAction(title: NSLocalizedString("categoryImageList_share", comment: "Share"),
                        image: UIImage(systemName: "square.and.arrow.up")) { _ in
            self.initSelection(ofImagesWithIDs: Set([imageID]), beforeAction: .share, contextually: true)
        }
    }
    
    private func favoriteImageAction(withID imageID: Int64) -> UIAction {
        return UIAction(title: NSLocalizedString("categoryImageList_favorite", comment: "Favorite"),
                        image: UIImage(systemName: "heart")) { _ in
            self.initSelection(ofImagesWithIDs: Set([imageID]), beforeAction: .favorite, contextually: true)
        }
    }
    
    private func unfavoriteImageAction(withID imageID: Int64) -> UIAction {
        return UIAction(title: NSLocalizedString("categoryImageList_unfavorite", comment: "Unfavorite"),
                        image: UIImage(systemName: "heart.slash")) { _ in
            self.initSelection(ofImagesWithIDs: Set([imageID]), beforeAction: .unfavorite, contextually: true)
        }
    }
    
    private func selectImageAction(forCell cell: ImageCollectionViewCell, at indexPath: IndexPath) -> UIAction {
        // Image not selected ► Propose to select it
        return UIAction(title: NSLocalizedString("categoryImageList_selectButton", comment: "Select"),
                        image: UIImage(systemName: "checkmark.circle")) { [self] _ in
            // Select image
            guard let imageData = cell.imageData else { return }
            self.selectImage(imageData, isFavorite: cell.isFavorite)
            cell.isSelection = true

            // Check if the selection mode is active
            if self.inSelectionMode {
                // Update the navigation bar and title view
                self.updateBarsInSelectMode()
            } else {
                // Enable the selection mode
                self.inSelectionMode = true
                self.hideButtons()
                self.initBarsInSelectMode()
            }
            
            // Update state of Select button if needed
            let selectState = self.updateSelectButton(ofSection: indexPath.section)
            let indexPath = IndexPath(item: 0, section: indexPath.section)
            if let header = self.collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPath) as? ImageHeaderReusableView {
                header.selectButton.setTitle(forState: selectState)
            }
        }
    }
    
    private func deselectImageAction(forCell cell: ImageCollectionViewCell, at indexPath: IndexPath) -> UIAction {
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
            guard let imageData = cell.imageData else { return }
            self.deselectImages(withIDs: Set([imageData.pwgID]))
            cell.isSelection = false
            
            // Check if the selection mode should be disabled
            if self.selectedImageIDs.isEmpty {
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
            }
        }
    }
    
    private func deleteImageMenu(forImageID imageID: Int64) -> UIMenu {
        let delete = deleteImageAction(forImageID: imageID)
        let menuId = UIMenu.Identifier("org.piwigo.removeFromCameraRoll")
        return UIMenu(identifier: menuId, options: UIMenu.Options.displayInline, children: [delete])
    }
    
    private func deleteImageAction(forImageID imageID: Int64) -> UIAction {
        // Image selected ► Propose to deselect it
        return UIAction(title: NSLocalizedString("deleteSingleImage_title", comment: "Delete Photo"),
                        image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
            self.initSelection(ofImagesWithIDs: Set([imageID]), beforeAction: .delete, contextually: true)
        }
    }
}
