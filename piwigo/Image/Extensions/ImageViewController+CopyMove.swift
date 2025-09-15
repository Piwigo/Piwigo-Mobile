//
//  ImageViewController+CopyMove.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

// MARK: Copy/Move Image
extension ImageViewController
{
    // MARK: - Actions
    func copyAction() -> UIAction {
        // Copy image to album
        let action = UIAction(title: NSLocalizedString("copyImage_title", comment: "Copy to Album"),
                              image: UIImage(systemName: "photo.on.rectangle"),
                              handler: { [self] _ in
            // Disable buttons during action
            setEnableStateOfButtons(false)
            // Present album selector for copying image
            selectCategory(withAction: .copyImage)
        })
        action.accessibilityIdentifier = "org.piwigo.image.copy"
        return action
    }
    
    func moveAction() -> UIAction {
        let action = UIAction(title: NSLocalizedString("moveImage_title", comment: "Move to Album"),
                              image: UIImage(systemName: "arrow.forward"),
                              handler: { [self] _ in
            // Disable buttons during action
            setEnableStateOfButtons(false)
            
            // Present album selector for moving image
            selectCategory(withAction: .moveImage)
        })
        action.accessibilityIdentifier = "org.piwigo.image.move"
        return action
    }

    func selectCategory(withAction action: pwgCategorySelectAction) {
        let copySB = UIStoryboard(name: "SelectCategoryViewController", bundle: nil)
        guard let copyVC = copySB.instantiateViewController(withIdentifier: "SelectCategoryViewController") as? SelectCategoryViewController else { return }
        let parameter = [imageData, NSNumber(value: categoryId)]
        copyVC.user = user
        if copyVC.setInput(parameter: parameter, for: action) {
            copyVC.delegate = self                  // To re-enable toolbar
            if action == .copyImage {
                copyVC.imageCopiedDelegate = self   // To update image data after copy
            } else {
                copyVC.imageRemovedDelegate = self  // To remove image after move
            }
            pushView(copyVC, forButton: actionBarButton)
        }
    }
}


// MARK: - SelectCategoryOfImageDelegate Methods
extension ImageViewController: SelectCategoryImageCopiedDelegate
{
    func didCopyImage() {
        // Update menus
        updateNavBar()
        // Re-enable buttons
        setEnableStateOfButtons(true)
    }
}
