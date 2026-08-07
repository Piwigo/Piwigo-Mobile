//
//  SettingsViewController+Images.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 11/12/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import PwgKit
import PwgCacheKit

// MARK: - DefaultImageThumbnailSizeDelegate Methods
extension SettingsViewController: DefaultImageThumbnailSizeDelegate {
    func didSelectImageDefaultThumbnailSize(_ thumbnailSize: pwgImageSize) {
        // Do nothing if size is unchanged
        guard let oldThumbnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize),
              thumbnailSize != oldThumbnailSize
        else { return }
        
        // Delete image thumbnails in background queue if not used anymore
        if oldThumbnailSize.rawValue != AlbumVars.shared.defaultAlbumThumbnailSize,
           oldThumbnailSize.rawValue != ImageVars.shared.defaultImagePreviewSize,
           oldThumbnailSize != .fullRes {
            
            DispatchQueue.global(qos: .userInitiated).async {
                // Get server instance
                let bckgContext = DataController.shared.newTaskContext()
                guard let server = try? ServerProvider().getCurrentServer(inContext: bckgContext)
                else { preconditionFailure("••> Server is not in cache!") }
                
                // Delete useless thumbnails
                server.clearCachedImages(ofSizes: [oldThumbnailSize], exceptVideos: true)
                
                // Recalculate cache size
                let sizes = self.getThumbnailSizes()
                let cacheSize = server.getCacheSize(forImageSizes: sizes)
                
                DispatchQueue.main.async {
                    // Refresh Settings cell
                    self.thumbCacheSize = cacheSize
                    self.updateThumbCacheCell()
                }
            }
        }

        // Save new choice
        AlbumVars.shared.defaultThumbnailSize = thumbnailSize.rawValue

        // Refresh settings
        let offset = defaultSortUnknown ? 1 : 0
        let indexPath = IndexPath(row: 0 + offset, section: SettingsSection.images.rawValue)
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
        
        // Delete image files in background queue if not used anymore
        if oldPhotoSize.rawValue != AlbumVars.shared.defaultAlbumThumbnailSize,
           oldPhotoSize.rawValue != AlbumVars.shared.defaultThumbnailSize,
           oldPhotoSize != .fullRes {
            
            DispatchQueue.global(qos: .userInitiated).async {
                // Get server instance
                let bckgContext = DataController.shared.newTaskContext()
                guard let server = try? ServerProvider().getCurrentServer(inContext: bckgContext)
                else { preconditionFailure("••> Server is not in cache!") }
                
                // Delete useless thumbnails
                server.clearCachedImages(ofSizes: [oldPhotoSize], exceptVideos: true)
                let sizes = self.getPhotoSizes()
                let cacheSize = server.getCacheSize(forImageSizes: sizes)
                
                DispatchQueue.main.async {
                    // Refresh Settings cell
                    self.thumbCacheSize = cacheSize
                    self.updatePhotoCacheCell()
                }
            }
        }

        // Save new choice
        ImageVars.shared.defaultImagePreviewSize = imageSize.rawValue

        // Refresh settings
        let offset = defaultSortUnknown ? 1 : 0
        let indexPath = IndexPath(row: 2 + offset, section: SettingsSection.images.rawValue)
        if let indexPaths = settingsTableView.indexPathsForVisibleRows, indexPaths.contains(indexPath),
           let cell = settingsTableView.cellForRow(at: indexPath) as? LabelTableViewCell {
            cell.detailLabel.text = imageSize.name
        }
    }
}
