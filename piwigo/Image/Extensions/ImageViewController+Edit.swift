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
        guard let imageData = imageData else { return }
        // Disable buttons during action
        setEnableStateOfButtons(false)

        // Present EditImageDetails view
        let editImageSB = UIStoryboard(name: "EditImageParamsViewController", bundle: nil)
        guard let editImageVC = editImageSB.instantiateViewController(withIdentifier: "EditImageParamsViewController") as? EditImageParamsViewController else { return }
        editImageVC.user = user
        editImageVC.images = [imageData]
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

    func didChangeImageParameters(_ params: Image) {
        // Update title view
        setTitleViewFromImageData()
        
        // Update image metadata
        if let imagePVC = pageViewController?.viewControllers?.first {
            (imagePVC as? ImageDetailViewController)?.updateImageMetadata(with: params)
            (imagePVC as? VideoDetailViewController)?.updateImageMetadata(with: params)
        }
    }

    func didFinishEditingParameters() {
        // Enable buttons after action
        setEnableStateOfButtons(true)

        // Reload tab bar
        updateNavBar()
    }
}
