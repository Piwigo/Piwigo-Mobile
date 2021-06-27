//
//  PwgNotifications.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 20/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

public class PwgNotifications: NSObject {
    
    /// - Change palette colour
    public static let paletteChanged = NSNotification.Name("kPiwigoNotificationPaletteChanged")
    
    
    // MARK: - Recent albums
    /// - Add category ID to the top of the list of recent albums
    public static let addRecentAlbum = NSNotification.Name("kPiwigoNotificationAddRecentAlbum")
    
    /// - Remove category ID from the list of recent albums
    public static let removeRecentAlbum = NSNotification.Name("kPiwigoNotificationRemoveRecentAlbum")
    
    
    // MARK: - Uploads
    /// - Update left number of upload requests
    public static let leftUploads = NSNotification.Name("kPiwigoNotificationLeftUploads")
    
    /// - Update progress bars of upload requests
    public static let uploadProgress = Notification.Name("kPiwigoNotificationUploadProgress")
    
    /// - Disable auto-uploading when appendAutoUploadRequests() fails
    public static let disableAutoUpload = Notification.Name("kPiwigoNotificationDisableAutoUpload")

    /// - Displays error when appendAutoUploadRequests() fails and resume upload manager operations
    public static let appendAutoUploadRequestsFailed = Notification.Name("kPiwigoNotificationAppendAutoUploadRequestsFail")
    
    /// - Adds image uploaded with pwg.images.upload to CategoriesData cache
    public static let addUploadedImageToCache = Notification.Name("kPiwigoNotificationAddUploadedImageToCache")
}
