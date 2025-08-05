//
//  ImageViewController+Edit.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

// MARK: - Edit Image Propertites Action
@available(iOS 14, *)
extension ImageViewController
{
    func editParamsAction() -> UIAction {
        // Edit image parameters
        let action = UIAction(title: NSLocalizedString("imageOptions_properties",
                                                       comment: "Modify Information"),
                              image: UIImage(systemName: "pencil"),
                              handler: { [self] _ in
            // Edit image informations
            self.editImage()
        })
        action.accessibilityIdentifier = "Edit Parameters"
        return action
    }
}


// MARK: - Edit Image Properties
extension ImageViewController
{
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
    func didDeselectImage(withID imageID: Int64) {
        // Should never be called when the properties of a single image are edited
    }

    func didChangeImageParameters(_ params: Image) {
        // Update title view
        setTitleViewFromImageData()
        
        // Update image metadata
        if let imagePVC = pageViewController?.viewControllers?.first {
            (imagePVC as? ImageDetailViewController)?.updateImageMetadata(with: params)
            (imagePVC as? VideoDetailViewController)?.updateImageMetadata(with: params)
            (imagePVC as? PdfDetailViewController)?.updateImageMetadata(with: params)
        }
    }

    func didFinishEditingParameters() {
        // Enable buttons after action
        setEnableStateOfButtons(true)

        // Reload tab bar
        updateNavBar()
    }
}
