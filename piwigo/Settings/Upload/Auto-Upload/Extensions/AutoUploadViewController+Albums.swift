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
            UploadVars.shared.autoUploadAlbumId = ""
            UploadVars.shared.isAutoUploadActive = false
        } else if photoAlbumId != UploadVars.shared.autoUploadAlbumId {
            // Did select another album
            UploadVars.shared.autoUploadAlbumId = photoAlbumId
            UploadVars.shared.isAutoUploadActive = false
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
            UploadVars.shared.autoUploadCategoryId = Int32.min
            UploadVars.shared.isAutoUploadActive = false
        } else if categoryId != UploadVars.shared.autoUploadCategoryId {
            // Did select another category
            UploadVars.shared.autoUploadCategoryId = categoryId
            UploadVars.shared.isAutoUploadActive = false
        }
    }
}
