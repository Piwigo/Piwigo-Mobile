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
    static let pwgPaletteChanged = Notification.Name("pwgNotificationPaletteChanged")

    // MARK: - Share images & videos
    /// - Share completed
    static let pwgDidShare = Notification.Name("pwgNotificationDidShare")
    /// - Cancel download of object to share
    static let pwgCancelDownload = Notification.Name("pwgNotificationCancelDownload")
    

    // MARK: - Recent albums
    /// - Add category ID to the top of the list of recent albums
    static let pwgAddRecentAlbum = Notification.Name("pwgNotificationAddRecentAlbum")
    
    /// - Remove category ID from the list of recent albums
    static let pwgRemoveRecentAlbum = Notification.Name("pwgNotificationRemoveRecentAlbum")
    
    
    // MARK: - Uploads
    /// - Update left number of upload requests
    static let pwgLeftUploads = Notification.Name("pwgNotificationLeftUploads")
    
    /// - Update progress bars of upload requests
    static let pwgUploadProgress = Notification.Name("pwgNotificationUploadProgress")
    
    /// - Notifies that auto-uploading is enabled by user
    static let pwgAutoUploadEnabled = Notification.Name("pwgNotificationAutoUploadEnabled")

    /// - Notifies that auto-uploading was disabled by appendAutoUploadRequests()
    static let pwgAutoUploadDisabled = Notification.Name("pwgNotificationAutoUploadDisabled")

    /// - Displays error when appendAutoUploadRequests() fails and resume upload manager operations
    static let pwgAppendAutoUploadRequestsFailed = Notification.Name("pwgNotificationAppendAutoUploadRequestsFail")
}
