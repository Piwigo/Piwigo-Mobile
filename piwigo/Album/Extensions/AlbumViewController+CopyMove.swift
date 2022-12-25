//
//  AlbumViewController+CopyMove.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

extension AlbumViewController
{
    // MARK: - Copy/Move Images to Album
    @objc func copyMoveSelection() {    // Alert displayed on iOS 9.x to 13.x
        // Disable buttons
        setEnableStateOfButtons(false)

        // Present alert to user
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        let cancelAction = UIAlertAction(
            title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
            style: .cancel, handler: { [self] action in
                setEnableStateOfButtons(true)
            })

        let copyAction = UIAlertAction(
            title: NSLocalizedString("copyImage_title", comment: "Copy to Album"),
            style: .default, handler: { [self] action in
                copyImagesToAlbum()
            })

        let moveAction = UIAlertAction(
            title: NSLocalizedString("moveImage_title", comment: "Move to Album"),
            style: .default, handler: { [self] action in
                moveImagesToAlbum()
            })

        // Add actions
        alert.addAction(cancelAction)
        alert.addAction(copyAction)
        alert.addAction(moveAction)

        // Present list of actions
        alert.view.tintColor = UIColor.piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        }
        alert.popoverPresentationController?.barButtonItem = moveBarButton
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange()
        }
    }

    func copyImagesToAlbum() {
        let copySB = UIStoryboard(name: "SelectCategoryViewController", bundle: nil)
        guard let copyVC = copySB.instantiateViewController(withIdentifier: "SelectCategoryViewController") as? SelectCategoryViewController else { return }
        let parameter: [Any] = [selectedImageIds, NSNumber(value: categoryId)]
        copyVC.userProvider = userProvider
        copyVC.albumProvider = albumProvider
        copyVC.savingContext = mainContext
        if copyVC.setInput(parameter: parameter, for: .copyImages) {
            copyVC.delegate = self              // To re-enable toolbar
            pushView(copyVC)
        }
    }

    func moveImagesToAlbum() {
        let moveSB = UIStoryboard(name: "SelectCategoryViewController", bundle: nil)
        guard let moveVC = moveSB.instantiateViewController(withIdentifier: "SelectCategoryViewController") as? SelectCategoryViewController else { return }
        let parameter: [Any] = [selectedImageIds, NSNumber(value: categoryId)]
        moveVC.userProvider = userProvider
        moveVC.albumProvider = albumProvider
        moveVC.savingContext = mainContext
        if moveVC.setInput(parameter: parameter, for: .moveImages) {
            moveVC.delegate = self              // To re-enable toolbar
            pushView(moveVC)
        }
    }
}
