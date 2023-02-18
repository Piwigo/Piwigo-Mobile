//
//  SettingsViewController+Cache.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 18/02/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

extension SettingsViewController
{
    func getThumbnailSizes() -> Set<pwgImageSize> {
        // Album and photo thumbnails
        // Select images whose size is lower than the default preview size
        let allSizes = pwgImageSize.allCases
        return Set(allSizes.filter({$0.rawValue < ImageVars.shared.defaultImagePreviewSize}))
    }
    
    func getPhotoSizes() -> Set<pwgImageSize> {
        // Album and photo thumbnails
        // Select images whose size is lower than the default preview size
        let allSizes = pwgImageSize.allCases
        return Set(allSizes.filter({$0.rawValue >= ImageVars.shared.defaultImagePreviewSize}))
    }
    
    func updatePhotoCacheCell() {
        let indexPath = IndexPath(row: 0, section: SettingsSection.cache.rawValue)
        if let indexPaths = self.settingsTableView.indexPathsForVisibleRows, indexPaths.contains(indexPath),
           let cell = self.settingsTableView.cellForRow(at: indexPath) as? LabelTableViewCell {
            cell.detailLabel.text = self.photoCacheSize
        }
    }
    
    func updateThumbCacheCell() {
        let indexPath = IndexPath(row: 1, section: SettingsSection.cache.rawValue)
        if let indexPaths = self.settingsTableView.indexPathsForVisibleRows, indexPaths.contains(indexPath),
           let cell = self.settingsTableView.cellForRow(at: indexPath) as? LabelTableViewCell {
            cell.detailLabel.text = self.thumbCacheSize
        }
    }
    
    func getClearCacheAlert() -> UIAlertController {
        let alert = UIAlertController(title: "", message:NSLocalizedString("settings_cacheClearMsg", comment: "Are you sure you want to clear the cache? This will make albums and images take a while to load again."), preferredStyle: .actionSheet)

        title = String(format: "%@ (%@)", NSLocalizedString("settingsHeader_thumbnails", comment: "Thumbnails"), thumbCacheSize)
        let clearThumbCacheAction = UIAlertAction(title: title, style: .default, handler: { action in
            // Delete album and photo thumbnails in foreground queue
            guard let server = self.user.server else {
                fatalError("••> User not provided!")
            }
            let sizes = self.getThumbnailSizes()
            server.clearCachedImages(ofSizes: sizes)

            // Refresh Settings cell
            self.thumbCacheSize = server.getCacheSize(forImageSizes: sizes)
            self.updateThumbCacheCell()
        })
        alert.addAction(clearThumbCacheAction)
        
        var title = String(format: "%@ (%@)", NSLocalizedString("severalImages", comment: "Photos"), photoCacheSize)
        let clearPhotoCacheAction = UIAlertAction(title: title, style: .default, handler: { action in
            // Delete high-resolution images in foreground queue
            guard let server = self.user.server else {
                fatalError("••> User not provided!")
            }
            let sizes = self.getPhotoSizes()
            server.clearCachedImages(ofSizes: sizes)

            // Refresh photo cache cell
            self.photoCacheSize = server.getCacheSize(forImageSizes: sizes)
            self.updatePhotoCacheCell()
        })
        alert.addAction(clearPhotoCacheAction)
        
#if DEBUG
        let clearAlbumsAction = UIAlertAction(title: "Album Data",
                                              style: .default, handler: { action in
            // Delete all albums in foreground queue
            self.albumProvider.clearAll()
        })
        alert.addAction(clearAlbumsAction)
        
        let clearImagesAction = UIAlertAction(title: "Photo Data",
                                              style: .default, handler: { action in
            // Delete all images in foreground queue
            ImageProvider().clearAll()
        })
        alert.addAction(clearImagesAction)
        
        let clearTagsAction = UIAlertAction(title: "Tag Data",
                                            style: .default, handler: { action in
            // Delete all tags in foreground queue
            TagProvider().clearAll()
        })
        alert.addAction(clearTagsAction)
        
        let titleClearLocations = "Location Data"
        let clearLocationsAction = UIAlertAction(title: titleClearLocations,
                                                 style: .default, handler: { action in
            // Delete all locations in foreground queue
            LocationProvider.shared.clearAll()
        })
        alert.addAction(clearLocationsAction)
        
        let clearUploadsAction = UIAlertAction(title: "Upload Requests",
                                               style: .default, handler: { action in
            // Delete all upload requests in foreground queue
            UploadProvider().clearAll()
        })
        alert.addAction(clearUploadsAction)
#else
        let clearDatabaseAction = UIAlertAction(title: "Database",
                                                style: .default, handler: { action in
            // Delete data in foreground queue
            ClearCache.clearData {
            }
        })
        alert.addAction(clearDatabaseAction)
#endif

        let clearAction = UIAlertAction(title: NSLocalizedString("settings_cacheClearAll", comment: "Clear All"), style: .destructive, handler: { action in
            // Delete whole cache in foreground queue
            ClearCache.clearData() {
                // Delete all images in foreground queue
                guard let server = self.user.server else {
                    fatalError("••> User not provided!")
                }
                // Clear all image files
                server.clearCachedImages(ofSizes: Set(pwgImageSize.allCases))

                // Refresh Settings cell related with images of preview size or above
                var sizes = self.getPhotoSizes()
                self.photoCacheSize = server.getCacheSize(forImageSizes: sizes)
                self.updatePhotoCacheCell()

                // Refresh Settings cell related with album and photo thumbnails
                sizes = self.getThumbnailSizes()
                self.thumbCacheSize = server.getCacheSize(forImageSizes: sizes)
                self.updateThumbCacheCell()
            }
        })
        alert.addAction(clearAction)

        let dismissAction = UIAlertAction(title: NSLocalizedString("alertDismissButton", comment: "Dismiss"), style: .cancel, handler: nil)
        alert.addAction(dismissAction)

        return alert
    }
}
