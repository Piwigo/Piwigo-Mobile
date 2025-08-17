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

extension AlbumViewController
{
    // MARK: - Upload Actions
    @objc func didTapUploadImagesButton() {
        // Check autorisation to access Photo Library before uploading
        checkPhotoLibraryAccess()

        // Hide CreateAlbum and UploadImages buttons
        didCancelTapAddButton()
    }
    
    func checkPhotoLibraryAccess() {
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


extension AlbumViewController: AlbumViewControllerDelegate {
    func didSelectCurrentCounter(value: Int64) {
        albumData.currentCounter = value
        mainContext.saveIfNeeded()
    }
}
