//
//  LocalImagesViewController+Menus.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 17 August 2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import Photos
import UIKit
import piwigoKit
import uploadKit

// MARK: Menus
extension LocalImagesViewController {
    
    // MARK: - Swap Sort Order
    func swapOrderAction() -> UIAction {
        // Initialise menu items
        let swapOrder: UIAction!
        switch UploadVars.shared.localImagesSort {
        case .dateCreatedAscending:
            swapOrder = UIAction(title: NSLocalizedString("Date", comment: "Date"),
                                 image: UIImage(systemName: "arrow.up"), handler: { _ in self.swapSortOrder()})
        case .dateCreatedDescending:
            swapOrder = UIAction(title: NSLocalizedString("Date", comment: "Date"),
                                 image: UIImage(systemName: "arrow.down"), handler: { _ in self.swapSortOrder()})
        default:
            swapOrder = UIAction(title: NSLocalizedString("Date", comment: "Date"),
                                 image: nil, handler: { _ in self.swapSortOrder()})
        }
        swapOrder.accessibilityIdentifier = "Date"
        return swapOrder
    }
    
    @objc func swapSortOrder() {
        // Swap between the two sort options
        switch UploadVars.shared.localImagesSort {
        case .dateCreatedDescending:
            UploadVars.shared.localImagesSort = .dateCreatedAscending
        case .dateCreatedAscending:
            UploadVars.shared.localImagesSort = .dateCreatedDescending
        default:
            return
        }
        
        // Change button icon and refresh collection
        reloadCollectionAndUpdateMenu()
    }
    
    private func reloadCollectionAndUpdateMenu() {
        // May be called from background queue
        DispatchQueue.main.async {
            self.updateActionButton()
            self.updateNavBar()
            self.localImagesCollection.reloadData()
        }
    }
    
    
    // MARK: - Group Images
    func groupMenu() -> UIMenu {
        // Create a menu for selecting how to group images
        let children = [byDayAction(), byWeekAction(), byMonthAction(), byNoneAction()].compactMap({$0})
        return UIMenu(title: NSLocalizedString("categoryView_group", comment: "Group Images By…"),
                      image: nil,
                      identifier: UIMenu.Identifier("org.piwigo.images.group.main"),
                      options: UIMenu.Options.displayInline,
                      children: children)
    }
    
    func byDayAction() -> UIAction {
        let isActive = sortType == .day
        let action = UIAction(title: NSLocalizedString("Day", comment: "Day"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: UIAction.Identifier("org.piwigo.images.group.day"),
                              handler: { [self] action in
            // Should image grouping be changed?
            if isActive { return }
            
            // Change image grouping
            self.sortType = .day
            self.reloadCollectionAndUpdateMenu()
        })
        action.accessibilityIdentifier = "groupByDay"
        return action
    }
    
    func byWeekAction() -> UIAction {
        let isActive = sortType == .week
        let action = UIAction(title: NSLocalizedString("Week", comment: "Week"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: UIAction.Identifier("org.piwigo.images.group.week"),
                              handler: { [self] action in
            // Should image grouping be changed?
            if isActive { return }
            
            // Change image grouping
            self.sortType = .week
            self.reloadCollectionAndUpdateMenu()
        })
        action.accessibilityIdentifier = "groupByWeek"
        return action
    }
    
    func byMonthAction() -> UIAction {
        let isActive = sortType == .month
        let action = UIAction(title: NSLocalizedString("Month", comment: "Month"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: UIAction.Identifier("org.piwigo.images.group.month"),
                              handler: { [self] action in
            // Should sorting be changed?
            if isActive { return }
            
            // Should image grouping be changed?
            self.sortType = .month
            self.reloadCollectionAndUpdateMenu()
        })
        action.accessibilityIdentifier = "groupByMonth"
        return action
    }
    
    func byNoneAction() -> UIAction {
        let isActive = sortType == .none
        let action = UIAction(title: NSLocalizedString("None", comment: "None"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: UIAction.Identifier("org.piwigo.images.group.none"),
                              handler: { [self] action in
            // Should image grouping be changed?
            if isActive { return }
            
            // Change image grouping
            self.sortType = .none
            self.reloadCollectionAndUpdateMenu()
        })
        action.accessibilityIdentifier = "groupByNone"
        return action
    }
    
    @IBAction func didChangeGroupOption(_ sender: UISegmentedControl) {
        // Did select new group option [Day, Week, Month, None in one section]
        sortType = SectionType(rawValue: sender.selectedSegmentIndex) ?? .none
        
        // Change button icon and refresh collection
        self.reloadCollectionAndUpdateMenu()
    }
    
    
    // MARK: - Select Camera Roll Images
    func selectPhotosMenu() -> UIMenu? {
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited {
            // Proposes to change the Photo Library selection
            let selector = UIAction(title: NSLocalizedString("localAlbums_accessible", comment: "Accessible Photos"),
                                    image: UIImage(systemName: "camera"), handler: { _ in
                // Proposes to change the Photo Library selection
                PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self)
            })
            return UIMenu(title: "", image: nil,
                          identifier: UIMenu.Identifier("org.piwigo.localImages.selector"),
                          options: .displayInline,
                          children: [selector])
        }
        return nil
    }
    

    // MARK: - Re-Upload Photos
    func reUploadAction() -> UIAction? {
        // Check if there are already uploaded photos
        if !canDeleteUploadedImages() { return nil }
        
        // Propose option for re-uploading photos
        let reUpload = UIAction(title: NSLocalizedString("localImages_reUploadTitle", comment: "Re-upload"),
                                image: reUploadAllowed ? UIImage(systemName: "checkmark") : nil, handler: { _ in
            self.swapReuploadOption()
        })
        reUpload.accessibilityIdentifier = "org.piwigo.reupload"
        return reUpload
    }
    
    private func swapReuploadOption() {
        // Swap "Re-upload" option
        reUploadAllowed = !(self.reUploadAllowed)
        updateActionButton()

        // Refresh section buttons if re-uploading is allowed
        if reUploadAllowed == false {
            // Get visible cells
            let visibleCells = localImagesCollection.visibleCells as? [LocalImageCollectionViewCell]

            // Deselect already uploaded photos if needed
            if (queue.operationCount == 0) && (selectedImages.count < indexedUploadsInQueue.count) {
                // Indexed uploads available
                for index in 0..<selectedImages.count {
                    if let upload = indexedUploadsInQueue[index],
                       [.finished, .moderated].contains(upload.1) {
                        // Deselect cell
                        selectedImages[index] = nil
                        if let cells = visibleCells,
                           let cell = cells.first(where: {$0.localIdentifier == upload.0}) {
                            cell.update(selected: false, state: upload.1)
                        }
                    }
                }
            } else {
                // Use non-indexed data (might be quite slow)
                let completed = (uploads.fetchedObjects ?? []).filter({[.finished, .moderated].contains($0.state)})
                for index in 0..<selectedImages.count {
                    if let localIdentifier = selectedImages[index]?.localIdentifier,
                       let upload = completed.first(where: {$0.localIdentifier == localIdentifier}) {
                        selectedImages[index] = nil
                        if let cells = visibleCells,
                           let cell = cells.first(where: {$0.localIdentifier == upload.localIdentifier}) {
                            cell.update(selected: false, state: upload.state)
                        }
                    }
                }
            }
        }
        
        // Update section buttons
        let headers = localImagesCollection.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader)
        headers.forEach { header in
            if let sectionHeader = header as? LocalImagesHeaderReusableView {
                let selectState = updateSelectButton(ofSection: sectionHeader.section)
                sectionHeader.selectButton.setTitle(forState: selectState)
            }
        }
        self.updateNavBar()
    }
        

    // MARK: - Delete Camera Roll Images
    func deleteMenu() -> UIMenu? {
        // Check if there are already uploaded photos that can be deleted
        if canDeleteUploadedImages() == false,
           canDeleteSelectedImages() == false { return nil }
        
        // Propose option for deleting photos
        let delete = UIAction(title: NSLocalizedString("localImages_deleteTitle", comment: "Remove from Camera Roll"),
                              image: UIImage(systemName: "trash"), attributes: .destructive, handler: { _ in
            // Delete uploaded photos from the camera roll
            self.deleteUploadedImages()
        })
        let menuId = UIMenu.Identifier("org.piwigo.removeFromCameraRoll")
        return UIMenu(identifier: menuId, options: UIMenu.Options.displayInline, children: [delete])
    }
    
    @objc func deleteUploadedImages() {
        // Delete uploaded images (fetched on the main queue)
        var uploadsToDelete = [Upload]()
        let indexedUploads = self.indexedUploadsInQueue.compactMap({$0})
        let completed = (uploads.fetchedObjects ?? []).filter({[.finished, .moderated].contains($0.state)})
        for index in 0..<indexedUploads.count {
            if let upload = completed.first(where: {$0.localIdentifier == indexedUploads[index].0}),
               indexedUploads[index].2 {
                uploadsToDelete.append(upload)
            }
        }
        
        // Delete selected images
        let assetsToDelete = selectedImages.compactMap({$0?.localIdentifier}).compactMap({$0})
        
        // Anything to delete? (should always be true)
        if assetsToDelete.isEmpty, uploadsToDelete.isEmpty {
            return
        }
        
        // Ask for confirmation
        let title = NSLocalizedString("localImages_deleteTitle", comment: "Remove from Camera Roll")
        let message = NSLocalizedString("localImages_deleteMessage", comment: "Message explaining what will happen")
        let alert = UIAlertController(title: "", message: message, preferredStyle: .alert)
        let defaultAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
            style: .cancel, handler: { action in })
        let deleteAction = UIAlertAction(title: title, style: .destructive, handler: { action in
            // Delete images and upload requests
            let uploadIDs = uploadsToDelete.map(\.objectID)
            let uploadLocalIDs = uploadsToDelete.map(\.localIdentifier)
            Task { @UploadManagement in
                UploadManager.shared.deleteAssets(associatedToUploads: uploadIDs, uploadLocalIDs, and: assetsToDelete)
            }
        })
        alert.addAction(defaultAction)
        alert.addAction(deleteAction)
        alert.view.tintColor = PwgColor.tintColor
        alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        self.present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = PwgColor.tintColor
        }
    }
}
