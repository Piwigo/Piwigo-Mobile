//
//  AlbumViewController+CopyMove.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

extension AlbumViewController
{
    // MARK: - Copy/Move Image Actions
    func imagesCopyAction() -> UIAction {
        let actionId = UIAction.Identifier("Copy")
        let action = UIAction(title: NSLocalizedString("copyImage_title", comment: "Copy to Album"),
                              image: UIImage(systemName: "photo.on.rectangle"),
                              identifier: actionId, handler: { [self] action in
            // Disable buttons during action
            setEnableStateOfButtons(false)
            // Retrieve complete image data before copying images
            initSelection(ofImagesWithIDs: selectedImageIDs, beforeAction: .copyImages, contextually: false)
        })
        action.accessibilityIdentifier = "copy"
        return action
    }
    
    func imagesMoveAction() -> UIAction {
        let actionId = UIAction.Identifier("Move")
        let action = UIAction(title: NSLocalizedString("moveImage_title", comment: "Move to Album"),
                              image: UIImage(systemName: "arrow.forward"),
                              identifier: actionId, handler: { [self] action in
            // Disable buttons during action
            setEnableStateOfButtons(false)
            // Retrieve complete image data before moving images
            initSelection(ofImagesWithIDs: selectedImageIDs, beforeAction: .moveImages, contextually: false)
        })
        action.accessibilityIdentifier = "move"
        return action
    }

    
    // MARK: - Copy/Move Images to Album
    func copyToAlbum(imagesWithID imageIDs: Set<Int64>) {
        let copySB = UIStoryboard(name: "SelectCategoryViewController", bundle: nil)
        guard let copyVC = copySB.instantiateViewController(withIdentifier: "SelectCategoryViewController") as? SelectCategoryViewController
        else { preconditionFailure("Could not instantiate SelectCategoryViewController") }
        let parameter: [Any] = [imageIDs, albumData.pwgID]
        copyVC.user = user
        if copyVC.setInput(parameter: parameter, for: .copyImages) {
            copyVC.delegate = self              // To re-enable toolbar
            pushView(copyVC)
        }
    }

    func moveToAlbum(imagesWithID imageIDs: Set<Int64>) {
        let moveSB = UIStoryboard(name: "SelectCategoryViewController", bundle: nil)
        guard let moveVC = moveSB.instantiateViewController(withIdentifier: "SelectCategoryViewController") as? SelectCategoryViewController
        else { preconditionFailure("Could not instantiate SelectCategoryViewController") }
        let parameter: [Any] = [imageIDs, albumData.pwgID]
        moveVC.user = user
        if moveVC.setInput(parameter: parameter, for: .moveImages) {
            moveVC.delegate = self              // To re-enable toolbar
            pushView(moveVC)
        }
    }
}


// MARK: - SelectCategoryDelegate Methods
extension AlbumViewController: SelectCategoryDelegate
{
    func didSelectCategory(withId category: Int32) {
        if category == Int32.min {
            setEnableStateOfButtons(true)
        } else {
            cancelSelect()
        }
    }
}


// MARK: - PushAlbumCollectionViewCellDelegate
extension AlbumViewController: PushAlbumCollectionViewCellDelegate
{
    func pushAlbumView(_ viewController: UIViewController?,
                       completion: @escaping (Bool) -> Void) {
        guard let viewController = viewController
        else { return }

        // Push sub-album, Discover or Favorites album
        if viewController is AlbumViewController {
            // Push sub-album view
            navigationController?.pushViewController(viewController, animated: true)
        }
        else {
            // Push album selector
            if view.traitCollection.userInterfaceIdiom == .pad {
                viewController.modalPresentationStyle = .formSheet
                viewController.modalTransitionStyle = .coverVertical
                viewController.popoverPresentationController?.sourceView = view
                viewController.popoverPresentationController?.sourceRect = CGRect(
                    x: view.bounds.midX, y: view.bounds.midY,
                    width: 0, height: 0)
                viewController.preferredContentSize = CGSize(
                    width: pwgPadSubViewWidth,
                    height: ceil(view.bounds.height * 2 / 3))
                present(viewController, animated: true) {
                    // Hide swipe commands
                    completion(true)
                }
            }
            else {
                let navController = UINavigationController(rootViewController: viewController)
                navController.modalPresentationStyle = .popover
                navController.popoverPresentationController?.sourceView = view
                navController.modalTransitionStyle = .coverVertical
                navigationController?.present(navController, animated: true) {
                    // Hide swipe commands
                    completion(true)
                }
            }
        }
    }
}
