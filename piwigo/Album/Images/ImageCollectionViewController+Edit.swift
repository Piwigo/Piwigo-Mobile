//
//  ImageCollectionViewController+Edit.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

// MARK: Edit Images Parameters
extension ImageCollectionViewController
{
    @objc func editSelection() {
        initSelection(beforeAction: .edit)
    }

    func editImages() {
        if selectedImageIds.isEmpty {
            // No image => End (should never happen)
            updatePiwigoHUDwithSuccess() { [self] in
                hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { [self] in
                    imageSelectionDelegate?.deselectImages()
                }
            }
            return
        }
        
        // Present EditImageParams view
        let editImageSB = UIStoryboard(name: "EditImageParamsViewController", bundle: nil)
        guard let editImageVC = editImageSB.instantiateViewController(withIdentifier: "EditImageParamsViewController") as? EditImageParamsViewController else {
            fatalError("No EditImageParamsViewController!")
        }
        editImageVC.user = user
        editImageVC.images = (images.fetchedObjects ?? []).filter({selectedImageIds.contains($0.pwgID)})
        editImageVC.delegate = self
        imageSelectionDelegate?.pushSelectionToView(editImageVC)
    }
}


// MARK: - EditImageParamsDelegate Methods
extension ImageCollectionViewController: EditImageParamsDelegate
{
    func didDeselectImage(withId imageId: Int64) {
        // Deselect image
        selectedImageIds.remove(imageId)
        selectedFavoriteIds.remove(imageId)
        collectionView?.reloadData()
    }

    func didChangeImageParameters(_ params: Image) {
        // Refresh image cell
//        let indexPath = IndexPath(item: indexOfUpdatedImage, section: 1)
//        if imagesCollection?.indexPathsForVisibleItems.contains(indexPath) ?? false {
//            imagesCollection?.reloadItems(at: [indexPath])
//        }
    }

    func didFinishEditingParameters() {
        imageSelectionDelegate?.deselectImages()
    }
}
