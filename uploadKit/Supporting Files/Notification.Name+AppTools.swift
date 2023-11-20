//
//  Notification.Name+AppTools.swift
//  uploadKit
//
//  Created by Eddy Lelièvre-Berna on 10/08/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation

public extension Notification.Name {
    
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
    
    /// - Notifies that auto-uploading is enabled/disabled by user or disableAutoUpload()
    static let pwgAutoUploadChanged = Notification.Name("pwgNotificationAutoUploadChanged")

    /// - Displays error when appendAutoUploadRequests() fails and resume upload manager operations
    static let pwgAppendAutoUploadRequestsFailed = Notification.Name("pwgNotificationAppendAutoUploadRequestsFail")
}
