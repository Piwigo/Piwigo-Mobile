//
//  ImageViewController+Edit.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

extension ImageViewController
{
    // MARK: - Edit Image
    @objc func editImage() {
        // Disable buttons during action
        setEnableStateOfButtons(false)

        // Present EditImageDetails view
        let editImageSB = UIStoryboard(name: "EditImageParamsViewController", bundle: nil)
        guard let editImageVC = editImageSB.instantiateViewController(withIdentifier: "EditImageParamsViewController") as? EditImageParamsViewController else { return }
        editImageVC.images = [imageData]
        editImageVC.hasTagCreationRights = userHasUploadRights
        editImageVC.delegate = self
        pushView(editImageVC, forButton: actionBarButton)
    }
}


// MARK: - EditImageParamsDelegate Methods
extension ImageViewController: EditImageParamsDelegate
{
    func didDeselectImage(withId imageId: Int64) {
        // Should never be called when the properties of a single image are edited
    }

    func didChangeImageParameters(_ params: PiwigoImageData) {
        // Determine index of updated image
        guard let indexOfUpdatedImage = images.firstIndex(where: { $0.imageId == params.imageId }) else { return }
        
        // Update list and currently viewed image
        imageData = params
        images[indexOfUpdatedImage] = params

        // Update title view
        setTitleViewFromImageData()
        
        // Update image metadata
        if let pVC = pageViewController,
           let imagePVC = pVC.viewControllers?.first as? ImagePreviewViewController {
            imagePVC.updateImageMetadata(with: imageData)
        }

        // Update cached image data
        /// Note: the current category might be a smart album.
        let mergedCatIds = Array(Set(imageData.categoryIds.map({$0.intValue}) + [Int(categoryId)]))
        for catId in mergedCatIds {
            CategoriesData.sharedInstance().getCategoryById(catId)?.updateImage(afterEdit: params)
        }
        
        // If the current category presents tagged images and the user
        // removed the associated tag, delete the image from the smart album.
        if categoryId == kPiwigoTagsCategoryId,
           let albumData = CategoriesData.sharedInstance().getCategoryById(kPiwigoTagsCategoryId),
           let tagId = Int(albumData.query), !params.tags.contains(where: { $0.tagId == tagId}) {
            // Delete this image from the category and the parent collection
            CategoriesData.sharedInstance().removeImage(params, fromCategory: String(kPiwigoTagsCategoryId))
            // … and delete it from this data source
            didRemoveImage(withId: params.imageId)
            return
        }

        // Update banner of item in collection view (in case of empty title)
        if imgDetailDelegate?.responds(to: #selector(ImageDetailDelegate.didUpdateImage(withData:))) ?? false {
            imgDetailDelegate?.didUpdateImage(withData: imageData)
        }
    }

    func didFinishEditingParameters() {
        // Enable buttons after action
        setEnableStateOfButtons(true)

        // Reload tab bar
        updateNavBar()
    }
}
