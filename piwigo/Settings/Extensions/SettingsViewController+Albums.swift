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
        if thumbnailSize == pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) {
            return
        }
        
        // Save new choice
        AlbumVars.shared.defaultAlbumThumbnailSize = thumbnailSize.rawValue

        // Refresh settings row
        let indexPath = IndexPath(row: 1, section: SettingsSection.albums.rawValue)
        if let indexPaths = settingsTableView.indexPathsForVisibleRows, indexPaths.contains(indexPath),
           let cell = settingsTableView.cellForRow(at: indexPath) as? LabelTableViewCell {
            cell.detailLabel.text = AlbumUtilities.albumThumbnailSizeName(for: thumbnailSize)
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
        
        // Clear image data in cache
        for category in CategoriesData.sharedInstance().allCategories {
            category.resetData()
        }
    }
}
