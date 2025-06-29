//
//  PasteboardImagesViewController+Delegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/03/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

// MARK: UICollectionViewDelegate Methods
extension PasteboardImagesViewController: UICollectionViewDelegate
{
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? LocalImageCollectionViewCell else {
            return
        }

        // Get upload state of image
        let uploadState = getUploadStateOfImage(at: indexPath.item, for: cell)

        // Update cell and selection
        if let _ = selectedImages[indexPath.item] {
            // Deselect the cell
            selectedImages[indexPath.item] = nil
            cell.update(selected: false, state: uploadState)
        } else {
            // Can we upload or re-upload this image?
            if (uploadState == nil) || reUploadAllowed {
                // Select the image
                selectedImages[indexPath.item] = UploadProperties(localIdentifier: cell.localIdentifier,
                                                                  category: categoryId)
                cell.update(selected: true, state: uploadState)
            }
        }

        // Update navigation bar
        updateNavBar()

        // Refresh cell
        cell.reloadInputViews()

        // Update state of Select button if needed
        updateSelectButton()
        if let header = self.localImagesCollection.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: 0)) as? PasteboardImagesHeaderReusableView {
            header.selectButton.setTitle(forState: sectionState)
        }
    }
    
    
    // MARK: - Context Menus
    @available(iOS, introduced: 13.0, deprecated: 16.0, message: "")
    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        if let cell = collectionView.cellForItem(at: indexPath) as? LocalImageCollectionViewCell {
            // Get image identifier and corresponding upload request if it exists
            let identifier = NSString(string: "\(cell.localIdentifier)")
            let upload = (self.uploads.fetchedObjects ?? []).filter({$0.md5Sum == cell.md5sum})
            
            // Get upload state
            let uploadState = self.getUploadStateOfImage(at: indexPath.item, for: cell)
            
            // Return preview and appropriate menu
            return UIContextMenuConfiguration(identifier: identifier,
                previewProvider: { [self] in
                    // Create preview view controller
                    let (image, _) = self.getImageAndMd5sumOfPbObject(atIndex: indexPath.item)
                    return LocalImagePreviewViewController(image: image)
                }, actionProvider: { suggestedActions in
                    var children = [UIMenuElement]()
                    if upload.isEmpty {
                        if self.selectedImages[indexPath.item] != nil {
                            // Image selected ► Propose to deselect it
                            children.append(self.deselectAction(forCell: cell, at: indexPath,
                                                                inUploadSate: uploadState))
                        } else if (uploadState == nil) || self.reUploadAllowed {
                            // Image deselected ► Propose to select it
                            children.append(self.selectAction(forCell: cell, at: indexPath,
                                                              inUploadSate: uploadState))
                        }
                        children.append(self.uploaAction(forCell: cell, at: indexPath))
                    } else {
                        children.append(self.statusAction(upload.first))
                        if self.reUploadAllowed {
                            children.append(self.uploaAction(forCell: cell, at: indexPath))
                        }
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
            let upload = (self.uploads.fetchedObjects ?? []).filter({$0.md5Sum == cell.md5sum})
            
            // Get upload state
            let uploadState = self.getUploadStateOfImage(at: indexPath.item, for: cell)
            
            // Return preview and appropriate menu
            return UIContextMenuConfiguration(identifier: identifier,
                previewProvider: { [self] in
                    // Create preview view controller
                    let (image, _) = self.getImageAndMd5sumOfPbObject(atIndex: indexPath.item)
                    return LocalImagePreviewViewController(image: image)
                }, actionProvider: { suggestedActions in
                    var children = [UIMenuElement]()
                    if upload.isEmpty {
                        if self.selectedImages[indexPath.item] != nil {
                            // Image selected ► Propose to deselect it
                            children.append(self.deselectAction(forCell: cell, at: indexPath,
                                                                inUploadSate: uploadState))
                        } else if (uploadState == nil) || self.reUploadAllowed {
                            // Image deselected ► Propose to select it
                            children.append(self.selectAction(forCell: cell, at: indexPath,
                                                              inUploadSate: uploadState))
                        }
                        children.append(self.uploaAction(forCell: cell, at: indexPath))
                    } else {
                        children.append(self.statusAction(upload.first))
                        if self.reUploadAllowed {
                            children.append(self.uploaAction(forCell: cell, at: indexPath))
                        }
                    }
                    return UIMenu(title: "", children: children)
                })
        }
        return nil
    }

    @available(iOS 13.0, *)
    private func statusAction(_ upload: Upload?) -> UIAction {
        // Check if an upload request exists (should never happen)
        guard let upload = upload else {
            return UIAction(title: NSLocalizedString("errorHUD_label", comment: "Error"),
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
    
    @available(iOS 13.0, *)
    private func selectAction(forCell cell: LocalImageCollectionViewCell, at indexPath: IndexPath,
                              inUploadSate uploadState: pwgUploadState?) -> UIAction
    {
        // Image not selected and selectable ► Propose to select it
        return UIAction(title: NSLocalizedString("categoryImageList_selectButton", comment: "Select"),
                        image: UIImage(systemName: "checkmark.circle")) { _ in
            // Select the cell
            self.selectedImages[indexPath.item] = UploadProperties(localIdentifier: cell.localIdentifier,
                                                                   category: self.categoryId)
            cell.update(selected: true, state: uploadState)
            
            // Update number of selected cells
            self.updateNavBar()
            
            // Update state of Select button if needed
            self.updateSelectButton()
            let indexPath = IndexPath(item: 0, section: indexPath.section)
            if let header = self.localImagesCollection.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPath) as? PasteboardImagesHeaderReusableView {
                header.configure(with: self.sectionState)
            }
        }
    }
    
    @available(iOS 13.0, *)
    private func deselectAction(forCell cell: LocalImageCollectionViewCell, at indexPath: IndexPath,
                                inUploadSate uploadState: pwgUploadState?) -> UIAction
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
            self.selectedImages[indexPath.item] = nil
            cell.update(selected: false, state: uploadState)
            
            // Update number of selected cells
            self.updateNavBar()
            
            // Update state of Select button if needed
            self.updateSelectButton()
            let indexPath = IndexPath(item: 0, section: indexPath.section)
            if let header = self.localImagesCollection.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPath) as? PasteboardImagesHeaderReusableView {
                header.configure(with: self.sectionState)
            }
        }
    }

    @available(iOS 13.0, *)
    private func uploaAction(forCell cell: LocalImageCollectionViewCell, at indexPath: IndexPath) -> UIAction {
        return UIAction(title: NSLocalizedString("tabBar_upload", comment: "Upload"),
                        image: UIImage(named: "imageUpload")) { action in
            // Check that an upload request does not exist for that image (should never happen)
            if (self.uploads.fetchedObjects ?? []).filter({$0.md5Sum == cell.md5sum}).first != nil {
                return
            }
            
            // Create an upload request for that image and add it to the upload queue
            let upload = UploadProperties(localIdentifier: cell.localIdentifier, category: self.categoryId)
            self.uploadRequests.append(upload)

            // Disable buttons
            self.cancelBarButton?.isEnabled = false
            self.uploadBarButton?.isEnabled = false
            self.actionBarButton?.isEnabled = false
            
            // Show upload parameter views
            let uploadSwitchSB = UIStoryboard(name: "UploadSwitchViewController", bundle: nil)
            guard let uploadSwitchVC = uploadSwitchSB.instantiateViewController(withIdentifier: "UploadSwitchViewController") as? UploadSwitchViewController
            else { preconditionFailure("Could not load UploadSwitchViewController") }
            
            uploadSwitchVC.delegate = self
            uploadSwitchVC.user = self.user
            uploadSwitchVC.categoryId = self.categoryId
            uploadSwitchVC.categoryCurrentCounter = self.categoryCurrentCounter
            uploadSwitchVC.canDeleteImages = false
            
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
}
