//
//  AlbumViewController+Edit.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

// MARK: Edit Images Parameters
extension AlbumViewController
{
    @objc func editSelection() {
        initSelection(beforeAction: .edit)
    }

    func editImages() {
        if selectedImageData.isEmpty {
            // No image => End (should never happened)
            updatePiwigoHUDwithSuccess() { [self] in
                hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { [self] in
                    cancelSelect()
                }
            }
            return
        }
        
        // Present EditImageParams view
        let editImageSB = UIStoryboard(name: "EditImageParamsViewController", bundle: nil)
        guard let editImageVC = editImageSB.instantiateViewController(withIdentifier: "EditImageParamsViewController") as? EditImageParamsViewController else {
            fatalError("No EditImageParamsViewController!")
        }
        editImageVC.images = selectedImageData
//        let albumData = CategoriesData.sharedInstance().getCategoryById(categoryId)
        editImageVC.hasTagCreationRights = userHasUploadRights
        editImageVC.delegate = self
        pushView(editImageVC)
    }
}


// MARK: - EditImageParamsDelegate Methods
@objc
extension AlbumViewController: EditImageParamsDelegate
{
    @objc func didDeselectImage(withId imageId: Int64) {
        // Deselect image
        selectedImageIds.removeAll { $0 == imageId }
        imagesCollection?.reloadSections(IndexSet(integer: 1))
    }

    @objc func didChangeImageParameters(_ params: PiwigoImageData) {
        // Update cached image data
        /// Note: the current category cannot be a smart album.
        if let categoryIds = params.categoryIds {
            for catId in categoryIds {
                CategoriesData.sharedInstance().getCategoryById(catId.intValue).updateImage(afterEdit: params)
            }
        }

        // Update data source
//        let indexOfUpdatedImage = albumData?.updateImage(params) ?? NSNotFound
//        if indexOfUpdatedImage == NSNotFound { return }

        // Refresh image cell
//        let indexPath = IndexPath(item: indexOfUpdatedImage, section: 1)
//        if imagesCollection?.indexPathsForVisibleItems.contains(indexPath) ?? false {
//            imagesCollection?.reloadItems(at: [indexPath])
//        }
    }

    @objc func didFinishEditingParameters() {
        cancelSelect()
    }
}
