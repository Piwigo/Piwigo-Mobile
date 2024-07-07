//
//  AlbumViewController+Edit.swift
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
    // MARK: Edit Images Parameters Action
    @available(iOS 14.0, *)
    func editParamsAction() -> UIAction {
        let actionId = UIAction.Identifier("org.piwigo.images.edit")
        let action = UIAction(title: NSLocalizedString("imageOptions_properties", comment: "Modify Properties"),
                              image: UIImage(systemName: "pencil"),
                              identifier: actionId, handler: { [self] action in
           // Edit image informations
            editSelection()
        })
        action.accessibilityIdentifier = "editProperties"
        return action
    }


    // MARK: Edit Images Parameters
    @objc func editSelection() {
        initSelection(beforeAction: .edit)
    }

    func editImages() {
        if selectedImageIds.isEmpty {
            // No image => End (should never happen)
            navigationController?.updateHUDwithSuccess() { [self] in
                navigationController?.hideHUD(afterDelay: pwgDelayHUD) { [self] in
                    cancelSelect()
                }
            }
            return
        }
        
        // Present EditImageParams view
        let editImageSB = UIStoryboard(name: "EditImageParamsViewController", bundle: nil)
        guard let editImageVC = editImageSB.instantiateViewController(withIdentifier: "EditImageParamsViewController") as? EditImageParamsViewController
        else { preconditionFailure("Could not load EditImageParamsViewController") }
        editImageVC.user = user
        let albumImages = images.fetchedObjects ?? []
        editImageVC.images = albumImages.filter({selectedImageIds.contains($0.pwgID)})
        editImageVC.delegate = self
        pushView(editImageVC)
    }
}


// MARK: - EditImageParamsDelegate Methods
extension AlbumViewController: EditImageParamsDelegate
{
    func didDeselectImage(withId imageId: Int64) {
        // Deselect image
        selectedImageIds.remove(imageId)
        selectedFavoriteIds.remove(imageId)
        selectedVideosIds.remove(imageId)
        collectionView?.reloadData()
    }

    func didChangeImageParameters(_ params: Image) {
        // Refresh image cell
//        let indexPath = IndexPath(item: indexOfUpdatedImage, section: 0)
//        if imagesCollection?.indexPathsForVisibleItems.contains(indexPath) ?? false {
//            imagesCollection?.reloadItems(at: [indexPath])
//        }
    }

    func didFinishEditingParameters() {
        cancelSelect()
    }
}
