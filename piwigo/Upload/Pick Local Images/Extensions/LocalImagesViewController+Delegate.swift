//
//  LocalImagesViewController+Delegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/03/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Photos
import UIKit
import piwigoKit
import uploadKit

// MARK: UICollectionViewDelegate Methods
extension LocalImagesViewController: UICollectionViewDelegate
{
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? LocalImageCollectionViewCell else {
            return
        }
        
        // Get index and upload state of image
        let index = getImageIndex(for: indexPath)
        let uploadState = getUploadStateOfImage(at: index, for: cell)

        // Update cell and selection
        if let _ = selectedImages[index] {
            // Deselect the cell
            selectedImages[index] = nil
            cell.update(selected: false, state: uploadState)
        } else {
            // Can we upload or re-upload this image?
            if (uploadState == nil) || reUploadAllowed {
                // Select the image
                selectedImages[index] = UploadProperties(localIdentifier: cell.localIdentifier,
                                                         category: categoryId)
                cell.update(selected: true, state: uploadState)
            }
        }

        // Update navigation bar
        updateNavBar()

        // Refresh cell
        cell.reloadInputViews()

        // Update state of Select button if needed
        let selectState = updateSelectButton(ofSection: indexPath.section)
        let indexPathOfHeader = IndexPath(item: 0, section: indexPath.section)
        if let header = self.localImagesCollection.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPathOfHeader) as? LocalImagesHeaderReusableView {
            header.selectButton.setTitle(forState: selectState)
        }
    }
    
    
    // MARK: - Context Menus
    @available(iOS, introduced: 13.0, obsoleted: 16.0, message: "")
    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        if let cell = collectionView.cellForItem(at: indexPath) as? LocalImageCollectionViewCell {
            // Get image identifier and corresponding upload request if it exists
            let identifier = NSString(string: "\(cell.localIdentifier)")
            let upload = (self.uploads.fetchedObjects ?? []).filter({$0.localIdentifier == cell.localIdentifier})
            
            // Get image asset and upload state
            let index = self.getImageIndex(for: indexPath)
            let imageAsset = self.fetchedImages[index]
            let uploadState = self.getUploadStateOfImage(at: index, for: cell)

            // Check if this image can be deleted
            let canDelete = (imageAsset.sourceType != .typeCloudShared) &&
                            (upload.isEmpty || [.finished, .moderated].contains(upload.first?.state))
            
            // Return preview and appropriate menu
            return UIContextMenuConfiguration(identifier: identifier,
                previewProvider: { [self] in
                    // Create preview view controller
                    return LocalImagePreviewViewController(imageAsset: imageAsset, pixelSize: view.bounds.size)
                }, actionProvider: { suggestedActions in
                    var children = [UIMenuElement]()
                    if upload.isEmpty {
                        if self.selectedImages[index] != nil {
                            // Image selected ► Propose to deselect it
                            children.append(self.deselectAction(forCell: cell, at: indexPath,
                                                                index: index, inUploadSate: uploadState))
                        } else if (uploadState == nil) || self.reUploadAllowed {
                            // Image deselected ► Propose to select it
                            children.append(self.selectAction(forCell: cell, at: indexPath,
                                                              index: index, inUploadSate: uploadState))
                        }
                        children.append(self.uploaAction(forCell: cell, at: indexPath))
                    } else {
                        children.append(self.statusAction(upload.first))
                    }
                    if self.reUploadAllowed {
                        children.append(self.uploaAction(forCell: cell, at: indexPath))
                    }
                    if canDelete {
                        children.append(self.deleteMenu(forCell: cell, at: indexPath))
                    }
                    return UIMenu(title: "", children: children)
                })
        }
        return nil
    }
    
    @available(iOS 16.0, *)
    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemsAt indexPaths: [IndexPath],
                        point: CGPoint) -> UIContextMenuConfiguration? {
        if indexPaths.count == 1, let indexPath = indexPaths.first,
           let cell = collectionView.cellForItem(at: indexPath) as? LocalImageCollectionViewCell {
            // Get image identifier and corresponding upload request if it exists
            let identifier = NSString(string: "\(cell.localIdentifier)")
            let upload = (self.uploads.fetchedObjects ?? []).filter({$0.localIdentifier == cell.localIdentifier})
            
            // Get image asset and upload state
            let index = self.getImageIndex(for: indexPath)
            let imageAsset = self.fetchedImages[index]
            let uploadState = self.getUploadStateOfImage(at: index, for: cell)

            // Check if this image can be deleted
            let canDelete = (imageAsset.sourceType != .typeCloudShared) &&
                            (upload.isEmpty || [.finished, .moderated].contains(upload.first?.state))
            
            // Return preview and appropriate menu
            return UIContextMenuConfiguration(identifier: identifier,
                previewProvider: { [self] in
                    // Create preview view controller
                    let scale = self.view.traitCollection.displayScale
                    let maxPixelSize = CGSize(width: view.bounds.width * scale, height: view.bounds.height * scale)
                    return LocalImagePreviewViewController(imageAsset: imageAsset, pixelSize: maxPixelSize)
                }, actionProvider: { suggestedActions in
                    var children = [UIMenuElement]()
                    if upload.isEmpty {
                        if self.selectedImages[index] != nil {
                            // Image selected ► Propose to deselect it
                            children.append(self.deselectAction(forCell: cell, at: indexPath,
                                                                index: index, inUploadSate: uploadState))
                        } else if (uploadState == nil) || self.reUploadAllowed {
                            // Image deselected ► Propose to select it
                            children.append(self.selectAction(forCell: cell, at: indexPath,
                                                              index: index, inUploadSate: uploadState))
                        }
                        children.append(self.uploaAction(forCell: cell, at: indexPath))
                    } else {
                        children.append(self.statusAction(upload.first))
                    }
                    if self.reUploadAllowed {
                        children.append(self.uploaAction(forCell: cell, at: indexPath))
                    }
                    if canDelete {
                        children.append(self.deleteMenu(forCell: cell, at: indexPath))
                    }
                    return UIMenu(title: "", children: children)
                })
        }
        return nil
    }
    
    private func statusAction(_ upload: Upload?) -> UIAction {
        // Check if an upload request exists (should never happen)
        guard let upload = upload else {
            return UIAction(title: String(localized: "errorHUD_label", bundle: piwigoKit, comment: "Error"),
                            image: UIImage(systemName: "exclamationmark.triangle"), handler: { _ in })
        }
        
        // Show upload status
        switch upload.state {
        case .waiting, .preparing, .prepared, .uploading, .uploaded, .finishing:
            return UIAction(title: upload.stateLabel,
                            image: UIImage(systemName: "timer"), handler: { _ in })
        case .preparingError, .preparingFail, .formatError,
             .uploadingError, .uploadingFail, .finishingError, .finishingFail:
            return UIAction(title: upload.stateLabel,
                            image: UIImage(systemName: "exclamationmark.triangle"), handler: { _ in })
        case .finished, .moderated:
            return UIAction(title: NSLocalizedString("imageUploadCompleted_title", comment: "Upload Completed"),
                            image: UIImage(systemName: "checkmark"), handler: { _ in })
        }
    }
    
    private func selectAction(forCell cell: LocalImageCollectionViewCell, at indexPath: IndexPath,
                              index: Int, inUploadSate uploadState: pwgUploadState?) -> UIAction
    {
        // Image not selected and selectable ► Propose to select it
        return UIAction(title: NSLocalizedString("categoryImageList_selectButton", comment: "Select"),
                        image: UIImage(systemName: "checkmark.circle")) { _ in
            // Select the cell
            self.selectedImages[index] = UploadProperties(localIdentifier: cell.localIdentifier,
                                                          category: self.categoryId)
            cell.update(selected: true, state: uploadState)
            
            // Update number of selected cells
            self.updateNavBar()
            
            // Update state of Select button if needed
            let selectState = self.updateSelectButton(ofSection: indexPath.section)
            let indexPath = IndexPath(item: 0, section: indexPath.section)
            if let header = self.localImagesCollection.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPath) as? LocalImagesHeaderReusableView {
                header.selectButton.setTitle(forState: selectState)
            }
        }
    }
    
    private func deselectAction(forCell cell: LocalImageCollectionViewCell, at indexPath: IndexPath,
                                index: Int, inUploadSate uploadState: pwgUploadState?) -> UIAction
    {
        var image: UIImage?
        if #available(iOS 16, *) {
            image = UIImage(systemName: "checkmark.circle.badge.xmark")
        } else {
            image = UIImage(systemName: "checkmark.circle")
        }
        return UIAction(title: NSLocalizedString("categoryImageList_deselectButton", comment: "Deselect"),
                        image: image) { _ in
            // Deselect the cell
            self.selectedImages[index] = nil
            cell.update(selected: false, state: uploadState)
            
            // Update number of selected cells
            self.updateNavBar()
            
            // Update state of Select button if needed
            let selectState = self.updateSelectButton(ofSection: indexPath.section)
            let indexPath = IndexPath(item: 0, section: indexPath.section)
            if let header = self.localImagesCollection.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPath) as? LocalImagesHeaderReusableView {
                header.selectButton.setTitle(forState: selectState)
            }
        }
    }

    private func uploaAction(forCell cell: LocalImageCollectionViewCell, at indexPath: IndexPath) -> UIAction {
        let imageUpload: UIImage?
        if #available(iOS 17.0, *) {
            let imageConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            imageUpload = UIImage(systemName: "photo.badge.plus", withConfiguration: imageConfig)
        } else {
            imageUpload = UIImage(named: "photo.badge.plus")
        }
        return UIAction(title: NSLocalizedString("tabBar_upload", comment: "Upload"),
                        image: imageUpload) { action in
            // Check that an upload request does not exist for that image (should never happen)
            if (self.uploads.fetchedObjects ?? [])
                .filter({$0.localIdentifier == cell.localIdentifier}).first != nil {
                return
            }
            
            // Create an upload request for that image and add it to the upload queue
            let upload = UploadProperties(localIdentifier: cell.localIdentifier, category: self.categoryId)
            self.uploadRequests.append(upload)

            // Disable buttons
            self.cancelBarButton?.isEnabled = false
            self.uploadBarButton?.isEnabled = false
            self.actionBarButton?.isEnabled = false
            self.trashBarButton?.isEnabled = false
            
            // Show upload parameter views
            let uploadSwitchSB = UIStoryboard(name: "UploadSwitchViewController", bundle: nil)
            guard let uploadSwitchVC = uploadSwitchSB.instantiateViewController(withIdentifier: "UploadSwitchViewController") as? UploadSwitchViewController
            else { preconditionFailure("Could not load UploadSwitchViewController") }
            
            uploadSwitchVC.delegate = self
            uploadSwitchVC.user = self.user
            uploadSwitchVC.categoryId = self.categoryId
            uploadSwitchVC.categoryCurrentCounter = self.categoryCurrentCounter

            // Will we propose to delete images after upload?
            if let imageAsset = PHAsset.fetchAssets(withLocalIdentifiers: [cell.localIdentifier],
                                                    options: nil).firstObject {
                // Only local images can be deleted
                if imageAsset.sourceType != .typeCloudShared {
                    // Will allow user to delete images after upload
                    uploadSwitchVC.canDeleteImages = true
                }
            }
            
            // Push Edit view embedded in navigation controller
            let navController = UINavigationController(rootViewController: uploadSwitchVC)
            navController.modalPresentationStyle = .popover
            navController.modalTransitionStyle = .coverVertical
            navController.popoverPresentationController?.sourceView = self.localImagesCollection
            navController.popoverPresentationController?.barButtonItem = self.uploadBarButton
            navController.popoverPresentationController?.permittedArrowDirections = .up
            self.navigationController?.present(navController, animated: true)
        }
    }

    private func deleteMenu(forCell cell: LocalImageCollectionViewCell, at indexPath: IndexPath) -> UIMenu {
        let delete = deleteAction(forCell: cell, at: indexPath)
        let menuId = UIMenu.Identifier("org.piwigo.removeFromCameraRoll")
        return UIMenu(identifier: menuId, options: UIMenu.Options.displayInline, children: [delete])
    }
    
    private func deleteAction(forCell cell: LocalImageCollectionViewCell, at indexPath: IndexPath) -> UIAction {
        return UIAction(title: NSLocalizedString("localImages_deleteTitle", comment: "Remove from Camera Roll"),
                        image: UIImage(systemName: "trash"), attributes: .destructive) { action in
            // Get asset to delete
            let index = self.getImageIndex(for: indexPath)
            let imageAsset = self.fetchedImages[index]
            let uploadID = (self.uploads.fetchedObjects ?? []).filter({$0.localIdentifier == cell.localIdentifier}).first?.objectID
            if let uploadID {
                Task { @UploadManagerActor in
                    UploadManager.shared.willDeleteAsssets(associatedToUploads: [uploadID])
                }
            }
            Task { @MainActor in
                do {
                    // Delete image from Photo Library
                    try await PHPhotoLibrary.shared().performChanges {
                        PHAssetChangeRequest.deleteAssets([imageAsset] as (any NSFastEnumeration))
                    }
                    
                    // Delete associated upload request if any
                    if let uploadID {
                        Task { @UploadManagerActor in
                            UploadManager.shared.deleteUploads([uploadID])
                        }
                    }
                }
                catch {
                    if let uploadID {
                        Task { @UploadManagerActor in
                            UploadManager.shared.disableDeleteAfterUpload([uploadID])
                        }
                    }
                }
            }
        }
    }
}
