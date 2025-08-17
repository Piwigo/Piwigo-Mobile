//
//  AlbumViewController+Select.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

// MARK: Buttons
extension AlbumViewController
{
    // MARK: - Cancel Button
    func getCancelBarButton() -> UIBarButtonItem {
        let button = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelSelect))
        button.accessibilityIdentifier = "Cancel"
        return button
    }
}


// MARK: - Menus
extension AlbumViewController
{
    // MARK: - Select Menu
    /// - for switching to the selection mode
    func selectMenu() -> UIMenu {
        let menuId = UIMenu.Identifier("org.piwigo.images.selectMode")
        let menu = UIMenu(title: "", image: nil, identifier: menuId,
                          options: UIMenu.Options.displayInline,
                          children: [selectAction()])
        return menu
    }
    
    private func selectAction() -> UIAction {
        let actionId = UIAction.Identifier("org.piwigo.images.select")
        let action = UIAction(title: NSLocalizedString("categoryImageList_selectButton", comment: "Select"),
                              image: UIImage(systemName: "checkmark.circle"),
                              identifier: actionId, handler: { [self] action in
            self.didTapSelect()
        })
        action.accessibilityIdentifier = "Select"
        return action
    }
    
    
    // MARK: - Album Menu
    /// - for copying images to another album
    /// - for moving images to another album
    func albumMenu() -> UIMenu {
        let menuId = UIMenu.Identifier("org.piwigo.images.album")
        let menu = UIMenu(title: "", image: nil, identifier: menuId,
                          options: UIMenu.Options.displayInline,
                          children: [imagesCopyAction(),
                                     imagesMoveAction()].compactMap({$0}))
        return menu
    }
    
    
    // MARK: - Images Menu
    /// - for editing image parameters
    func imagesMenu() -> UIMenu {
        let menuId = UIMenu.Identifier("org.piwigo.images.edit")
        let menu = UIMenu(title: "", image: nil, identifier: menuId,
                          options: UIMenu.Options.displayInline,
                          children: [rotateMenu(),
                                     editParamsAction()].compactMap({$0}))
        return menu
    }
}


// MARK: - Selection Management
extension AlbumViewController
{
    @objc func didTapSelect() {
        // Should we really enable this mode?
        if albumData.nbImages == 0 {
            return
        }
        
        // Hide buttons
        hideButtons()
        
        // Activate Images Selection mode
        inSelectionMode = true
        
        // Disable interaction with category cells and scroll to first image cell if needed
        var numberOfImageCells = 0
        for cell in collectionView?.visibleCells ?? []
        {
            // Disable user interaction with album cell
            if let albumCell = cell as? AlbumCollectionViewCell {
                albumCell.contentView.alpha = 0.5
                albumCell.isUserInteractionEnabled = false
            }
            else if let albumCell = cell as? AlbumCollectionViewCellOld {
                albumCell.contentView.alpha = 0.5
                albumCell.isUserInteractionEnabled = false
            }

            // Will scroll to position if no visible image cell
            if cell is ImageCollectionViewCell {
                numberOfImageCells = numberOfImageCells + 1
            }
        }

        // Scroll to position of images if needed
        if numberOfImageCells == 0, nberOfImages() != 0 {
            let indexPathOfFirstImage = IndexPath(item: 0, section: 1)
            collectionView?.scrollToItem(at: indexPathOfFirstImage, at: .top, animated: true)
        }

        // Initialisae navigation bar and toolbar
        initBarsInSelectMode()
    }
    
    @MainActor
    @objc func cancelSelect() {
        // Disable Images Selection mode
        inSelectionMode = false
        
        // Update navigation bar and toolbar
        initBarsInPreviewMode()
        updateBarsInPreviewMode()
        setTitleViewFromAlbumData()
        updateButtons()
        
        // Enable interaction with album cells and deselect image cells
        for cell in collectionView?.visibleCells ?? [] {
            // Enable user interaction with album cell
            if let albumCell = cell as? AlbumCollectionViewCell {
                albumCell.contentView.alpha = 1.0
                albumCell.isUserInteractionEnabled = true
            }
            else if let albumCell = cell as? AlbumCollectionViewCellOld {
                albumCell.contentView.alpha = 1.0
                albumCell.isUserInteractionEnabled = true
            }
        }
        
        // Deselect image cells
        for cell in collectionView?.visibleCells ?? [] {
            // Deselect image cell and disable interaction
            if let imageCell = cell as? ImageCollectionViewCell,
               imageCell.isSelection {
                imageCell.isSelection = false
            }
        }
        
        // Clear array of selected images
        touchedImageIDs = []
        selectedImageIDs = Set<Int64>()
        selectedFavoriteIDs = Set<Int64>()
        selectedVideosIDs = Set<Int64>()
        for key in selectedSections.keys {
            selectedSections[key] = .select
        }

        // Update select buttons of section headers if needed
        if images.sectionNameKeyPath != nil,
           let headers = collectionView?.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader)
        {
            headers.forEach { header in
                if let header = header as? ImageHeaderReusableView {
                    header.selectButton.setTitle(forState: .select)
                }
                else if let header = header as? ImageOldHeaderReusableView {
                    header.selectButton.setTitle(forState: .select)
                }
            }
        }
    }
    
    func selectImage(_ imageData: Image, isFavorite: Bool) {
        self.selectedImageIDs.insert(imageData.pwgID)
        if isFavorite {
            selectedFavoriteIDs.insert(imageData.pwgID)
        }
        if imageData.isVideo {
            selectedVideosIDs.insert(imageData.pwgID)
        }
    }

    func deselectImages(withIDs imageIDs: Set<Int64>) {
        self.selectedImageIDs.subtract(imageIDs)
        self.selectedVideosIDs.subtract(imageIDs)
        self.selectedFavoriteIDs.subtract(imageIDs)
    }

    func updateSelectButton(ofSection section: Int) -> SelectButtonState {
        // No selector for users not allowed to share images or manage favorites
        if (user.canDownloadImages() || hasFavorites || user.hasUploadRights(forCatID: categoryId)) == false {
            return .none
        }

        // Album section?
        if let index = diffableDataSource.snapshot().indexOfSection(pwgAlbumGroup.none.sectionKey),
           index == section {
            return .none
        }
        
        // Number of images in section
        var nberOfImagesInSection = Int.zero
        let snapshot = diffableDataSource.snapshot() as Snaphot
        let sectionID = snapshot.sectionIdentifiers[section]
        nberOfImagesInSection = snapshot.numberOfItems(inSection: sectionID)
        if nberOfImagesInSection == 0 {
            selectedSections[section] = SelectButtonState.none
            return .none
        }

        // Number of selected images
        var nberOfSelectedImagesInSection = 0
        snapshot.itemIdentifiers(inSection: sectionID).forEach { objectID in
            if let image = try? self.mainContext.existingObject(with: objectID) as? Image,
               selectedImageIDs.contains(image.pwgID) {
                nberOfSelectedImagesInSection += 1
            }
        }
        
        // Update state of Select button only if needed
        if nberOfImagesInSection == nberOfSelectedImagesInSection {
            // All images are selected
            selectedSections[section] = SelectButtonState.deselect
            return .deselect
        } else {
            // Not all images are selected
            selectedSections[section] = SelectButtonState.select
            return .select
        }
    }

    
    // MARK: - Prepare Selection
    @MainActor
    func initSelection(ofImagesWithIDs imageIDs: Set<Int64>,
                       beforeAction action: pwgImageAction, contextually: Bool) {
        if imageIDs.isEmpty { return }

        // Disable buttons
        setEnableStateOfButtons(false)

        // Prepare variable for HUD and attribute action
        switch action {
        case .edit              /* Edit images parameters */,
             .delete            /* Distinguish orphanes and ask for confirmation */,
             .share             /* Check Photo Library access rights */:
            
            // Identify images with incomplete data, retrieve missing data and perform wanted action
            prepareDataRetrieval(ofImagesWithIDs: imageIDs, beforeAction: action, contextually: contextually)
            
        case .copyImages        /* Copy images to album to select */,
             .moveImages        /* Move images to album to select */:
            
            // Add category ID to list of recently used albums
            let userInfo = ["categoryId": albumData.pwgID]
            NotificationCenter.default.post(name: .pwgAddRecentAlbum, object: nil, userInfo: userInfo)
            
            // Complete image data is not necessary for Piwigo server version +14.x
            if NetworkVars.shared.usesSetCategory {
                // Select album and copy images into that album
                performAction(action, withImageIDs: imageIDs, contextually: contextually)
            } else {
                // Identify images with incomplete data, retrieve missing data and perform wanted action
                prepareDataRetrieval(ofImagesWithIDs: imageIDs, beforeAction: action, contextually: contextually)
            }
            
        case .favorite          /* Favorite photos   */,
             .unfavorite        /* Unfavorite photos */:
            
            // Display HUD
            let title = imageIDs.count > 1 ?
                NSLocalizedString("editImageDetailsHUD_updatingPlural", comment: "Updating Photos…") :
                NSLocalizedString("editImageDetailsHUD_updatingSingle", comment: "Updating Photo…")
            navigationController?.showHUD(withTitle: title, inMode: imageIDs.count > 1 ? .determinate : .indeterminate)
            
            // Add or remove image from favorites
            performAction(action, withImageIDs: imageIDs, contextually: contextually)
            
        case .rotateImagesLeft  /* Rotate photos 90° to left */,
             .rotateImagesRight /* Rotate photos 90° to right */:
            
            // Display HUD
            let title = imageIDs.count > 1 ?
                NSLocalizedString("rotateSeveralImageHUD_rotating", comment: "Rotating Photos…") :
                NSLocalizedString("rotateSingleImageHUD_rotating", comment: "Rotating Photo…")
            navigationController?.showHUD(withTitle: title, inMode: imageIDs.count > 1 ? .determinate : .indeterminate)
            
            // Add or remove image from favorites
            performAction(action, withImageIDs: imageIDs, contextually: contextually)
        }
    }
    
    @MainActor
    private func performAction(_ action: pwgImageAction, withImageIDs imageIDs: Set<Int64>, contextually: Bool) {
        switch action {
        case .edit          /* Edit images parameters */:
            editImages(withIDs: imageIDs)
        case .delete        /* Distinguish orphanes and ask for confirmation */:
            askDeleteConfirmation(forImagesWithID: imageIDs, contextually: contextually)
        case .share         /* Check Photo Library access rights */:
            // Display or update HUD
            if navigationController?.isShowingHUD() ?? false {
                navigationController?.updateHUD(title: NSLocalizedString("loadingHUD_label", comment: "Loading…"),
                                                inMode: .indeterminate)
            } else if selectedImageIDs.count > 200 {
                navigationController?.showHUD(withTitle: NSLocalizedString("loadingHUD_label", comment: "Loading…"),
                                              inMode: .indeterminate)
            }
            // Prepare items to share in background queue
            DispatchQueue(label: "org.piwigo.share", qos: .userInitiated).async { [self] in
                self.checkPhotoLibraryAccessBeforeSharing(imagesWithID: imageIDs, contextually: contextually)
            }
        case .copyImages    /* Copy images to Album */:
            copyToAlbum(imagesWithID: imageIDs)
        case .moveImages    /* Move images to album */:
            moveToAlbum(imagesWithID: imageIDs)
        case .favorite:
            favorite(imagesWithID: imageIDs, total: Float(imageIDs.count), contextually: contextually)
        case .unfavorite:
            unfavorite(imagesWithID: imageIDs, total: Float(imageIDs.count), contextually: contextually)
        case .rotateImagesLeft:
            rotateImages(withID: imageIDs, by: CGFloat(.pi/2.0), total: Float(imageIDs.count))
        case .rotateImagesRight:
            rotateImages(withID: imageIDs, by: CGFloat(-.pi/2.0), total: Float(imageIDs.count))
        }
    }

    @MainActor
    private func prepareDataRetrieval(ofImagesWithIDs imageIDs: Set<Int64>,
                                      beforeAction action: pwgImageAction, contextually: Bool) {
        // Remove images from which we already have complete data
        var imageIDsToRetrieve = imageIDs
        let selectedImages = (images.fetchedObjects ?? []).filter({imageIDs.contains($0.pwgID)})
        for imageID in imageIDs {
            guard let selectedImage = selectedImages.first(where: {$0.pwgID == imageID})
            else { continue }
            if selectedImage.fileSize != Int64.zero {
                imageIDsToRetrieve.remove(imageID)
            }
        }
        
        // Should we retrieve data of some images?
        if imageIDsToRetrieve.isEmpty {
            performAction(action, withImageIDs: imageIDs, contextually: contextually)
        } else {
            // Display HUD
            navigationController?.showHUD(withTitle: NSLocalizedString("loadingHUD_label", comment: "Loading…"),
                          inMode: imageIDsToRetrieve.count > 1 ? .determinate : .indeterminate)
            
            // Retrieve image data if needed
            PwgSession.checkSession(ofUser: user) {  [self] in
                DispatchQueue.main.async { [self] in
                    self.retrieveData(ofImagesWithID: imageIDsToRetrieve, among: imageIDs,
                                      beforeAction: action, contextually: contextually)
                }
            } failure: { [self] error in
                DispatchQueue.main.async { [self] in
                    retrieveImageDataError(error, contextually: contextually)
                }
            }
        }
    }
    
    @MainActor
    private func retrieveData(ofImagesWithID someIDs: Set<Int64>, among imageIDs: Set<Int64>,
                              beforeAction action:pwgImageAction, contextually: Bool) {
        // Get image ID if any
        var remainingIDs = someIDs
        guard let imageID = remainingIDs.first else {
            if action == .share {
                // Update or display HUD
                self.performAction(action, withImageIDs: imageIDs, contextually: contextually)
            } else {
                self.navigationController?.hideHUD() { [self] in
                    performAction(action, withImageIDs: imageIDs, contextually: contextually)
                }
            }
            return
        }
        
        // Image data are not complete when retrieved using pwg.categories.getImages
        imageProvider.getInfos(forID: imageID, inCategoryId: self.albumData.pwgID) { [self] in
            DispatchQueue.main.async { [self] in
                // Image info retrieved
                remainingIDs.remove(imageID)
                
                // Update HUD
                let progress: Float = Float(1) - Float(remainingIDs.count) / Float(imageIDs.count)
                self.navigationController?.updateHUD(withProgress: progress)

                // Next image
                retrieveData(ofImagesWithID: remainingIDs, among: imageIDs,
                             beforeAction: action, contextually: contextually)
            }
        } failure: { [self] error in
            DispatchQueue.main.async { [self] in
                retrieveImageDataError(error, contextually: contextually)
            }
        }
    }
    
    @MainActor
    private func retrieveImageDataError(_ error: Error, contextually: Bool) {
        // Session logout required?
        if let pwgError = error as? PwgKitError, pwgError.requiresLogout {
            ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
            return
        }
        
        // Report error
        let title = NSLocalizedString("imageDetailsFetchError_title", comment: "Image Details Fetch Failed")
        let message = NSLocalizedString("imageDetailsFetchError_message", comment: "Fetching the photo data failed.")
        dismissPiwigoError(withTitle: title, message: message, errorMessage: error.localizedDescription) { [self] in
            navigationController?.hideHUD() { [self] in
                if contextually {
                    setEnableStateOfButtons(true)
                } else {
                    updateBarsInSelectMode()
                }
            }
        }
    }
}

// MARK: - UIGestureRecognizerDelegate Methods
extension AlbumViewController: UIGestureRecognizerDelegate
{
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Will examine touchs only in select mode
        if inSelectionMode {
            return true
        }
        return false
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Will interpret touches only in horizontal direction
        if let gPR = gestureRecognizer as? UIPanGestureRecognizer,
           let collectionView = collectionView {
            let translation = gPR.translation(in: collectionView)
            if abs(translation.x) > abs(translation.y) {
                return true
            }
        }
        return false
    }
    
    @objc func touchedImages(_ gestureRecognizer: UIPanGestureRecognizer?) {
        // Just in case…
        guard let collectionView = collectionView,
              let gestureRecognizerState = gestureRecognizer?.state,
              let point = gestureRecognizer?.location(in: collectionView),
              let indexPath = collectionView.indexPathForItem(at: point)
        else { return }
        
        // Select/deselect cells
        //        let start = CFAbsoluteTimeGetCurrent()
        if [.began, .changed].contains(gestureRecognizerState)
        {
            // Get cell at touch position
            if let imageCell = collectionView.cellForItem(at: indexPath) as? ImageCollectionViewCell,
               let imageData = imageCell.imageData
            {
                // Update the selection if not already done
                if touchedImageIDs.contains(imageData.pwgID) { return }
                
                // Store that the user touched this cell during this gesture
                touchedImageIDs.append(imageData.pwgID)
                
                // Update the selection state
                if !selectedImageIDs.contains(imageData.pwgID) {
                    selectImage(imageData, isFavorite: imageCell.isFavorite)
                    imageCell.isSelection = true
                } else {
                    imageCell.isSelection = false
                    deselectImages(withIDs: Set([imageData.pwgID]))
                }
                
                // Update the navigation bar
                updateBarsInSelectMode()
            }
        }
        
        // Is this the end of the gesture?
        if gestureRecognizerState == .ended {
            // Clear list of touched images
            touchedImageIDs = []
            
            // Update state of Select button if needed
            let selectState = updateSelectButton(ofSection: indexPath.section)
            let indexPath = IndexPath(item: 0, section: indexPath.section)
            if let header = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPath) as? ImageHeaderReusableView {
                header.selectButton.setTitle(forState: selectState)
            } else if let header = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPath) as? ImageOldHeaderReusableView {
                header.selectButton.setTitle(forState: selectState)
            }
        }
        //        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
        //        debugPrint("••> image selected/deselected in \(diff.rounded()) ms")
    }
}


// MARK: - ImageDetailDelegate Methods
extension AlbumViewController: ImageDetailDelegate
{
    func didSelectImage(atIndexPath indexPath: IndexPath) {
        // Scroll view to center image
        if collectionView?.numberOfSections ?? 0 > indexPath.section,
           collectionView?.numberOfItems(inSection: indexPath.section) ?? 0 > indexPath.item {
            
            imageOfInterest = indexPath
            collectionView?.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
            
            // Prepare variables for transitioning delegate
            if let selectedCell = collectionView?.cellForItem(at: indexPath) as? ImageCollectionViewCell {
                animatedCell = selectedCell
                albumViewSnapshot = view.snapshotView(afterScreenUpdates: false)
                cellImageViewSnapshot = selectedCell.snapshotView(afterScreenUpdates: false)
                navBarSnapshot = navigationController?.navigationBar.snapshotView(afterScreenUpdates: false)
            }
        }
    }
}
