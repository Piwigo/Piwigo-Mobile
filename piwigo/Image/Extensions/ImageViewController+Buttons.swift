//
//  ImageViewController+Buttons.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

extension ImageViewController
{
    // MARK: Get Bar Buttons
    func getMoveBarButton() -> UIBarButtonItem {
        return UIBarButtonItem.moveImageButton(self, action: #selector(addImageToCategory))
    }
    
    func getSetThumbnailBarButton() -> UIBarButtonItem {
        return UIBarButtonItem.setThumbnailButton(self, action: #selector(setAsAlbumImage))
    }
    
    func getDeleteBarButton() -> UIBarButtonItem {
        return UIBarButtonItem.deleteImageButton(self, action: #selector(deleteImage))
    }
    
    func getShareButton() -> UIBarButtonItem {
        return UIBarButtonItem.shareImageButton(self, action: #selector(ImageViewController.shareImage))
    }
}
