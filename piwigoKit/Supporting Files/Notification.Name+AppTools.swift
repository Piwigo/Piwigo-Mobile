//
//  Notification.Name+AppTools.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 10/04/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

public extension Notification.Name {
    
    /// - Change palette colour
    static let pwgPaletteChanged = Notification.Name("kPiwigoNotificationPaletteChanged")

    // MARK: - Share images & videos
    /// - Share completed
    static let pwgDidShare = Notification.Name("kPiwigoNotificationDidShare")
    /// - Cancel download of object to share
    static let pwgCancelDownload = Notification.Name("kPiwigoNotificationCancelDownload")
    

    // MARK: - Recent albums
    /// - Add category ID to the top of the list of recent albums
    static let pwgAddRecentAlbum = Notification.Name("kPiwigoNotificationAddRecentAlbum")
    
    /// - Remove category ID from the list of recent albums
    static let pwgRemoveRecentAlbum = Notification.Name("kPiwigoNotificationRemoveRecentAlbum")
    
    
    // MARK: - Uploads
    /// - Update left number of upload requests
    static let pwgLeftUploads = Notification.Name("kPiwigoNotificationLeftUploads")
    
    /// - Update progress bars of upload requests
    static let pwgUploadProgress = Notification.Name("kPiwigoNotificationUploadProgress")
    
    /// - Notifies that auto-uploading is enabled by user
    static let pwgAutoUploadEnabled = Notification.Name("kPiwigoNotificationAutoUploadEnabled")

    /// - Notifies that auto-uploading was disabled by appendAutoUploadRequests()
    static let pwgAutoUploadDisabled = Notification.Name("kPiwigoNotificationAutoUploadDisabled")

    /// - Displays error when appendAutoUploadRequests() fails and resume upload manager operations
    static let pwgAppendAutoUploadRequestsFailed = Notification.Name("kPiwigoNotificationAppendAutoUploadRequestsFail")
    
    /// - Adds image uploaded with pwg.images.upload to CategoriesData cache
    static let pwgAddUploadedImageToCache = Notification.Name("kPiwigoNotificationAddUploadedImageToCache")
}
