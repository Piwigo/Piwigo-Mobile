//
//  SettingsViewController+Images.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 11/12/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

// MARK: - DefaultImageThumbnailSizeDelegate Methods
extension SettingsViewController: DefaultImageThumbnailSizeDelegate {
    func didSelectImageDefaultThumbnailSize(_ thumbnailSize: pwgImageSize) {
        // Do nothing if size is unchanged
        if thumbnailSize == pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) { return }
        
        // Save new choice
        AlbumVars.shared.defaultThumbnailSize = thumbnailSize.rawValue

        // Refresh settings
        let indexPath = IndexPath(row: 1, section: SettingsSection.images.rawValue)
        if let indexPaths = settingsTableView.indexPathsForVisibleRows, indexPaths.contains(indexPath),
           let cell = settingsTableView.cellForRow(at: indexPath) as? LabelTableViewCell {
            cell.detailLabel.text = AlbumUtilities.thumbnailSizeName(for: thumbnailSize)
        }
    }
}


// MARK: - DefaultImageSizeDelegate Methods
extension SettingsViewController: DefaultImageSizeDelegate {
    func didSelectImageDefaultSize(_ imageSize: pwgImageSize) {
        // Do nothing if size is unchanged
        if imageSize == pwgImageSize(rawValue: ImageVars.shared.defaultImagePreviewSize) { return }
        
        // Save new choice
        ImageVars.shared.defaultImagePreviewSize = imageSize.rawValue

        // Refresh settings
        let indexPath = IndexPath(row: 4, section: SettingsSection.images.rawValue)
        if let indexPaths = settingsTableView.indexPathsForVisibleRows, indexPaths.contains(indexPath),
           let cell = settingsTableView.cellForRow(at: indexPath) as? LabelTableViewCell {
            cell.detailLabel.text = ImageUtilities.imageSizeName(for: imageSize)
        }
    }
}
