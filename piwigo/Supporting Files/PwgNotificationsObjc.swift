//
//  PwgNotificationsObjc.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 20/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

@objc public
class PwgNotificationsObjc: NSObject {
    
    /// - Change palette colour
    @objc public static let pwgPaletteChanged = Notification.Name.pwgPaletteChanged.rawValue
    
    
    // MARK: - Recent albums
    /// - Add category ID to the top of the list of recent albums
    @objc public static let pwgAddRecentAlbum = Notification.Name.pwgAddRecentAlbum.rawValue
    
    /// - Remove category ID from the list of recent albums
    @objc public static let pwgRemoveRecentAlbum = Notification.Name.pwgRemoveRecentAlbum.rawValue
    
    
    // MARK: - Uploads
    /// - Update left number of upload requests
    @objc public static let pwgLeftUploads = Notification.Name.pwgLeftUploads.rawValue
    
    /// - Update progress bars of upload requests
    @objc public static let pwgUploadProgress = Notification.Name.pwgUploadProgress.rawValue

    /// - Notifies that auto-uploading is enabled by user
    @objc public static let pwgAutoUploadEnabled = Notification.Name.pwgAutoUploadEnabled.rawValue

    /// - Notifies that auto-uploading was disabled by appendAutoUploadRequests()
    @objc public static let pwgAutoUploadDisabled = Notification.Name.pwgAutoUploadDisabled.rawValue
}
