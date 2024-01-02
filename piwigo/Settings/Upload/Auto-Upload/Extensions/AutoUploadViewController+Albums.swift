//
//  AutoUploadViewController+Albums.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/01/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import piwigoKit

// MARK: - LocalAlbumsSelectorDelegate Methods
extension AutoUploadViewController: LocalAlbumsSelectorDelegate {
    // Collect cosen Photo Library album (or whole Camera Roll)
    func didSelectPhotoAlbum(withId photoAlbumId: String) -> Void {
        // Check selection
        if photoAlbumId.isEmpty {
            // Did not select a Photo Library album
            UploadVars.autoUploadAlbumId = ""
            UploadVars.isAutoUploadActive = false
        } else if photoAlbumId != UploadVars.autoUploadAlbumId {
            // Did select another album
            UploadVars.autoUploadAlbumId = photoAlbumId
            UploadVars.isAutoUploadActive = false
        }
    }
}


// MARK: - SelectCategoryDelegate Methods
extension AutoUploadViewController: SelectCategoryDelegate {
    // Collect chosen Piwigo category
    func didSelectCategory(withId categoryId: Int32) -> Void {
        // Check selection
        if categoryId == Int32.min {
            // Did not select a Piwigo album
            UploadVars.autoUploadCategoryId = Int32.min
            UploadVars.isAutoUploadActive = false
        } else if categoryId != UploadVars.autoUploadCategoryId {
            // Did select another category
            UploadVars.autoUploadCategoryId = categoryId
            UploadVars.isAutoUploadActive = false
        }
    }
}
