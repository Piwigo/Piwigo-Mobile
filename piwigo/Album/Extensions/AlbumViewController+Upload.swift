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
        if #available(iOS 14, *) {
            PhotosFetch.shared.checkPhotoLibraryAuthorizationStatus(for: PHAccessLevel.readWrite, for: self, onAccess: { [self] in
                // Open local albums view controller in new navigation controller
                self.presentLocalAlbums()
            }, onDeniedAccess: { })
        } else {
            // Fallback on earlier versions
            PhotosFetch.shared.checkPhotoLibraryAccessForViewController(self, onAuthorizedAccess: { [self] in
                // Open local albums view controller in new navigation controller
                self.presentLocalAlbums()
            }, onDeniedAccess: { })
        }

        // Hide CreateAlbum and UploadImages buttons
        didCancelTapAddButton()
    }
    
    private func presentLocalAlbums() {
        // Open local albums view controller in new navigation controller
        let localAlbumsSB = UIStoryboard(name: "LocalAlbumsViewController", bundle: nil)
        guard let localAlbumsVC = localAlbumsSB.instantiateViewController(withIdentifier: "LocalAlbumsViewController") as? LocalAlbumsViewController
        else { preconditionFailure("Cloud not load LocalAlbumsViewController") }
        localAlbumsVC.categoryId = categoryId
        localAlbumsVC.user = user
        let navController = UINavigationController(rootViewController: localAlbumsVC)
        navController.modalTransitionStyle = .coverVertical
        navController.modalPresentationStyle = .pageSheet
        present(navController, animated: true)
    }

    @objc func didTapUploadQueueButton() {
        // Open upload queue controller in new navigation controller
        var navController: UINavigationController? = nil
        if #available(iOS 13.0, *) {
            let uploadQueueSB = UIStoryboard(name: "UploadQueueViewController", bundle: nil)
            guard let uploadQueueVC = uploadQueueSB.instantiateViewController(withIdentifier: "UploadQueueViewController") as? UploadQueueViewController
            else { preconditionFailure("Could not load UploadQueueViewController") }
            navController = UINavigationController(rootViewController: uploadQueueVC)
        }
        else {
            // Fallback on earlier versions
            let uploadQueueSB = UIStoryboard(name: "UploadQueueViewControllerOld", bundle: nil)
            guard let uploadQueueVC = uploadQueueSB.instantiateViewController(withIdentifier: "UploadQueueViewControllerOld") as? UploadQueueViewControllerOld
            else { preconditionFailure("Cloud not load UploadQueueViewControllerOld") }
            navController = UINavigationController(rootViewController: uploadQueueVC)
        }
        navController?.modalTransitionStyle = .coverVertical
        navController?.modalPresentationStyle = .formSheet
        if let navController = navController {
            present(navController, animated: true)
        }
    }
}
