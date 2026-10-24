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
import PwgKit
import PwgCacheKit
import PwgUIKit
import PwgUploadKit

// MARK: Menus
extension LocalImagesViewController {
    
    // MARK: - Swap Sort Order
    func swapOrderAction() -> UIAction {
        // Initialise menu items
        let swapOrder: UIAction!
        switch UploadVars.shared.localImagesSort {
        case .dateCreatedAscending:
            swapOrder = UIAction(title: String(localized: "Date", comment: "Date"),
                                 image: UIImage(systemName: "arrow.up"), handler: { [weak self] _ in self?.swapSortOrder()})
        case .dateCreatedDescending:
            swapOrder = UIAction(title: String(localized: "Date", comment: "Date"),
                                 image: UIImage(systemName: "arrow.down"), handler: { [weak self] _ in self?.swapSortOrder()})
        default:
            swapOrder = UIAction(title: String(localized: "Date", comment: "Date"),
                                 image: nil, handler: { [weak self] _ in self?.swapSortOrder()})
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
    
    func reloadCollectionAndUpdateMenu() {
        // May be called from background queue
        DispatchQueue.main.async {
            // Remember the image shown at the top, to show it again after the change
            let anchor = self.indexOfFirstVisibleImage()
            self.updateLayout()
            self.updateActionButton()
            self.updateNavBar()
            self.localImagesCollection.reloadData()
            if let anchor { self.scrollTo(imageAt: anchor) }
        }
    }
    
    /// Groups the images by day, week or month, or does not group them. The sections of the groupings are built
    /// in the background when the view opens: if they are not ready yet, the change waits for them.
    func changeGrouping(to newType: SectionType) {
        sortType = newType
        UploadVars.shared.localImagesGroupingRaw = Int16(newType.rawValue)       // Remembered for next time
        if newType != .none, layouts == nil {
            isWaitingForSections = true
            showHUD(withTitle: String(localized: "editImageDetailsHUD_updatingPlural", comment: "Updating Photos…"))
            updateActionButton()
            return
        }
        reloadCollectionAndUpdateMenu()
    }
    
    
    // MARK: - Group Images
    func groupMenu() -> UIMenu {
        // Create a menu for selecting how to group images
        let children = [byDayAction(), byWeekAction(), byMonthAction(), byNoneAction()].compactMap({$0})
        return UIMenu(title: String(localized: "categoryView_group", comment: "Group Images By…"),
                      image: nil,
                      identifier: UIMenu.Identifier("org.piwigo.images.group.main"),
                      options: UIMenu.Options.displayInline,
                      children: children)
    }
    
    func byDayAction() -> UIAction {
        let isActive = sortType == .day
        let action = UIAction(title: String(localized: "Day", comment: "Day"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: UIAction.Identifier("org.piwigo.images.group.day"),
                              handler: { [weak self] action in
            guard let self else { return }
            // Should image grouping be changed?
            if isActive { return }
            
            // Change image grouping
            self.changeGrouping(to: .day)
        })
        action.accessibilityIdentifier = "groupByDay"
        return action
    }
    
    func byWeekAction() -> UIAction {
        let isActive = sortType == .week
        let action = UIAction(title: String(localized: "Week", comment: "Week"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: UIAction.Identifier("org.piwigo.images.group.week"),
                              handler: { [weak self] action in
            guard let self else { return }
            // Should image grouping be changed?
            if isActive { return }
            
            // Change image grouping
            self.changeGrouping(to: .week)
        })
        action.accessibilityIdentifier = "groupByWeek"
        return action
    }
    
    func byMonthAction() -> UIAction {
        let isActive = sortType == .month
        let action = UIAction(title: String(localized: "Month", comment: "Month"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: UIAction.Identifier("org.piwigo.images.group.month"),
                              handler: { [weak self] action in
            guard let self else { return }
            // Should sorting be changed?
            if isActive { return }
            
            // Should image grouping be changed?
            self.changeGrouping(to: .month)
        })
        action.accessibilityIdentifier = "groupByMonth"
        return action
    }
    
    func byNoneAction() -> UIAction {
        let isActive = sortType == .none
        let action = UIAction(title: String(localized: "None", comment: "None"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: UIAction.Identifier("org.piwigo.images.group.none"),
                              handler: { [weak self] action in
            guard let self else { return }
            // Should image grouping be changed?
            if isActive { return }
            
            // Change image grouping
            self.changeGrouping(to: .none)
        })
        action.accessibilityIdentifier = "groupByNone"
        return action
    }
    
    @IBAction func didChangeGroupOption(_ sender: UISegmentedControl) {
        // Did select new group option [Day, Week, Month, None in one section]
        changeGrouping(to: SectionType(rawValue: sender.selectedSegmentIndex) ?? .none)
    }
    
    
    // MARK: - Select Camera Roll Images
    func selectPhotosMenu() -> UIMenu? {
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited {
            // Proposes to change the Photo Library selection
            let selector = UIAction(title: String(localized: "localAlbums_accessible", comment: "Accessible Photos"),
                                    image: UIImage(systemName: "camera"), handler: { [weak self] _ in
                guard let self else { return }
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
        let reUpload = UIAction(title: String(localized: "localImages_reUploadTitle", comment: "Re-upload"),
                                image: reUploadAllowed ? UIImage(systemName: "checkmark") : nil, handler: { [weak self] _ in
            self?.swapReuploadOption()
        })
        reUpload.accessibilityIdentifier = "org.piwigo.reupload"
        return reUpload
    }
    
    private func swapReuploadOption() {
        // Swap "Re-upload" option
        reUploadAllowed = !(self.reUploadAllowed)
        updateActionButton()

        // Deselect already uploaded photos if re-uploading is no longer allowed
        if reUploadAllowed == false {
            let completed = Set((uploads.fetchedObjects ?? [])
                .filter({[.finished, .moderated].contains($0.state)}).map(\.localIdentifier))
            selection.remove(IndexSet(completed.compactMap({ uploadPositions[$0] })))
            updateVisibleCells()
        }
        
        // Update section buttons
        updateVisibleSelectButtons()
        self.updateNavBar()
    }
        

    // MARK: - Delete Camera Roll Images
    func deleteMenu() -> UIMenu? {
        // Check if there are already uploaded photos that can be deleted
        if canDeleteUploadedImages() == false,
           canDeleteSelectedImages() == false { return nil }
        
        // Propose option for deleting photos
        let delete = UIAction(title: String(localized: "localImages_deleteTitle", comment: "Remove from Camera Roll"),
                              image: UIImage(systemName: "trash"), attributes: .destructive, handler: { [weak self] _ in
            // Delete uploaded photos from the camera roll
            self?.deleteUploadedImages()
        })
        let menuId = UIMenu.Identifier("org.piwigo.removeFromCameraRoll")
        return UIMenu(identifier: menuId, options: UIMenu.Options.displayInline, children: [delete])
    }
    
    @objc func deleteUploadedImages() {
        // Uploaded images (fetched on the main queue) and selected images
        let completed = (uploads.fetchedObjects ?? []).filter({[.finished, .moderated].contains($0.state)})
        let uploadsToDelete = completed.filter({ deletableUploads.contains($0.localIdentifier) })
        let selectedPositions = selection.positions
        let assets = PhotoLibraryAssets(fetchedImages)
        
        // Anything to delete? (should always be true)
        if uploadsToDelete.isEmpty, selectedPositions.isEmpty {
            return
        }
        
        // Ask for confirmation
        let title = String(localized: "localImages_deleteTitle", comment: "Remove from Camera Roll")
        let message = String(localized: "localImages_deleteMessage", comment: "Message explaining what will happen")
        let alert = UIAlertController(title: "", message: message, preferredStyle: .alert)
        let defaultAction = UIAlertAction(title: Localized.cancel,
                                          style: .cancel, handler: { action in })
        let deleteAction = UIAlertAction(title: title, style: .destructive, handler: { action in
            // Delete images and upload requests
            let uploadIDs = uploadsToDelete.map(\.objectID)
            let uploadedAssetIDs = uploadsToDelete.map(\.localIdentifier)
            Task { @MainActor in
                // Identifiers of the selected images (reading a very large selection takes a while)
                let selectedAssetIDs = await assets.identifiers(at: selectedPositions) ?? []
                let assetIDsToDelete = Set(uploadedAssetIDs).union(selectedAssetIDs)
                let assetsToDelete = PHAsset.fetchAssets(withLocalIdentifiers: Array(assetIDsToDelete), options: nil)
                do {
                    // Delete image from Photo Library
                    try await PHPhotoLibrary.shared().performChanges {
                        PHAssetChangeRequest.deleteAssets(assetsToDelete as (any NSFastEnumeration))
                    }
                    
                    // Delete associated upload request if any
                    Task { @UploadManagerActor in
                        // Delete upload requests w/o reporting potential error
                        try? UploadProvider().deleteUploads(withID: uploadIDs, inContext: UploadManager.shared.uploadBckgContext)
                    }
                }
                catch {
                    Task { @UploadManagerActor in
                        UploadManager.shared.disableDeleteAfterUpload(uploadIDs)
                    }
                }
            }
        })
        alert.addAction(defaultAction)
        alert.addAction(deleteAction)
        alert.view.tintColor = PwgColor.tintColor
        alert.overrideUserInterfaceStyle = UIVars.shared.isDarkPaletteActive ? .dark : .light
        self.present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = PwgColor.tintColor
        }
    }
}
