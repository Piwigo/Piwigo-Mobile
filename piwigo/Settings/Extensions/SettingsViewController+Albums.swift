//
//  SettingsViewController+Albums.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 11/12/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

// MARK: DefaultAlbumThumbnailSizeDelegate Methods
extension SettingsViewController: DefaultAlbumThumbnailSizeDelegate {
    func didSelectAlbumDefaultThumbnailSize(_ thumbnailSize: pwgImageSize) {
        // Do nothing if size is unchanged
        guard let oldThumbnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize),
              thumbnailSize != oldThumbnailSize else {
            return
        }
        
        // Delete album thumbnails in foreground queue if not used anymore
        DispatchQueue.global(qos: .userInitiated).async {
            guard let server = self.user.server else {
                fatalError("••> User not provided!")
            }
            if oldThumbnailSize.rawValue != AlbumVars.shared.defaultThumbnailSize,
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
        AlbumVars.shared.defaultAlbumThumbnailSize = thumbnailSize.rawValue

        // Refresh settings row
        let indexPath = IndexPath(row: 1, section: SettingsSection.albums.rawValue)
        if let indexPaths = settingsTableView.indexPathsForVisibleRows, indexPaths.contains(indexPath),
           let cell = settingsTableView.cellForRow(at: indexPath) as? LabelTableViewCell {
            cell.detailLabel.text = thumbnailSize.name
        }
    }
}


// MARK: - SelectCategoryDelegate Methods
extension SettingsViewController: SelectCategoryDelegate {
    func didSelectCategory(withId categoryId: Int32) {
        // Do nothing if new default album is unknown or unchanged
        guard categoryId != Int32.min,
              categoryId != AlbumVars.shared.defaultCategory else {
            return
        }

        // Save new choice
        AlbumVars.shared.defaultCategory = categoryId

        // Change album name in row
        let indexPath = IndexPath(row: 0, section: SettingsSection.albums.rawValue)
        if let indexPaths = settingsTableView.indexPathsForVisibleRows, indexPaths.contains(indexPath),
           let cell = settingsTableView.cellForRow(at: indexPath) as? LabelTableViewCell {
            cell.detailLabel.text = defaultAlbumName()
        }

        // Switch to new default album
        settingsDelegate?.didChangeDefaultAlbum()
    }
    
    func defaultAlbumName() -> String {
        var rootName: String
        if view.bounds.size.width > 375 {
            rootName = pwgSmartAlbum.root.name
        } else {
            rootName = NSLocalizedString("categorySelection_root<375pt", comment: "Root")
        }

        // Root album?
        if AlbumVars.shared.defaultCategory == 0 {
            return rootName
        }
        
        // Default album…
        if let album = albumProvider.getAlbum(ofUser: user, withId: AlbumVars.shared.defaultCategory),
           album.name.isEmpty == false {
            return album.name
        } else {
            return NSLocalizedString("categorySelection_title", comment: "Album")
        }
    }
}


// MARK: - CategorySortDelegate Methods
extension SettingsViewController: CategorySortDelegate {
    func didSelectCategorySortType(_ sortType: pwgImageSort) {
        // Do nothing if sort type is unchanged
        if sortType == AlbumVars.shared.defaultSort { return }
        
        // Save new choice
        AlbumVars.shared.defaultSort = sortType

        // Refresh settings
        let indexPath = IndexPath(row: 0, section: SettingsSection.images.rawValue)
        if let indexPaths = settingsTableView.indexPathsForVisibleRows, indexPaths.contains(indexPath),
           let cell = settingsTableView.cellForRow(at: indexPath) as? LabelTableViewCell {
            cell.detailLabel.text = sortType.name
        }
    }
}
