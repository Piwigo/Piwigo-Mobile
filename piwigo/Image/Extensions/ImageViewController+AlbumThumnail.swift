//
//  ImageViewController+AlbumThumnail.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

extension ImageViewController
{
    // MARK: - Set Image as Album Thumbnail
    @objc func setAsAlbumImage() {
        // Check image data
        guard let imageData = imageData else { return }
        
        // Disable buttons during action
        setEnableStateOfButtons(false)

        // Present SelectCategory view
        let setThumbSB = UIStoryboard(name: "SelectCategoryViewController", bundle: nil)
        guard let setThumbVC = setThumbSB.instantiateViewController(withIdentifier: "SelectCategoryViewController") as? SelectCategoryViewController else { return }
        setThumbVC.albumProvider = albumProvider
        setThumbVC.savingContext = savingContext
        if setThumbVC.setInput(parameter:[imageData, categoryId], for: .setAlbumThumbnail) {
            setThumbVC.delegate = self
            if #available(iOS 14.0, *) {
                pushView(setThumbVC, forButton: actionBarButton)
            } else {
                pushView(setThumbVC, forButton: setThumbnailBarButton)
            }
        }
    }
}
