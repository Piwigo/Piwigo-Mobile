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
                          children: [imageCollectionVC.imagesCopyAction(),
                                     imageCollectionVC.imagesMoveAction()])
        return menu
    }
    
    
    // MARK: - Images Menu
    /// - for editing image parameters
    func imagesMenu() -> UIMenu {
        let menuId = UIMenu.Identifier("org.piwigo.piwigoImages.edit")
        let menu = UIMenu(title: "", image: nil, identifier: menuId,
                          options: UIMenu.Options.displayInline,
                          children: [imageCollectionVC.rotateMenu(),
                                     imageCollectionVC.editParamsAction()].compactMap({$0}))
        return menu
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
        // Should we really enable this mode?
        if albumData.nbImages == 0 {
            return
        }
        
        // Hide buttons
        hideButtons()
        
        // Activate Images Selection mode
        imageCollectionVC.isSelect = true
        
        // Disable interaction with album cells and scroll first image cells to top if needed
        let visibleAlbumCells = albumCollectionVC.collectionView?.visibleCells ?? []
        for cell in visibleAlbumCells {
            // Disable user interaction with category cell
            if let categoryCell = cell as? AlbumCollectionViewCell {
                categoryCell.contentView.alpha = 0.5
                categoryCell.isUserInteractionEnabled = false
            }
        }
        
        // Any album cell visible above the image collection?
        if let lastAlbumCell = visibleAlbumCells.last, let window = view.window
        {
            var fromCoordinateSpace = lastAlbumCell.coordinateSpace
            let toCoordinateSpace = window.screen.coordinateSpace
            var albumHeight = fromCoordinateSpace.convert(lastAlbumCell.bounds, to: toCoordinateSpace).maxY
            albumHeight -= navigationController?.navigationBar.bounds.height ?? 0.0
            if #available(iOS 13, *) {
                albumHeight -= window.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
            } else {
                albumHeight -= UIApplication.shared.statusBarFrame.height
            }
            if albumHeight > 0.0 {
                // Scroll to image cells to the top
                let row = hasAlbumDataToShow() ? 1 : 0
                let indexPathOfFirstImage = IndexPath(row: row, section: 0)
                albumImageTableView.scrollToRow(at: indexPathOfFirstImage, at: .top, animated: true)
            }
        }

        // Initialisae navigation bar and toolbar
        initBarsInSelectMode()
    }
    
    @objc func cancelSelect() {
        // Disable Images Selection mode
        imageCollectionVC.isSelect = false
        
        // Update navigation bar and toolbar
        initBarsInPreviewMode()
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
        imageCollectionVC.selectedVideosIds = Set<Int64>()
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
