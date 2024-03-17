//
//  LocalImagesViewController+UICollectionViewDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/03/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Photos
import piwigoKit
import uploadKit

extension LocalImagesViewController: UICollectionViewDelegate
{
    // MARK: - Headers & Footers
    func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        if (elementKind == UICollectionView.elementKindSectionHeader) || (elementKind == UICollectionView.elementKindSectionFooter) {
            view.layer.zPosition = 0 // Below scroll indicator
        }
    }

    
    // MARK: - Sections
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 10, left: AlbumUtilities.kImageMarginsSpacing,
                            bottom: 10, right: AlbumUtilities.kImageMarginsSpacing)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return CGFloat(AlbumUtilities.imageCellVerticalSpacing(forCollectionType: .popup))
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return CGFloat(AlbumUtilities.imageCellHorizontalSpacing(forCollectionType: .popup))
    }
    
    
    // MARK: - Items i.e. Images
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Calculate the optimum image size
        let size = CGFloat(AlbumUtilities.imageSize(forView: collectionView, imagesPerRowInPortrait: AlbumVars.shared.thumbnailsPerRowInPortrait, collectionType: .popup))

        return CGSize(width: size, height: size)
    }

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
            header.setButtonTitle(forState: selectState)
        }
    }
    
    @available(iOS 13.0, *)
    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        if let cell = collectionView.cellForItem(at: indexPath) as? LocalImageCollectionViewCell {
            // Get image identifier and corresponding upload request if it exists
            let identifier = NSString(string: "\(cell.localIdentifier)")
            let upload = (self.uploads.fetchedObjects ?? []).filter({$0.localIdentifier == cell.localIdentifier})
            
            // Get image asset
            let index = self.getImageIndex(for: indexPath)
            let imageAsset = self.fetchedImages[index]

            // Check if this image can be deleted
            let canDelete = (imageAsset.sourceType != .typeCloudShared) &&
                            (upload.isEmpty || [.finished, .moderated].contains(upload.first?.state))
            
            // Return nil or a
            return UIContextMenuConfiguration(identifier: identifier,
                previewProvider: { [self] in
                    // Create preview view controller
                    let scale = view.window?.screen.scale ?? 1.0
                    let maxPixelSize = CGSize(width: view.bounds.width * scale, height: view.bounds.height * scale)
                    return LocalImagePreviewViewController(imageAsset: imageAsset, pixelSize: maxPixelSize)
                }, actionProvider: { suggestedActions in
                    var children = [UIMenuElement]()
                    if upload.isEmpty {
                        children.append(self.uploaAction(indexPath))
                    } else {
                        children.append(self.statusAction(upload.first))
                    }
                    if canDelete { children.append(self.deleteAction(indexPath)) }
                    return UIMenu(title: "", children: children)
                })
        }
        else {
            return nil
        }
    }
    
    
    // MARK: - Context Menu Actions
    @available(iOS 13.0, *)
    func statusAction(_ upload: Upload?) -> UIAction {
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
    func uploaAction(_ indexPath: IndexPath) -> UIAction {
        return UIAction(title: NSLocalizedString("imageUploadDetailsButton_title", comment: "Upload"),
                        image: UIImage(contentsOfFile: "piwigo")) { action in
            if let cell = self.localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell {
                // Check that an upload request does not exist for that image
                if (self.uploads.fetchedObjects ?? [])
                    .filter({$0.localIdentifier == cell.localIdentifier}).first != nil {
                    return
                }
                
                // Create an upload request for that image and update the corresponding cell
                let upload = UploadProperties(localIdentifier: cell.localIdentifier, category: self.categoryId)
                cell.update(selected: true, state: .waiting)
                
                // Append the upload to the queue
                UploadManager.shared.backgroundQueue.async {
                    self.uploadProvider.importUploads(from: [upload]) { error in
                        guard let error = error else {
                            // Restart UploadManager activities
                            UploadManager.shared.backgroundQueue.async {
                                UploadManager.shared.isPaused = false
                                UploadManager.shared.findNextImageToUpload()
                            }
                            return
                        }
                        DispatchQueue.main.async {
                            self.dismissPiwigoError(withTitle: NSLocalizedString("CoreDataFetch_UploadCreateFailed", comment: "Failed to create a new Upload object."), message: error.localizedDescription) {
                                // Restart UploadManager activities
                                UploadManager.shared.backgroundQueue.async {
                                    UploadManager.shared.updateNberOfUploadsToComplete()
                                    UploadManager.shared.isPaused = false
                                    UploadManager.shared.findNextImageToUpload()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @available(iOS 13.0, *)
    func deleteAction(_ indexPath: IndexPath) -> UIAction {
        return UIAction(title: NSLocalizedString("localImages_deleteTitle", comment: "Remove from Camera Roll"),
                        image: UIImage(systemName: "trash"),
                        attributes: .destructive) { action in
            if let cell = self.localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell {
                // Get image identifier and check if this image has been uploaded
                if let upload = (self.uploads.fetchedObjects ?? []).filter({$0.localIdentifier == cell.localIdentifier}).first {
                    // Delete uploaded image
                    UploadManager.shared.deleteAssets(associatedToUploads: [upload])
                } else {
                    // Delete images from Photo Library
                    let index = self.getImageIndex(for: indexPath)
                    let imageAsset = self.fetchedImages[index]
                    PHPhotoLibrary.shared().performChanges {
                        // Delete images from the library
                        PHAssetChangeRequest.deleteAssets([imageAsset] as NSFastEnumeration)
                    }
                }
            }
        }
    }
}
