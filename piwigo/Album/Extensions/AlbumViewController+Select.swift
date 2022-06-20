//
//  AlbumViewController+Select.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

extension AlbumViewController
{
    // MARK: - Buttons in Selection Mode
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

    func initButtonsInSelectionMode() {
        // Get album upload rights
        userHasUploadRights = CategoriesData.sharedInstance()
            .getCategoryById(categoryId)?.hasUploadRights ?? false

        // Hide back, Settings, Upload and Home buttons
        navigationItem.hidesBackButton = true
        addButton.isHidden = true
        homeAlbumButton?.isHidden = true

        // Button displayed in all circumstances
        shareBarButton = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareSelection))
        shareBarButton?.tintColor = UIColor.piwigoColorOrange()

        if #available(iOS 14, *) {
            // Interface depends on device and orientation
            let orientation = view.window?.windowScene?.interfaceOrientation

            // User with admin or upload rights can do everything
            if NetworkVars.hasAdminRights ||
               (NetworkVars.hasNormalRights && userHasUploadRights) {
                // The action button proposes:
                /// - to copy or move images to other albums
                /// - to set the image as album thumbnail
                /// - to edit image parameters
                let menu = UIMenu(title: "", children: [albumMenu(), imagesMenu()])
                actionBarButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: menu)
                actionBarButton?.accessibilityIdentifier = "actions"

                deleteBarButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deleteSelection))

                if orientation?.isPortrait ?? false,
                   UIDevice.current.userInterfaceIdiom == .phone {
                    // Left side of navigation bar
                    navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)

                    // Right side of navigation bar
                    navigationItem.setRightBarButtonItems([actionBarButton].compactMap { $0 }, animated: true)

                    // Remaining buttons in navigation toolbar
                    /// We reset the bar button items which are not positioned correctly by iOS 15 after device rotation.
                    /// They also disappear when coming back to portrait orientation.
                    var toolBarItems = [shareBarButton,
                                        UIBarButtonItem.space(),
                                        deleteBarButton].compactMap { $0 }
                    // pwg.users.favorites… methods available from Piwigo version 2.10
                    if "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric, range: nil, locale: .current) != .orderedDescending {
                        favoriteBarButton = getFavoriteBarButton()
                        for (objectIndex, insertionIndex) in NSIndexSet(indexesIn: NSRange(location: 2, length: 2)).enumerated() {toolBarItems.insert(([favoriteBarButton, UIBarButtonItem.space()].compactMap { $0 })[objectIndex], at: insertionIndex) }
                    }
                    navigationController?.setToolbarHidden(false, animated: true)
                    toolbarItems = toolBarItems
                } else {
                    // Left side of navigation bar
                    navigationItem.setLeftBarButtonItems([cancelBarButton, deleteBarButton].compactMap { $0 }, animated: true)

                    // Right side of navigation bar
                    var rightBarButtonItems = [actionBarButton, shareBarButton].compactMap { $0 }
                    // pwg.users.favorites… methods available from Piwigo version 2.10
                    if "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric, range: nil, locale: .current) != .orderedDescending {
                        favoriteBarButton = getFavoriteBarButton()
                        for (objectIndex, insertionIndex) in NSIndexSet(indexesIn: NSRange(location: 1, length: 1)).enumerated() { rightBarButtonItems.insert(([favoriteBarButton].compactMap { $0 })[objectIndex], at: insertionIndex) }
                    }
                    navigationItem.setRightBarButtonItems(rightBarButtonItems, animated: true)

                    // Hide toolbar
                    navigationController?.setToolbarHidden(true, animated: true)
                }
            } else if !NetworkVars.hasGuestRights,
                      ("2.10.0".compare(NetworkVars.pwgVersion, options: .numeric, range: nil, locale: .current) != .orderedDescending) {
                favoriteBarButton = getFavoriteBarButton()

                if orientation?.isPortrait ?? false,
                   UIDevice.current.userInterfaceIdiom == .phone {
                    // Left side of navigation bar
                    navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)

                    // No button on the right
                    navigationItem.setRightBarButtonItems([], animated: true)

                    // Remaining buttons in navigation toolbar
                    navigationController?.setToolbarHidden(false, animated: true)
                    toolbarItems = [shareBarButton,
                                    UIBarButtonItem.space(),
                                    favoriteBarButton].compactMap { $0 }
                } else {
                    // Left side of navigation bar
                    navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)

                    // All other buttons in navigation bar
                    navigationItem.setRightBarButtonItems([favoriteBarButton, shareBarButton].compactMap { $0 }, animated: true)

                    // Hide navigation toolbar
                    navigationController?.setToolbarHidden(true, animated: true)
                }
            } else {
                // Left side of navigation bar
                navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)

                // Guest can only share images
                navigationItem.setRightBarButtonItems([shareBarButton].compactMap { $0 }, animated: true)

                // Hide toolbar
                navigationController?.setToolbarHidden(true, animated: true)
            }
        } else {
            // Fallback on earlier versions
            // Interface depends on device and orientation
            let orientation = UIApplication.shared.statusBarOrientation

            // User with admin or upload rights can do everything
            // WRONG =====> 'normal' user with upload access to the current category can edit images
            // SHOULD BE => 'normal' user having uploaded images can edit them. This requires 'user_id' and 'added_by'
            if NetworkVars.hasAdminRights ||
               (NetworkVars.hasNormalRights && userHasUploadRights) {
                // The action button only proposes to edit image parameters
                actionBarButton = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editSelection))
                actionBarButton?.accessibilityIdentifier = "actions"

                deleteBarButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deleteSelection))
                moveBarButton = UIBarButtonItem(barButtonSystemItem: .reply, target: self, action: #selector(copyMoveSelection))

                if orientation.isPortrait,
                   UIDevice.current.userInterfaceIdiom == .phone {
                    // Left side of navigation bar
                    navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)

                    // Right side of navigation bar
                    navigationItem.setRightBarButtonItems([actionBarButton].compactMap { $0 }, animated: true)

                    // Remaining buttons in navigation toolbar
                    /// We reset the bar button items which are not positioned correctly by iOS 15 after device rotation.
                    /// They also disappear when coming back to portrait orientation.
                    var toolBarItems = [shareBarButton, UIBarButtonItem.space(), moveBarButton, UIBarButtonItem.space(), deleteBarButton].compactMap { $0 }
                    // pwg.users.favorites… methods available from Piwigo version 2.10
                    if "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric, range: nil, locale: .current) != .orderedDescending {
                        favoriteBarButton = getFavoriteBarButton()
                        for (objectIndex, insertionIndex) in NSIndexSet(indexesIn: NSRange(location: 4, length: 2)).enumerated() { toolBarItems.insert(([favoriteBarButton, UIBarButtonItem.space()].compactMap { $0 })[objectIndex], at: insertionIndex) }
                    }
                    navigationController?.setToolbarHidden(false, animated: true)
                    toolbarItems = toolBarItems
                } else {
                    // Left side of navigation bar
                    navigationItem.setLeftBarButtonItems([cancelBarButton, deleteBarButton, moveBarButton].compactMap { $0 }, animated: true)

                    // Right side of navigation bar
                    var rightBarButtonItems = [actionBarButton, shareBarButton].compactMap { $0 }
                    // pwg.users.favorites… methods available from Piwigo version 2.10
                    if "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric, range: nil, locale: .current) != .orderedDescending {
                        favoriteBarButton = getFavoriteBarButton()
                        for (objectIndex, insertionIndex) in NSIndexSet(indexesIn: NSRange(location: 1, length: 1)).enumerated() { rightBarButtonItems.insert(([favoriteBarButton].compactMap { $0 })[objectIndex], at: insertionIndex) }
                    }
                    navigationItem.setRightBarButtonItems(rightBarButtonItems, animated: true)

                    // Hide toolbar
                    navigationController?.setToolbarHidden(true, animated: true)
                }
            } else if !NetworkVars.hasGuestRights,
                      "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric, range: nil, locale: .current) != .orderedDescending {
                favoriteBarButton = getFavoriteBarButton()

                if orientation.isPortrait,
                   UIDevice.current.userInterfaceIdiom == .phone {
                    // Left side of navigation bar
                    navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)

                    // No button on the right
                    navigationItem.setRightBarButtonItems([], animated: true)

                    // Remaining buttons in navigation toolbar
                    navigationController?.setToolbarHidden(false, animated: true)
                    toolbarItems = [shareBarButton, UIBarButtonItem.space(), favoriteBarButton].compactMap { $0 }
                } else {
                    // Left side of navigation bar
                    navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)

                    // All other buttons in navigation bar
                    navigationItem.setRightBarButtonItems([favoriteBarButton, shareBarButton].compactMap { $0 }, animated: true)

                    // Hide navigation toolbar
                    navigationController?.setToolbarHidden(true, animated: true)
                }
            } else {
                // Left side of navigation bar
                navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)

                // Guest can only share images
                navigationItem.setRightBarButtonItems([shareBarButton].compactMap { $0 }, animated: true)

                // Hide toolbar
                navigationController?.setToolbarHidden(true, animated: true)
            }
        }

        // Set initial status
        updateButtonsInSelectionMode()
    }

    func updateButtonsInSelectionMode() {
        let hasImagesSelected = !selectedImageIds.isEmpty

        // User with admin or upload rights can do everything
        // WRONG =====> 'normal' user with upload access to the current category can edit images
        // SHOULD BE => 'normal' user having uploaded images can edit them. This requires 'user_id' and 'added_by'
        if NetworkVars.hasAdminRights ||
           (NetworkVars.hasNormalRights && userHasUploadRights) {
            cancelBarButton?.isEnabled = true
            actionBarButton?.isEnabled = hasImagesSelected
            shareBarButton?.isEnabled = hasImagesSelected
            deleteBarButton?.isEnabled = hasImagesSelected
            // pwg.users.favorites… methods available from Piwigo version 2.10
            if "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric, range: nil, locale: .current) != .orderedDescending {
                favoriteBarButton?.isEnabled = hasImagesSelected
                let areFavorites = CategoriesData.sharedInstance().category(withId: kPiwigoFavoritesCategoryId, containsImagesWithId: selectedImageIds)
                favoriteBarButton?.setFavoriteImage(for: areFavorites)
                favoriteBarButton?.action = areFavorites ? #selector(removeFromFavorites) : #selector(addToFavorites)
            }

            if #available(iOS 14, *) {
                } else {
                moveBarButton?.isEnabled = hasImagesSelected
            }
        } else {
            // Left side of navigation bar
            cancelBarButton?.isEnabled = true

            // Right side of navigation bar
            /// — guests can share photo of high-resolution or not
            /// — non-guest users can set favorites in addition
            shareBarButton?.isEnabled = hasImagesSelected
            if !NetworkVars.hasGuestRights,
               "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric, range: nil, locale: .current) != .orderedDescending {
                favoriteBarButton?.isEnabled = hasImagesSelected
                let areFavorites = CategoriesData.sharedInstance().category(withId: kPiwigoFavoritesCategoryId, containsImagesWithId: selectedImageIds)
                favoriteBarButton?.setFavoriteImage(for: areFavorites)
                favoriteBarButton?.action = areFavorites ? #selector(removeFromFavorites) : #selector(addToFavorites)
            }
        }
    }

    // Buttons are disabled (greyed) when retrieving image data
    // They are also disabled during an action
    func setEnableStateOfButtons(_ state: Bool) {
        cancelBarButton?.isEnabled = state
        actionBarButton?.isEnabled = state
        deleteBarButton?.isEnabled = state
        moveBarButton?.isEnabled = state
        shareBarButton?.isEnabled = state
        // pwg.users.favorites… methods available from Piwigo version 2.10
        if "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric, range: nil, locale: .current) != .orderedDescending {
            favoriteBarButton?.isEnabled = state
        }
    }


    // MARK: - Select Images
    @objc func didTapSelect() {
        // Activate Images Selection mode
        isSelect = true

        // Disable interaction with category cells and scroll to first image cell if needed
        var numberOfImageCells = 0
        for cell in imagesCollection?.visibleCells ?? []
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
        if numberOfImageCells == 0 {
            imagesCollection?.scrollToItem(at: IndexPath(row: 0, section: 1), at: .top, animated: true)
        }

        // Initialisae navigation bar and toolbar
        initButtonsInSelectionMode()
    }

    @objc func cancelSelect() {
        // Disable Images Selection mode
        isSelect = false

        // Update navigation bar and toolbar
        updateButtonsInPreviewMode()

        // Enable interaction with category cells and deselect image cells
        for cell in imagesCollection?.visibleCells ?? []
        {
            // Enable user interaction with category cell
            if let categoryCell = cell as? AlbumCollectionViewCell {
                categoryCell.contentView.alpha = 1.0
                categoryCell.isUserInteractionEnabled = true
            }

            // Deselect image cell and disable interaction
            if let imageCell = cell as? ImageCollectionViewCell,
               imageCell.isSelection {
                imageCell.isSelection = false
            }
        }

        // Clear array of selected images and allow iOS device to sleep
        touchedImageIds = []
        selectedImageIds = []
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Will examine touchs only in select mode
        if isSelect {
            return true
        }
        return false
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Will interpret touches only in horizontal direction
        if let gPR = gestureRecognizer as? UIPanGestureRecognizer {
            let translation = gPR.translation(in: imagesCollection)
            if abs(Float(translation.x)) > abs(Float(translation.y)) {
                return true
            }
        }
        return false
    }

    @objc func touchedImages(_ gestureRecognizer: UIPanGestureRecognizer?) {
        // Just in case…
        guard let gestureRecognizer = gestureRecognizer else { return }

        // Select/deselect cells
        switch gestureRecognizer.state {
        case .began, .changed:
            // Get touch point
            let point = gestureRecognizer.location(in: imagesCollection)

            // Get cell at touch position
            if let indexPath = imagesCollection?.indexPathForItem(at: point),
               indexPath.section == 1,
               let imageCell = imagesCollection?.cellForItem(at: indexPath) as? ImageCollectionViewCell,
               let imageId = imageCell.imageData?.imageId
            {
                // Update the selection if not already done
                let imageIdObject = NSNumber(value: imageId)
                if touchedImageIds.contains(imageIdObject) { return }

                // Store that the user touched this cell during this gesture
                touchedImageIds.append(imageIdObject)

                // Update the selection state
                if !selectedImageIds.contains(imageIdObject) {
                    selectedImageIds.append(imageIdObject)
                    imageCell.isSelection = true
                } else {
                    imageCell.isSelection = false
                    selectedImageIds.removeAll { $0 === imageIdObject }
                }

                // Update the navigation bar
                updateButtonsInSelectionMode()
            }
            
        case .ended:
            touchedImageIds = []
        default:
            debugPrint("NOP")
        }
    }


    // MARK: - Initialise Selection Before Action
    func initSelection(beforeAction action:pwgImageAction) {
        if selectedImageIds.isEmpty { return }

        // Disable buttons
        setEnableStateOfButtons(false)

        // Display HUD
        totalNumberOfImages = selectedImageIds.count
        showPiwigoHUD(withTitle: NSLocalizedString("loadingHUD_label", comment: "Loading…"),
                      detail: "", buttonTitle: "", buttonTarget: nil, buttonSelector: nil,
                      inMode: totalNumberOfImages > 1 ? .annularDeterminate : .indeterminate)

        // Add image to favorites?
        if action == .addToFavorites {
            addImageToFavorites()
            return
        }
        
        // Remove image from favorites?
        if action == .removeFromFavorites {
            removeImageFromFavorites()
            return
        }
        
        // Retrieve image data
        selectedImageData = []
        selectedImageIdsLoop = selectedImageIds.compactMap({$0.intValue})
        retrieveImageData(beforeAction: action)
    }

    func retrieveImageData(beforeAction action:pwgImageAction) {
        if selectedImageIdsLoop.isEmpty {
            hidePiwigoHUD() { [self] in
                switch action {
                case .edit:
                    // Edit images parameters
                    editImages()
                case .delete:
                    // Distinguish orphanes and ask for confirmation
                    askDeleteConfirmation()
                case .share:
                    // Check Photo Library access rights
                    checkPhotoLibraryAccessBeforeShare()
                case .addToFavorites, .removeFromFavorites:
                    // No need to retrieve image data
                    debugPrint("••> Did call retrieveImageData() before adding/removing images from favorites!?")
                }
            }
            return
        }

        // Check the provided image ID
        guard let imageId = selectedImageIdsLoop.last else {
            // Forget this image
            selectedImageIdsLoop.removeLast()
            
            // Update HUD
            updatePiwigoHUD(withProgress: 1.0 - Float(selectedImageIdsLoop.count) / Float(totalNumberOfImages))
            
            // Next image
            retrieveImageData(beforeAction: action)
            return
        }
        
        // Image data are not complete when retrieved using pwg.categories.getImages
        ImageUtilities.getInfos(forID: imageId,
                                inCategoryId: categoryId) { [self] imageData in
            // Store image data
            selectedImageData.insert(imageData, at: 0)

            // Image info retrieved
            selectedImageIdsLoop.removeLast()

            // Update HUD
            updatePiwigoHUD(withProgress: 1.0 - Float(selectedImageIdsLoop.count) / Float(totalNumberOfImages))

            // Next image
            retrieveImageData(beforeAction: action)
            
        } failure: { [self] error in
            // Failed — Ask user if he/she wishes to retry
            dismissRetryPiwigoError(withTitle: NSLocalizedString("imageDetailsFetchError_title", comment: "Image Details Fetch Failed"), message: NSLocalizedString("imageDetailsFetchError_retryMessage", comment: "Fetching the image data failed\nTry again?"), errorMessage: error.localizedDescription, dismiss: { [self] in
                hidePiwigoHUD() { [self] in
                    updateButtonsInSelectionMode()
                }
            }, retry: { [self] in
                // Try relogin if unauthorized
                if error.code == 401 {
                    let appDelegate = UIApplication.shared.delegate as? AppDelegate
                    appDelegate?.reloginAndRetry(afterRestoringScene: false) { [self] in
                        retrieveImageData(beforeAction: action)
                    }
                } else {
                    retrieveImageData(beforeAction: action)
                }
            })
        }
    }
}
