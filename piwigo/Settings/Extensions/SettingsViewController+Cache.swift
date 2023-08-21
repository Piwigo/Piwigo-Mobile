//
//  SettingsViewController+Cache.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 18/02/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit
import uploadKit

extension SettingsViewController
{
    // MARK: - Image Sizes
    func getThumbnailSizes() -> Set<pwgImageSize> {
        // Album and photo thumbnails
        // Select images whose size is lower than the default preview size
        let allSizes = pwgImageSize.allCases
        let thumbSize = max(AlbumVars.shared.defaultThumbnailSize, AlbumVars.shared.defaultAlbumThumbnailSize)
        return Set(allSizes.filter({$0.rawValue <= thumbSize}))
    }
    
    func getPhotoSizes() -> Set<pwgImageSize> {
        // Album and photo thumbnails
        // Select images whose size is lower than the default preview size
        let allSizes = pwgImageSize.allCases
        let thumbSize = max(AlbumVars.shared.defaultThumbnailSize, AlbumVars.shared.defaultAlbumThumbnailSize)
        return Set(allSizes.filter({$0.rawValue > thumbSize}))
    }
    
    
    // MARK: - Update Cache Cells
    func updateDataCacheCell() {
        let section = SettingsSection.cache.rawValue - (hasUploadRights() ? 0 : 1)
        let indexPath = IndexPath(row: 0, section: section)
        if let cell = self.settingsTableView.cellForRow(at: indexPath) as? LabelTableViewCell {
            cell.detailLabel.text = self.dataCacheSize
        }
    }

    func updateThumbCacheCell() {
        let section = SettingsSection.cache.rawValue - (hasUploadRights() ? 0 : 1)
        let indexPath = IndexPath(row: 1, section: section)
        if let cell = self.settingsTableView.cellForRow(at: indexPath) as? LabelTableViewCell {
            cell.detailLabel.text = self.thumbCacheSize
        }
    }

    func updatePhotoCacheCell() {
        let section = SettingsSection.cache.rawValue - (hasUploadRights() ? 0 : 1)
        let indexPath = IndexPath(row: 2, section: section)
        if let cell = self.settingsTableView.cellForRow(at: indexPath) as? LabelTableViewCell {
            cell.detailLabel.text = self.photoCacheSize
        }
    }
    
    func updateUploadCacheCell() {
        let section = SettingsSection.cache.rawValue - (hasUploadRights() ? 0 : 1)
        let indexPath = IndexPath(row: 3, section: section)
        if let cell = self.settingsTableView.cellForRow(at: indexPath) as? LabelTableViewCell {
            cell.detailLabel.text = self.uploadCacheSize
        }
    }


    // MARK: - Return Clear Cache Alert
    func getClearCacheAlert() -> UIAlertController {
        let alert = UIAlertController(title: "", message:NSLocalizedString("settings_cacheClearMsg", comment: "Are you sure you want to clear the cache? This will make albums and images take a while to load again."), preferredStyle: .actionSheet)

        var title = String(format: "%@ (%@)", NSLocalizedString("settings_database", comment: "Data"), dataCacheSize)
        let clearDataAction = UIAlertAction(title: title, style: .default, handler: { action in
            // Delete all data and directories in foreground queue
            ClearCache.clearData() {
                // Get server instance
                guard let server = self.user.server else {
                    assert(self.user?.server != nil, "••> User not provided!")
                    return
                }
                try? self.mainContext.save()

                // Refresh Settings cell related with data
                self.dataCacheSize = server.getAlbumImageCount()
            }
        })
        alert.addAction(clearDataAction)

        title = String(format: "%@ (%@)", NSLocalizedString("settingsHeader_thumbnails", comment: "Thumbnails"), thumbCacheSize)
        let clearThumbCacheAction = UIAlertAction(title: title, style: .default, handler: { action in
            // Delete album and photo thumbnails in foreground queue
            guard let server = self.user?.server else {
                assert(self.user?.server != nil, "••> User not provided!")
                return
            }
            let sizes = self.getThumbnailSizes()
            server.clearCachedImages(ofSizes: sizes)

            // Refresh Settings cell
            self.thumbCacheSize = server.getCacheSize(forImageSizes: sizes)
        })
        alert.addAction(clearThumbCacheAction)
        
        title = String(format: "%@ (%@)", NSLocalizedString("severalImages", comment: "Photos"), photoCacheSize)
        let clearPhotoCacheAction = UIAlertAction(title: title, style: .default, handler: { action in
            // Delete high-resolution images in foreground queue
            guard let server = self.user.server else {
                assert(self.user?.server != nil, "••> User not provided!")
                return
            }
            let sizes = self.getPhotoSizes()
            server.clearCachedImages(ofSizes: sizes)

            // Refresh photo cache cell
            self.photoCacheSize = server.getCacheSize(forImageSizes: sizes)
        })
        alert.addAction(clearPhotoCacheAction)
        
        if hasUploadRights() {
            title = String(format: "%@ (%@)", NSLocalizedString("UploadRequests_cache", comment: "Uploads"), uploadCacheSize)
            let clearUploadCacheAction = UIAlertAction(title: title, style: .default, handler: { action in
                // Delete upload data and Uploads/tempporary folders in foreground queue
                ClearCache.clearUploads() {
                    // Get server instance
                    guard let server = self.user.server else {
                        assert(self.user?.server != nil, "••> User not provided!")
                        return
                    }
                    try? self.mainContext.save()
                    
                    // Refresh upload cache cell
                    self.uploadCacheSize = server.getUploadCount()
                        + " | " + UploadManager.shared.getUploadsDirectorySize()
                }
            })
            alert.addAction(clearUploadCacheAction)
        }
        
        let clearAction = UIAlertAction(title: NSLocalizedString("settings_cacheClearAll", comment: "Clear All"), style: .destructive, handler: { action in
            // Delete whole cache and folders in foreground queue
            ClearCache.clearData() {
                // Get server instance
                guard let server = self.user.server else {
                    assert(self.user?.server != nil, "••> User not provided!")
                    return
                }
                try? self.mainContext.save()

                // Clear all image files
                server.clearCachedImages(ofSizes: Set(pwgImageSize.allCases))

                // Refresh variables and cells
                self.dataCacheSize = server.getAlbumImageCount()
                var sizes = self.getThumbnailSizes()
                self.thumbCacheSize = server.getCacheSize(forImageSizes: sizes)
                sizes = self.getPhotoSizes()
                self.photoCacheSize = server.getCacheSize(forImageSizes: sizes)
                self.uploadCacheSize = server.getUploadCount()
            }
        })
        alert.addAction(clearAction)

        let dismissAction = UIAlertAction(title: NSLocalizedString("alertDismissButton", comment: "Dismiss"), style: .cancel, handler: nil)
        alert.addAction(dismissAction)

        return alert
    }
}
