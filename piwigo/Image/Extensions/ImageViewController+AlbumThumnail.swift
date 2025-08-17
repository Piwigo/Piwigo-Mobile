//
//  ImageViewController+AlbumThumnail.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

// MARK: Set as Album Thumbnail
extension ImageViewController
{
    func setAsThumbnailAction() -> UIAction {
        let action = UIAction(title: NSLocalizedString("imageOptions_setAlbumImage",
                                                       comment:"Set as Album Thumbnail"),
                              image: UIImage(systemName: "rectangle.and.paperclip"),
                              handler: { [self] _ in
            // Present album selector for setting album thumbnail
            self.setAsAlbumImage()
        })
        action.accessibilityIdentifier = "org.piwigo.image.setThumbnail"
        return action
    }

    @objc func setAsAlbumImage() {
        // Check image data
        guard let imageData = imageData else { return }
        
        // Disable buttons during action
        setEnableStateOfButtons(false)

        // Present SelectCategory view
        let setThumbSB = UIStoryboard(name: "SelectCategoryViewController", bundle: nil)
        guard let setThumbVC = setThumbSB.instantiateViewController(withIdentifier: "SelectCategoryViewController") as? SelectCategoryViewController else { return }
        setThumbVC.user = user
        if setThumbVC.setInput(parameter:[imageData, categoryId] as [Any], for: .setAlbumThumbnail) {
            setThumbVC.delegate = self
            pushView(setThumbVC, forButton: actionBarButton)
        }
    }
}
