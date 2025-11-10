//
//  AlbumViewController+Upload.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import Photos
import UIKit
import piwigoKit

extension AlbumViewController
{
    // MARK: Toolbar Buttons (iOS 26+)
    func getUploadQueueBarButton(withTitle title: String? = nil) -> UIBarButtonItem? {
        guard let title = title
        else { return nil }
        
        let button = UIBarButtonItem(title: title, style: .plain,
                                     target: self, action: #selector(didTapUploadQueueButton))
        button.accessibilityIdentifier = "showUploadQueue"
        return button
    }
    

    // MARK: - Button Management
    @MainActor
    func showUploadQueueButton() {
        // Show upload queue button only in default album
        guard [0, AlbumVars.shared.defaultCategory].contains(categoryId)
        else { return }
        
        if #available(iOS 26.0, *) {
            // Already shown?
            if (toolbarItems ?? []).count == 3  {
                // Add button to toolbar
                let searchBarButton = navigationItem.searchBarPlacementBarButtonItem
                let toolBarItems = [uploadQueueBarButton, .space(), addAlbumBarButton, searchBarButton].compactMap { $0 }
                setToolbarItems(toolBarItems, animated: true)
            }
        } else {
            showOldUploadQueueButton()
        }
    }
    
    @MainActor
    func hideUploadQueueButton() {
        // The upload queue button is only presented in the default album
        guard [0, AlbumVars.shared.defaultCategory].contains(categoryId)
        else { return }
        
        if #available(iOS 26.0, *) {
            // Currently shown?
            var toolbarItems = toolbarItems ?? []
            if toolbarItems.count == 4 {
                // Remove UploadQueue button from toolbar when the root album is visible
                toolbarItems.removeFirst()
                setToolbarItems(toolbarItems, animated: true)
            }
        } else {
            hideOldUploadQueueButton()
        }
    }
    
    @MainActor
    @objc func updateNberOfUploads(_ notification: Notification?) {
        // Update main header if necessary
        setTableViewMainHeader()

        // Update upload queue button only in default album
        guard [0, AlbumVars.shared.defaultCategory].contains(categoryId),
              let nberOfUploads = (notification?.userInfo?["nberOfUploadsToComplete"] as? Int)
        else { return }

        // Upload completed?
        if nberOfUploads <= 0 {
            // Hide button if not already hidden
            hideUploadQueueButton()
            return
        }
        
        // Uploading: Update button?
        if #available(iOS 26.0, *) {
            if (!NetworkVars.shared.isConnectedToWiFi && UploadVars.shared.wifiOnlyUploading) ||
                ProcessInfo.processInfo.isLowPowerModeEnabled {
                if uploadQueueBarButton == nil {
                    uploadQueueBarButton = getUploadQueueBarButton(withTitle: "⚠️")!
                } else {
                    uploadQueueBarButton?.title = "⚠️"
                }
            } else {
                // Set number of uploads
                let nber = String(format: "%lu", UInt(nberOfUploads))
                if uploadQueueBarButton == nil {
                    uploadQueueBarButton = getUploadQueueBarButton(withTitle: nber)!
                } else if let currentTitle = uploadQueueBarButton?.title,
                          nber.compare(currentTitle) == .orderedSame,
                          uploadQueueBarButton?.isHidden ?? true == false {
                    // Nothing changed ► NOP
                    return
                }
                uploadQueueBarButton?.title = nber
            }
            
            // Resize and show button if needed
            showUploadQueueButton()
        }
        else {
            updateOldButton(withNberOfUploads: nberOfUploads)
        }
    }
    
    
    // MARK: - Upload Actions
    @objc func didTapUploadImagesButton() {
        // Hide CreateAlbum and UploadImages buttons
        hideOptionalButtons { [self] in
            // Check autorisation to access Photo Library before uploading
            checkPhotoLibraryAccess()

            // Reset appearance and action of Add button
            showAddButton { [self] in
                addButton.removeTarget(self, action: #selector(didCancelTapAddButton), for: .touchUpInside)
                addButton.addTarget(self, action: #selector(didTapAddButton), for: .touchUpInside)
            }

            // Show button on the left of the Add button if needed
            if ![0, AlbumVars.shared.defaultCategory].contains(categoryId) {
                // Show Home button if not in root or default album
                showHomeAlbumButtonIfNeeded()
            }
        }
    }
    
    @objc func checkPhotoLibraryAccess() {
        PhotosFetch.shared.checkPhotoLibraryAuthorizationStatus(for: PHAccessLevel.readWrite, for: self, onAccess: { [self] in
            // Open local albums view controller in new navigation controller
            DispatchQueue.main.async {
                self.presentLocalAlbums()
            }
        }, onDeniedAccess: { })
    }
    
    @MainActor
    private func presentLocalAlbums() {
        // Open local albums view controller in new navigation controller
        let localAlbumsSB = UIStoryboard(name: "LocalAlbumsViewController", bundle: nil)
        guard let localAlbumsVC = localAlbumsSB.instantiateViewController(withIdentifier: "LocalAlbumsViewController") as? LocalAlbumsViewController
        else { preconditionFailure("Cloud not load LocalAlbumsViewController") }
        localAlbumsVC.categoryId = categoryId
        localAlbumsVC.categoryCurrentCounter = albumData.currentCounter
        localAlbumsVC.albumDelegate = self
        localAlbumsVC.user = user
        let navController = UINavigationController(rootViewController: localAlbumsVC)
        navController.modalTransitionStyle = .coverVertical
        navController.modalPresentationStyle = .pageSheet
        present(navController, animated: true)
    }

    @MainActor
    @objc func didTapUploadQueueButton() {
        // Open upload queue controller in new navigation controller
        let uploadQueueSB = UIStoryboard(name: "UploadQueueViewController", bundle: nil)
        guard let uploadQueueVC = uploadQueueSB.instantiateViewController(withIdentifier: "UploadQueueViewController") as? UploadQueueViewController
        else { preconditionFailure("Could not load UploadQueueViewController") }
        let navController = UINavigationController(rootViewController: uploadQueueVC)
        navController.modalTransitionStyle = .coverVertical
        navController.modalPresentationStyle = .formSheet
        present(navController, animated: true)
    }
}


// MARK: - AlbumViewControllerDelegate Methods
extension AlbumViewController: AlbumViewControllerDelegate {
    func didSelectCurrentCounter(value: Int64) {
        albumData.currentCounter = value
        mainContext.saveIfNeeded()
    }
}
