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
        guard let oldThumbnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize),
              thumbnailSize != oldThumbnailSize else {
            return
        }
        
        // Delete image thumbnails in foreground queue if not used anymore
        DispatchQueue.global(qos: .userInitiated).async {
            guard let server = self.user.server else {
                fatalError("••> User not provided!")
            }
            if oldThumbnailSize.rawValue != AlbumVars.shared.defaultAlbumThumbnailSize,
               oldThumbnailSize.rawValue != ImageVars.shared.defaultImagePreviewSize,
               oldThumbnailSize != .fullRes {
                server.clearCachedImages(ofSizes: [oldThumbnailSize], exceptVideos: true)
            }
            
            DispatchQueue.main.async {
                // Refresh Settings cell
                let sizes = self.getThumbnailSizes()
                self.thumbCacheSize = server.getCacheSize(forImageSizes: sizes)
                self.updateThumbCacheCell()
            }
        }

        // Save new choice
        AlbumVars.shared.defaultThumbnailSize = thumbnailSize.rawValue

        // Refresh settings
        let indexPath = IndexPath(row: 1, section: SettingsSection.images.rawValue)
        if let indexPaths = settingsTableView.indexPathsForVisibleRows, indexPaths.contains(indexPath),
           let cell = settingsTableView.cellForRow(at: indexPath) as? LabelTableViewCell {
            cell.detailLabel.text = thumbnailSize.name
        }
    }
}


// MARK: - DefaultImageSizeDelegate Methods
extension SettingsViewController: DefaultImageSizeDelegate {
    func didSelectImageDefaultSize(_ imageSize: pwgImageSize) {
        // Do nothing if size is unchanged
        guard let oldPhotoSize = pwgImageSize(rawValue: ImageVars.shared.defaultImagePreviewSize),
              imageSize != oldPhotoSize else {
            return
        }
        
        // Delete image files in foreground queue if not used anymore
        DispatchQueue.global(qos: .userInitiated).async {
            guard let server = self.user.server else {
                fatalError("••> User not provided!")
            }
            if oldPhotoSize.rawValue != AlbumVars.shared.defaultAlbumThumbnailSize,
               oldPhotoSize.rawValue != AlbumVars.shared.defaultThumbnailSize,
               oldPhotoSize != .fullRes {
                server.clearCachedImages(ofSizes: [oldPhotoSize], exceptVideos: true)
            }
            
            DispatchQueue.main.async {
                // Refresh Settings cell
                let sizes = self.getPhotoSizes()
                self.thumbCacheSize = server.getCacheSize(forImageSizes: sizes)
                self.updatePhotoCacheCell()
            }
        }

        // Save new choice
        ImageVars.shared.defaultImagePreviewSize = imageSize.rawValue

        // Refresh settings
        let indexPath = IndexPath(row: 4, section: SettingsSection.images.rawValue)
        if let indexPaths = settingsTableView.indexPathsForVisibleRows, indexPaths.contains(indexPath),
           let cell = settingsTableView.cellForRow(at: indexPath) as? LabelTableViewCell {
            cell.detailLabel.text = imageSize.name
        }
    }
}
