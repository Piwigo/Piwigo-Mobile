//
//  ImageViewController+CopyMove.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

extension ImageViewController
{
    func selectCategory(withAction action: pwgCategorySelectAction) {
        let copySB = UIStoryboard(name: "SelectCategoryViewController", bundle: nil)
        guard let copyVC = copySB.instantiateViewController(withIdentifier: "SelectCategoryViewController") as? SelectCategoryViewController else { return }
        let parameter = [imageData, NSNumber(value: categoryId)]
        copyVC.userProvider = userProvider
        copyVC.albumProvider = albumProvider
        copyVC.imageProvider = imageProvider
        copyVC.savingContext = savingContext
        if copyVC.setInput(parameter: parameter, for: action) {
            copyVC.delegate = self                  // To re-enable toolbar
            if action == .copyImage {
                copyVC.imageCopiedDelegate = self   // To update image data after copy
            } else {
                copyVC.imageRemovedDelegate = self  // To remove image after move
            }
            if #available(iOS 14.0, *) {
                pushView(copyVC, forButton: actionBarButton)
            } else {
                pushView(copyVC, forButton: moveBarButton)
            }
        }
    }
    
    @objc func addImageToCategory() {
        // Disable buttons during action
        setEnableStateOfButtons(false)

        // If image selected from Search, immediatley propose to copy it
        if categoryId == pwgSmartAlbum.search.rawValue {
            // Present album selector for copying image
            self.selectCategory(withAction: .copyImage)
            return
        }

        // Image selected from album collection
        let alert = UIAlertController(title: nil, message: nil,
            preferredStyle: .actionSheet)

        let cancelAction = UIAlertAction(
            title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
            style: .cancel, handler: { [self] action in
                // Re-enable buttons
                setEnableStateOfButtons(true)
            })

        let copyAction = UIAlertAction(
            title: NSLocalizedString("copyImage_title", comment: "Copy to Album"),
            style: .default, handler: { [self] action in
                // Present album selector for copying image
                self.selectCategory(withAction: .copyImage)
            })

        let moveAction = UIAlertAction(
            title: NSLocalizedString("moveImage_title", comment: "Move to Album"),
            style: .default, handler: { [self] action in
                // Present album selector for moving image
                self.selectCategory(withAction: .moveImage)
            })

        // Add actions
        alert.addAction(cancelAction)
        alert.addAction(copyAction)
        alert.addAction(moveAction)

        // Present list of actions
        alert.view.tintColor = .piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        }
        alert.popoverPresentationController?.barButtonItem = moveBarButton
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = .piwigoColorOrange()
        }
    }
}


// MARK: - SelectCategoryOfImageDelegate Methods
extension ImageViewController: SelectCategoryImageCopiedDelegate
{
    func didCopyImage() {
        // Re-enable buttons
        setEnableStateOfButtons(true)
    }
}
