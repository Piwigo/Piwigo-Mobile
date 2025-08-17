//
//  LocalImagesViewController+Bar.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 17 August 2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import Photos
import UIKit

// MARK: Navigation Bar & Buttons
extension LocalImagesViewController {
    
    @MainActor
    func updateNavBar() {
        let nberOfSelectedImages = selectedImages.compactMap{ $0 }.count
        switch nberOfSelectedImages {
        case 0:
            // Buttons
            cancelBarButton.isEnabled = false
            actionBarButton.isEnabled = (queue.operationCount == 0)
            uploadBarButton.isEnabled = false
            
            // Display "Back" button on the left side
            navigationItem.leftBarButtonItems = []
            
            // Set buttons on the right side on iPhone
            if UIDevice.current.userInterfaceIdiom == .phone {
                // Presents a single action menu
                updateActionButton()
                navigationItem.rightBarButtonItems = [actionBarButton].compactMap { $0 }
                
                // Present the "Upload" button in the toolbar
                legendLabel.text = NSLocalizedString("selectImages", comment: "Select Photos")
                legendBarItem = UIBarButtonItem(customView: legendLabel)
                toolbarItems = [legendBarItem, .flexibleSpace(), uploadBarButton]
            }
            
        default:
            // Buttons
            cancelBarButton.isEnabled = true
            actionBarButton.isEnabled = (queue.operationCount == 0)
            uploadBarButton.isEnabled = true
            
            // Display "Cancel" button on the left side
            navigationItem.leftBarButtonItems = [cancelBarButton].compactMap { $0 }
            
            // Set buttons on the right side on iPhone
            if UIDevice.current.userInterfaceIdiom == .phone {
                // Update the number of selected photos in the toolbar
                legendLabel.text = nberOfSelectedImages == 1 ? NSLocalizedString("selectImageSelected", comment: "1 Photo Selected") : String(format:NSLocalizedString("selectImagesSelected", comment: "%@ Photos Selected"), NSNumber(value: nberOfSelectedImages))
                legendBarItem = UIBarButtonItem(customView: legendLabel)
                toolbarItems = [legendBarItem, .flexibleSpace(), uploadBarButton]
                
                // Presents a single action menu
                updateActionButton()
                navigationItem.rightBarButtonItems = [actionBarButton].compactMap { $0 }
            }
        }
        
        // Set buttons on the right side on iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            // Update the number of selected photos in the navigation bar
            title = nberOfSelectedImages == 1 ? NSLocalizedString("selectImageSelected", comment: "1 Photo Selected") : String(format:NSLocalizedString("selectImagesSelected", comment: "%@ Photos Selected"), NSNumber(value: nberOfSelectedImages))
            
            if canDeleteUploadedImages() || canDeleteSelectedImages() {
                trashBarButton.isEnabled = true
                navigationItem.rightBarButtonItems = [uploadBarButton,
                                                      actionBarButton,
                                                      trashBarButton].compactMap { $0 }
            } else {
                trashBarButton.isEnabled = false
                navigationItem.rightBarButtonItems = [uploadBarButton,
                                                      actionBarButton].compactMap { $0 }
            }
        }
    }
    
    @MainActor
    func updateActionButton() {
        // Update action button
        // The action button proposes:
        /// - to swap between ascending and descending sort orders,
        /// - to choose one of the 4 sort options
        /// - to select new photos in the Photo Library if the user did not grant full access to the Photo Library,
        /// - to allow/disallow re-uploading photos,
        /// - to delete photos already uploaded to the Piwigo server on iPhone only.
        var children: [UIMenuElement?] = [swapOrderAction(), groupMenu(),
                                          selectPhotosMenu(), reUploadAction()]
        if UIDevice.current.userInterfaceIdiom == .phone {
            children.append(deleteMenu())
        }
        let updatedMenu = actionBarButton?.menu?.replacingChildren(children.compactMap({$0}))
        actionBarButton?.menu = updatedMenu
    }
    
    func canDeleteUploadedImages() -> Bool {
        // Don't provide access to the Trash button until the preparation work is not done
        if queue.operationCount > 0 { return false }
        
        // Check if there are uploaded photos to delete
        let indexedUploads = self.indexedUploadsInQueue.compactMap({$0})
        let completed = (uploads.fetchedObjects ?? []).filter({[.finished, .moderated].contains($0.state)})
        for index in 0..<indexedUploads.count {
            if let _ = completed.first(where: {$0.localIdentifier == indexedUploads[index].0}),
               indexedUploads[index].2 {
                return true
            }
        }
        return false
    }
    
    func canDeleteSelectedImages() -> Bool {
        var hasImagesToDelete = false
        let imageIDs = selectedImages.compactMap({ $0?.localIdentifier })
        PHAsset.fetchAssets(withLocalIdentifiers: imageIDs, options: nil)
            .enumerateObjects(options: .concurrent) { asset, _ , stop in
                if asset.canPerform(.delete) {
                    hasImagesToDelete = true
                    stop.pointee = true
                }
            }
        return hasImagesToDelete
    }
    
    
    // MARK: - Show Upload Options
    @objc func didTapUploadButton() {
        // Avoid potential crash (should never happen, but…)
        uploadRequests = selectedImages.compactMap({ $0 })
        if uploadRequests.isEmpty { return }
        
        // Disable buttons
        cancelBarButton?.isEnabled = false
        uploadBarButton?.isEnabled = false
        actionBarButton?.isEnabled = false
        trashBarButton?.isEnabled = false
        
        // Show upload parameter views
        let uploadSwitchSB = UIStoryboard(name: "UploadSwitchViewController", bundle: nil)
        guard let uploadSwitchVC = uploadSwitchSB.instantiateViewController(withIdentifier: "UploadSwitchViewController") as? UploadSwitchViewController
        else { preconditionFailure("could not load UploadSwitchViewController") }
        
        uploadSwitchVC.delegate = self
        uploadSwitchVC.user = user
        uploadSwitchVC.categoryId = categoryId
        uploadSwitchVC.categoryCurrentCounter = categoryCurrentCounter

        // Will we propose to delete images after upload?
        if let firstLocalID = uploadRequests.first?.localIdentifier {
            if let imageAsset = PHAsset.fetchAssets(withLocalIdentifiers: [firstLocalID], options: nil).firstObject {
                // Only local images can be deleted
                if imageAsset.sourceType != .typeCloudShared {
                    // Will allow user to delete images after upload
                    uploadSwitchVC.canDeleteImages = true
                }
            }
        }
        
        // Push Edit view embedded in navigation controller
        let navController = UINavigationController(rootViewController: uploadSwitchVC)
        navController.modalPresentationStyle = .popover
        navController.modalTransitionStyle = .coverVertical
        navController.popoverPresentationController?.sourceView = localImagesCollection
        navController.popoverPresentationController?.barButtonItem = uploadBarButton
        navController.popoverPresentationController?.permittedArrowDirections = .up
        navigationController?.present(navController, animated: true)
    }
}
