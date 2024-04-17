//
//  AlbumImageTableViewController+Select.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

@available(iOS 14, *)
extension AlbumImageTableViewController
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
                          children: [imagesCopyAction(), imagesMoveAction()])
        return menu
    }
    
    private func imagesCopyAction() -> UIAction {
        let actionId = UIAction.Identifier("Copy")
        let action = UIAction(title: NSLocalizedString("copyImage_title", comment: "Copy to Album"),
                              image: UIImage(systemName: "rectangle.stack.badge.plus"),
                              identifier: actionId, handler: { [self] action in
            // Disable buttons during action
            setEnableStateOfButtons(false)
            // Retrieve complete image data before copying images
            imageCollectionVC.initSelection(beforeAction: .copyImages)
        })
        action.accessibilityIdentifier = "copy"
        return action
    }
    
    private func imagesMoveAction() -> UIAction {
        let actionId = UIAction.Identifier("Move")
        let action = UIAction(title: NSLocalizedString("moveImage_title", comment: "Move to Album"),
                              image: UIImage(systemName: "arrowshape.turn.up.right"),
                              identifier: actionId, handler: { [self] action in
            // Disable buttons during action
            setEnableStateOfButtons(false)
            // Retrieve complete image data before moving images
            imageCollectionVC.initSelection(beforeAction: .moveImages)
        })
        action.accessibilityIdentifier = "move"
        return action
    }
    
    
    // MARK: - Images Menu
    /// - for editing image parameters
    func imagesMenu() -> UIMenu {
        let menuId = UIMenu.Identifier("org.piwigo.piwigoImage.edit")
        let menu = UIMenu(title: "", image: nil, identifier: menuId,
                          options: UIMenu.Options.displayInline,
                          children: [editParamsAction()])
        return menu
    }

    private func editParamsAction() -> UIAction {
        let actionId = UIAction.Identifier("Edit Parameters")
        let action = UIAction(title: NSLocalizedString("imageOptions_properties", comment: "Modify Information"),
                              image: UIImage(systemName: "pencil"),
                              identifier: actionId, handler: { [self] action in
           // Edit image informations
            imageCollectionVC.editSelection()
        })
        return action
    }
}


// MARK: - Select Buttons
extension AlbumImageTableViewController
{
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


// MARK: - Selection Management
extension AlbumImageTableViewController
{
    @objc func didTapSelect() {
        // Hide buttons
        hideButtons()
        
        // Activate Images Selection mode
        imageCollectionVC.isSelect = true
        
        // Disable interaction with album cells and scroll to first image cell if needed
        var numberOfImageCells = 0
        for cell in albumCollectionVC.collectionView?.visibleCells ?? [] {
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
        if numberOfImageCells == 0, albumData.nbImages != 0 {
            let indexPathOfFirstImage = IndexPath(row: 1, section: 0)
            albumImageTableView.scrollToRow(at: indexPathOfFirstImage, at: .top, animated: true)
        }
        
        // Initialisae navigation bar and toolbar
        initBarsInSelectMode()
    }
    
    @objc func cancelSelect() {
        // Disable Images Selection mode
        imageCollectionVC.isSelect = false
        
        // Update navigation bar and toolbar
        updateBarsInPreviewMode()
        updateButtons()
        
        // Enable interaction with album cells and deselect image cells
        for cell in albumCollectionVC.collectionView?.visibleCells ?? [] {
            // Enable user interaction with album cell
            if let albumCell = cell as? AlbumCollectionViewCell {
                albumCell.contentView.alpha = 1.0
                albumCell.isUserInteractionEnabled = true
            }
        }
        
        // Deselect image cells
        for cell in imageCollectionVC.collectionView?.visibleCells ?? [] {
            // Deselect image cell and disable interaction
            if let imageCell = cell as? ImageCollectionViewCell,
               imageCell.isSelection {
                imageCell.isSelection = false
            }
        }
        
        // Clear array of selected images and allow iOS device to sleep
        imageCollectionVC.touchedImageIds = []
        imageCollectionVC.selectedImageIds = Set<Int64>()
        imageCollectionVC.selectedFavoriteIds = Set<Int64>()
        UIApplication.shared.isIdleTimerDisabled = false
    }
}


extension AlbumImageTableViewController: ImageSelectionCollectionViewDelegate
{
    func updatePreviewMode() {
        updateBarsInPreviewMode()
    }
    
    func updateSelectMode() {
        updateBarsInSelectMode()
    }
    
    func setButtonsState(_ enabled: Bool) {
        setEnableStateOfButtons(enabled)
    }
    
    func pushSelectionToView(_ viewController: UIViewController?) {
        pushView(viewController)
    }
    
    func deselectImages() {
        cancelSelect()
    }
}
