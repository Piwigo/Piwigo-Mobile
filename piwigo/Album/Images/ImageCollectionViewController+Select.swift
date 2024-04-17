//
//  ImageCollectionViewController+Select.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

extension ImageCollectionViewController: UIGestureRecognizerDelegate
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
                } else {
                    imageCell.isSelection = false
                    selectedImageIds.remove(imageId)
                    selectedFavoriteIds.remove(imageId)
                }

                // Update the navigation bar
                imageSelectionDelegate?.updateSelectMode()
            }
            
        case .ended:
            touchedImageIds = []
        default:
            debugPrint("NOP")
        }
//        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//        debugPrint("••> image selected/deselected in \(diff.rounded()) ms")
    }


    // MARK: - Prepare Selection
    func initSelection(beforeAction action: pwgImageAction) {
        if selectedImageIds.isEmpty { return }

        // Disable buttons
        imageSelectionDelegate?.setButtonsState(false)

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
                showPiwigoHUD(withTitle: NSLocalizedString("loadingHUD_label", comment: "Loading…"),
                              detail: "", buttonTitle: "", buttonTarget: nil, buttonSelector: nil,
                              inMode: totalNumberOfImages > 1 ? .annularDeterminate : .indeterminate)
                
                // Retrieve image data if needed
                NetworkUtilities.checkSession(ofUser: user) {  [self] in
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
            showPiwigoHUD(withTitle: title,
                          detail: "", buttonTitle: "", buttonTarget: nil, buttonSelector: nil,
                          inMode: totalNumberOfImages > 1 ? .annularDeterminate : .indeterminate)
            
            // Retrieve image data if needed
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
        }
    }

    private func retrieveImageData(beforeAction action:pwgImageAction) {
        // Get image ID if any
        guard let imageId = selectedImageIdsLoop.first else {
            hidePiwigoHUD() { [self] in
                doAction(action)
            }
            return
        }
                        
        // Image data are not complete when retrieved using pwg.categories.getImages
        imageProvider.getInfos(forID: imageId, inCategoryId: self.albumData.pwgID) {  [self] in
            // Image info retrieved
            selectedImageIdsLoop.remove(imageId)

            // Update HUD
            updatePiwigoHUD(withProgress: 1.0 - Float(selectedImageIdsLoop.count) / Float(totalNumberOfImages))

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
                hidePiwigoHUD() { [unowned self] in
                    imageSelectionDelegate?.updateSelectMode()
                }
            }
        }
    }
}
