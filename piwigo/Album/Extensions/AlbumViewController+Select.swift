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

extension AlbumViewController
{
    // MARK: - Select Buttons
    func getSelectBarButton() -> UIBarButtonItem {
        let button = UIBarButtonItem(title: NSLocalizedString("categoryImageList_selectButton", comment: "Select"), style: .plain, target: self, action: #selector(didTapSelect))
        button.accessibilityIdentifier = "Select"
        return button
    }
    
    func getCancelBarButton() -> UIBarButtonItem {
        let button = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelSelect))
        button.accessibilityIdentifier = "Cancel"
        return button
    }
}


@available(iOS 14, *)
extension AlbumViewController
{
    // MARK: - Select Menu
    /// - for switching to the selection mode
    func selectMenu() -> UIMenu {
        let menuId = UIMenu.Identifier("org.piwigo.piwigoImage.select")
        let menu = UIMenu(title: "", image: nil, identifier: menuId,
                          options: UIMenu.Options.displayInline,
                          children: [selectAction()])
        return menu
    }
    
    private func selectAction() -> UIAction {
        let actionId = UIAction.Identifier("Select")
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
        let menuId = UIMenu.Identifier("org.piwigo.piwigoImage.album")
        let menu = UIMenu(title: "", image: nil, identifier: menuId,
                          options: UIMenu.Options.displayInline,
                          children: [imagesCopyAction(),
                                     imagesMoveAction()].compactMap({$0}))
        return menu
    }
    
    
    // MARK: - Images Menu
    /// - for editing image parameters
    func imagesMenu() -> UIMenu {
        let menuId = UIMenu.Identifier("org.piwigo.piwigoImages.edit")
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
        isSelect = true
        
        // Disable interaction with category cells and scroll to first image cell if needed
        var numberOfImageCells = 0
        for cell in collectionView.visibleCells
        {
            // Disable user interaction with category cell
            if let categoryCell = cell as? AlbumCollectionViewCell {
                categoryCell.contentView.alpha = 0.5
                categoryCell.isUserInteractionEnabled = false
            }

            // Will scroll to position if no visible image cell
            if cell is ImageCollectionViewCell {
                numberOfImageCells = numberOfImageCells + 1
            }
        }

        // Scroll to position of images if needed
        if numberOfImageCells == 0, (images.fetchedObjects ?? []).count != 0 {
            let indexPathOfFirstImage = IndexPath(item: 0, section: 1)
            collectionView.scrollToItem(at: indexPathOfFirstImage, at: .top, animated: true)
        }

        // Initialisae navigation bar and toolbar
        initBarsInSelectMode()
    }
    
    @objc func cancelSelect() {
        // Disable Images Selection mode
        isSelect = false
        
        // Update navigation bar and toolbar
        initBarsInPreviewMode()
        updateBarsInPreviewMode()
        updateButtons()
        
        // Enable interaction with album cells and deselect image cells
        for cell in collectionView?.visibleCells ?? [] {
            // Enable user interaction with album cell
            if let albumCell = cell as? AlbumCollectionViewCell {
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
        
        // Clear array of selected images and allow iOS device to sleep
        touchedImageIds = []
        selectedImageIds = Set<Int64>()
        selectedFavoriteIds = Set<Int64>()
        selectedVideosIds = Set<Int64>()
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    
    // MARK: - Prepare Selection
    func initSelection(beforeAction action: pwgImageAction) {
        if selectedImageIds.isEmpty { return }

        // Disable buttons
        setEnableStateOfButtons(false)

        // Prepare variable for HUD and attribute action
        switch action {
        case .edit         /* Edit images parameters */,
             .delete       /* Distinguish orphanes and ask for confirmation */,
             .share        /* Check Photo Library access rights */,
             .copyImages   /* Copy images to album */,
             .moveImages   /* Move images to album */:
            
            // Remove images from which we already have complete data
            selectedImageIdsLoop = selectedImageIds
            let selectedImages = (images.fetchedObjects ?? []).filter({selectedImageIds.contains($0.pwgID)})
            for selectedImageId in selectedImageIds {
                guard let selectedImage = selectedImages.first(where: {$0.pwgID == selectedImageId})
                    else { continue }
                if selectedImage.fileSize != Int64.zero {
                    selectedImageIdsLoop.remove(selectedImageId)
                }
            }
            
            // Should we retrieve data of some images?
            if selectedImageIdsLoop.isEmpty {
                doAction(action)
            } else {
                // Display HUD
                totalNumberOfImages = selectedImageIdsLoop.count
                navigationController?.showHUD(withTitle: NSLocalizedString("loadingHUD_label", comment: "Loading…"),
                              inMode: totalNumberOfImages > 1 ? .determinate : .indeterminate)
                
                // Retrieve image data if needed
                PwgSession.checkSession(ofUser: user) {  [self] in
                    retrieveImageData(beforeAction: action)
                } failure: { [unowned self] error in
                    retrieveImageDataError(error)
                }
            }
            
        case .addToFavorites        /* Add photos to favorites */,
             .removeFromFavorites   /* Remove photos from favorites */:
            // Display HUD
            totalNumberOfImages = selectedImageIds.count
            let title = totalNumberOfImages > 1 ? NSLocalizedString("editImageDetailsHUD_updatingPlural", comment: "Updating Photos…") : NSLocalizedString("editImageDetailsHUD_updatingSingle", comment: "Updating Photo…")
            navigationController?.showHUD(withTitle: title, inMode: totalNumberOfImages > 1 ? .determinate : .indeterminate)
            
            // Add or remove image from favorites
            doAction(action)
            
        case .rotateImagesLeft      /* Rotate photos 90° to left */,
             .rotateImagesRight     /* Rotate photos 90° to right */:
            // Display HUD
            totalNumberOfImages = selectedImageIds.count
            let title = totalNumberOfImages > 1 ? NSLocalizedString("rotateSeveralImageHUD_rotating", comment: "Rotating Photos…") : NSLocalizedString("rotateSingleImageHUD_rotating", comment: "Rotating Photo…")
            navigationController?.showHUD(withTitle: title, inMode: totalNumberOfImages > 1 ? .determinate : .indeterminate)
            
            // Add or remove image from favorites
            doAction(action)
        }
    }
    
    private func doAction(_ action: pwgImageAction) {
        switch action {
        case .edit          /* Edit images parameters */:
            editImages()
        case .delete        /* Distinguish orphanes and ask for confirmation */:
            askDeleteConfirmation()
        case .share         /* Check Photo Library access rights */:
            checkPhotoLibraryAccessBeforeShare()
        case .copyImages    /* Copy images to Album */:
            copyImagesToAlbum()
        case .moveImages    /* Move images to album */:
            moveImagesToAlbum()
        case .addToFavorites:
            addImageToFavorites()
        case .removeFromFavorites:
            removeImageFromFavorites()
        case .rotateImagesLeft:
            rotateImages(by: 90.0)
        case .rotateImagesRight:
            rotateImages(by: -90.0)
        }
    }

    private func retrieveImageData(beforeAction action:pwgImageAction) {
        // Get image ID if any
        guard let imageId = selectedImageIdsLoop.first else {
            navigationController?.hideHUD() { [self] in
                doAction(action)
            }
            return
        }
                        
        // Image data are not complete when retrieved using pwg.categories.getImages
        imageProvider.getInfos(forID: imageId, inCategoryId: self.albumData.pwgID) {  [self] in
            // Image info retrieved
            selectedImageIdsLoop.remove(imageId)

            // Update HUD
            navigationController?.updateHUD(withProgress: 1.0 - Float(selectedImageIdsLoop.count) / Float(totalNumberOfImages))

            // Next image
            retrieveImageData(beforeAction: action)
        } failure: { [unowned self] error in
            retrieveImageDataError(error)
        }
    }
    
    private func retrieveImageDataError(_ error: NSError) {
        DispatchQueue.main.async { [self] in
            // Session logout required?
            if let pwgError = error as? PwgSessionError,
               [.invalidCredentials, .incompatiblePwgVersion, .invalidURL, .authenticationFailed]
                .contains(pwgError) {
                ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
                return
            }
            
            // Report error
            let title = NSLocalizedString("imageDetailsFetchError_title", comment: "Image Details Fetch Failed")
            let message = NSLocalizedString("imageDetailsFetchError_message", comment: "Fetching the photo data failed.")
            dismissPiwigoError(withTitle: title, message: message,
                               errorMessage: error.localizedDescription) { [unowned self] in
                navigationController?.hideHUD() { [unowned self] in
                    updateBarsInSelectMode()
                }
            }
        }
    }
}

// MARK: -
extension AlbumViewController: UIGestureRecognizerDelegate
{
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Will examine touchs only in select mode
        if isSelect {
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
        guard let gestureRecognizer = gestureRecognizer,
              let collectionView = collectionView
        else { return }
        
        // Select/deselect cells
        //        let start = CFAbsoluteTimeGetCurrent()
        switch gestureRecognizer.state {
        case .began, .changed:
            // Get touch point
            let point = gestureRecognizer.location(in: collectionView)
            
            // Get cell at touch position
            if let indexPath = collectionView.indexPathForItem(at: point),
               let imageCell = collectionView.cellForItem(at: indexPath) as? ImageCollectionViewCell,
               let imageId = imageCell.imageData?.pwgID
            {
                // Update the selection if not already done
                if touchedImageIds.contains(imageId) { return }
                
                // Store that the user touched this cell during this gesture
                touchedImageIds.append(imageId)
                
                // Update the selection state
                if !selectedImageIds.contains(imageId) {
                    selectedImageIds.insert(imageId)
                    imageCell.isSelection = true
                    if imageCell.isFavorite {
                        selectedFavoriteIds.insert(imageId)
                    }
                    if imageCell.imageData.isVideo {
                        selectedVideosIds.insert(imageId)
                    }
                } else {
                    imageCell.isSelection = false
                    selectedImageIds.remove(imageId)
                    selectedFavoriteIds.remove(imageId)
                    selectedVideosIds.remove(imageId)
                }
                
                // Update the navigation bar
                updateBarsInSelectMode()
            }
            
        case .ended:
            touchedImageIds = []
        default:
            debugPrint("NOP")
        }
        //        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
        //        debugPrint("••> image selected/deselected in \(diff.rounded()) ms")
    }
}


// MARK: - ImageDetailDelegate Methods
extension AlbumViewController: ImageDetailDelegate
{
    func didSelectImage(atIndex imageIndex: Int) {
        // Scroll view to center image
        if collectionView.numberOfItems(inSection: 1) > imageIndex {
            let indexPath = IndexPath(item: imageIndex, section: 1)
            imageOfInterest = indexPath
            collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
            
            // Prepare variables for transitioning delegate
            if let selectedCell = collectionView.cellForItem(at: indexPath) as? ImageCollectionViewCell {
                animatedCell = selectedCell
                albumViewSnapshot = view.snapshotView(afterScreenUpdates: false)
                cellImageViewSnapshot = selectedCell.snapshotView(afterScreenUpdates: false)
                navBarSnapshot = navigationController?.navigationBar.snapshotView(afterScreenUpdates: false)
            }
        }
    }
}

//extension AlbumCollectionViewCell
//{
//    func updatePreviewMode(withInit: Bool) {
//        if withInit {
//            initBarsInPreviewMode()
//        } else {
//            updateBarsInPreviewMode()
//        }
//    }
//    
//    func updateSelectMode(withInit: Bool) {
//        if withInit {
//            initBarsInSelectMode()
//        } else {
//            updateBarsInSelectMode()
//        }
//    }
//    
//    func setButtonsState(_ enabled: Bool) {
//        setEnableStateOfButtons(enabled)
//    }
//    
//    func pushSelectionToView(_ viewController: UIViewController?) {
//        pushView(viewController)
//    }
//    
//    func deselectImages() {
//        cancelSelect()
//    }
//}
