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
    private func setNavBarWithUploadQueueButton() {
        // Show upload queue button only in default album
        guard [0, AlbumVars.shared.defaultCategory].contains(categoryId),
              uploadQueueBarButton != nil
        else { return }
        
        // Reset the navigation bar
        switch view.traitCollection.userInterfaceIdiom {
        case .phone:
            // Search and other buttons in the toolbar
            navigationItem.preferredSearchBarPlacement = .integratedButton
            let searchBarButton = navigationItem.searchBarPlacementBarButtonItem
            let toolBarItems = [uploadQueueBarButton, .space(), addAlbumBarButton, searchBarButton].compactMap { $0 }
            navigationController?.setToolbarHidden(false, animated: true)
            setToolbarItems(toolBarItems, animated: true)
            
        case .pad:
            // Right side of the navigation bar
            navigationItem.preferredSearchBarPlacement = .integrated
            let items = [discoverBarButton, addAlbumBarButton, .fixedSpace(16.0), uploadQueueBarButton].compactMap { $0 }
            navigationItem.setRightBarButtonItems(items, animated: true)
            
        default:
            preconditionFailure("!!! Interface not managed !!!")
        }
    }
    
    @MainActor @available(iOS 26.0, *)
    func setNavBarWithUploadQueueButton(andNberOfUploads nberOfUploads: Int) {
        guard [0, AlbumVars.shared.defaultCategory].contains(categoryId),
              nberOfUploads > 0
        else { return }
        
        if (!NetworkVars.shared.isConnectedToWiFi && UploadVars.shared.wifiOnlyUploading) ||
            ProcessInfo.processInfo.isLowPowerModeEnabled {
            if uploadQueueBarButton == nil {
                uploadQueueBarButton = getUploadQueueBarButton(withTitle: "⚠️")!
                setNavBarWithUploadQueueButton()
            } else {
                uploadQueueBarButton?.title = "⚠️"
            }
        } else {
            // Set number of uploads
            let nber = String(format: "%lu", UInt(nberOfUploads))
            if uploadQueueBarButton == nil {
                uploadQueueBarButton = getUploadQueueBarButton(withTitle: nber)!
                setNavBarWithUploadQueueButton()
            }
            else if let currentTitle = uploadQueueBarButton?.title,
                      nber.compare(currentTitle) == .orderedSame,
                      uploadQueueBarButton?.isHidden ?? true == false {
                // Nothing changed ► NOP
                return
            } else {
                uploadQueueBarButton?.title = nber
            }
        }
    }
    
    @MainActor @available(iOS 26.0, *)
    func setNavBarWithoutUploadQueueButton() {
        // The upload queue button is only presented in the default album
        guard [0, AlbumVars.shared.defaultCategory].contains(categoryId)
        else { return }
        
        // Reset the navigation bar
        switch view.traitCollection.userInterfaceIdiom {
        case .phone:
            // Search and other buttons in the toolbar
            navigationItem.preferredSearchBarPlacement = .integratedButton
            let searchBarButton = navigationItem.searchBarPlacementBarButtonItem
            let toolBarItems = [.space(), addAlbumBarButton, searchBarButton].compactMap { $0 }
            navigationController?.setToolbarHidden(false, animated: true)
            setToolbarItems(toolBarItems, animated: true)
            
        case .pad:
            // Right side of the navigation bar
            navigationItem.preferredSearchBarPlacement = .integrated
            let items = [discoverBarButton, addAlbumBarButton, .fixedSpace(16.0)].compactMap { $0 }
            navigationItem.setRightBarButtonItems(items, animated: true)
            
        default:
            preconditionFailure("!!! Interface not managed !!!")
        }
        
        // Deinitialise the button
        uploadQueueBarButton = nil
    }
    
    @MainActor
    @objc func updateNberOfUploads(_ notification: Notification?) {
        // Update main header if necessary
        setTableViewMainHeader()

        // Update upload queue button only in default album
        guard [0, AlbumVars.shared.defaultCategory].contains(categoryId),
              let nberOfUploads = (notification?.userInfo?["nberOfUploadsToComplete"] as? Int)
        else { return }

        // Show/hide upload queue button
        if #available(iOS 26.0, *) {
            if nberOfUploads <= 0 {
                setNavBarWithoutUploadQueueButton()
            } else {
                setNavBarWithUploadQueueButton(andNberOfUploads: nberOfUploads)
            }
        }
        else {
            // Fallback on previous version
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
