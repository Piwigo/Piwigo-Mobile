//
//  ImageCollectionViewController+CopyMove.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

extension ImageCollectionViewController
{
    // MARK: - Copy/Move Bar Buttons
    func getMoveBarButton() -> UIBarButtonItem {
        return UIBarButtonItem(barButtonSystemItem: .reply, target: self,
                               action: #selector(copyMoveSelection))
    }

    
    // MARK: - Copy/Move Images to Album
    @objc func copyMoveSelection() {    // Alert displayed on iOS 9.x to 13.x
        // Disable buttons
        imageSelectionDelegate?.setButtonsState(false)

        // Present alert to user
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        let cancelAction = UIAlertAction(
            title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
            style: .cancel, handler: { [self] action in
                imageSelectionDelegate?.setButtonsState(true)
            })

        let copyAction = UIAlertAction(
            title: NSLocalizedString("copyImage_title", comment: "Copy to Album"),
            style: .default, handler: { [self] action in
                // Retrieve complete image data before copying images
                initSelection(beforeAction: .copyImages)
            })

        let moveAction = UIAlertAction(
            title: NSLocalizedString("moveImage_title", comment: "Move to Album"),
            style: .default, handler: { [self] action in
                // Retrieve complete image data before moving images
                initSelection(beforeAction: .moveImages)
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
        if let parent = parent as? AlbumImageTableViewController {
            alert.popoverPresentationController?.barButtonItem = parent.moveBarButton
        }
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange()
        }
    }

    func copyImagesToAlbum() {
        let copySB = UIStoryboard(name: "SelectCategoryViewController", bundle: nil)
        guard let copyVC = copySB.instantiateViewController(withIdentifier: "SelectCategoryViewController") as? SelectCategoryViewController else { return }
        let parameter: [Any] = [selectedImageIds, albumData.pwgID]
        copyVC.user = user
        if copyVC.setInput(parameter: parameter, for: .copyImages) {
            copyVC.delegate = self              // To re-enable toolbar
            imageSelectionDelegate?.pushSelectionToView(copyVC)
        }
    }

    func moveImagesToAlbum() {
        let moveSB = UIStoryboard(name: "SelectCategoryViewController", bundle: nil)
        guard let moveVC = moveSB.instantiateViewController(withIdentifier: "SelectCategoryViewController") as? SelectCategoryViewController else { return }
        let parameter: [Any] = [selectedImageIds, albumData.pwgID]
        moveVC.user = user
        if moveVC.setInput(parameter: parameter, for: .moveImages) {
            moveVC.delegate = self              // To re-enable toolbar
            imageSelectionDelegate?.pushSelectionToView(moveVC)
        }
    }
}


// MARK: - SelectCategoryDelegate Methods
extension ImageCollectionViewController: SelectCategoryDelegate
{
    func didSelectCategory(withId category: Int32) {
        if category == Int32.min {
            imageSelectionDelegate?.setButtonsState(true)
        } else {
            imageSelectionDelegate?.deselectImages()
        }
    }
}
