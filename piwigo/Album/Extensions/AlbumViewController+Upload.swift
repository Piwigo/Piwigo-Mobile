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
import PwgKit
import PwgCacheKit

extension AlbumViewController
{
    // MARK: Toolbar Buttons
    @MainActor @available(iOS 26.0, *)
    func getUploadQueueBarButton(withTitle title: String? = nil) -> UIBarButtonItem? {
        guard let title = title
        else { return nil }
        
        let button = UIBarButtonItem()
        button.style = .plain
        button.target = self
        button.action = #selector(didTapUploadQueueButton)
        button.accessibilityIdentifier = "showUploadQueue"
        if title == "⚠️" {
            let config = UIImage.SymbolConfiguration(pointSize: 17)
            button.image = UIImage(systemName: "photo.badge.exclamationmark", withConfiguration: config)
        } else {
            button.title = title
        }
        return button
    }
    
    
    // MARK: - Button Management
    @MainActor @available(iOS 26.0, *)
    func setUploadQueueButton(withNberOfUploads nberOfUploads: Int) {
        
        if (!ServerVars.shared.isConnectedToWiFi && UploadVars.shared.wifiOnlyUploading) ||
            [.serious, .critical].contains(ProcessInfo.processInfo.thermalState) ||
            ProcessInfo.processInfo.isLowPowerModeEnabled {
            if uploadQueueBarButton == nil {
                uploadQueueBarButton = getUploadQueueBarButton(withTitle: "⚠️")!
            }
            else {
                let config = UIImage.SymbolConfiguration(pointSize: 17)
                uploadQueueBarButton?.image = UIImage(systemName: "photo.badge.exclamationmark", withConfiguration: config)
            }
        } else {
            // Set number of uploads
            let nber = String(format: "%lu", UInt(nberOfUploads))
            if uploadQueueBarButton == nil {
                uploadQueueBarButton = getUploadQueueBarButton(withTitle: nber)!
            }
            else if let currentTitle = uploadQueueBarButton?.title,
                      nber.compare(currentTitle) == .orderedSame,
                      uploadQueueBarButton?.isHidden ?? true == false {
                // Nothing changed ► NOP
            }
            else {
                uploadQueueBarButton?.image = nil
                uploadQueueBarButton?.title = nber
            }
        }
    }
    
    @MainActor
    @objc func updateNberOfUploads(_ notification: Notification?) {
        // Update main header if necessary
        setTableViewMainHeader()
        
        // Show/hide upload queue button
        if #available(iOS 26.0, *) {
            // Update upload queue button only in root and regular albums
            guard categoryId > 0
            else { return }
            updateBarsInModernPreviewMode()
        }
        else {
            // Fallback on previous version
            // Update upload queue button only in default album
            guard [0, AlbumVars.shared.defaultCategory].contains(categoryId),
                  let nberOfUploads = (notification?.userInfo?["nberOfUploadsToComplete"] as? Int)
            else { return }
            if nberOfUploads <= 0 {
                hideOldUploadQueueButton()
            } else {
                updateOldButton(withNberOfUploads: nberOfUploads)
            }
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
        localAlbumsVC.userData = userData
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
extension AlbumViewController: @MainActor AlbumViewControllerDelegate {
    func didSelectCurrentCounter(value: Int64) {
        // Save counter value if needed
        if value != albumData.currentCounter {
            albumData.currentCounter = value
            try? albumProvider.updateAlbum(withProperties: albumData, inContext: mainContext)
        }
    }
}
