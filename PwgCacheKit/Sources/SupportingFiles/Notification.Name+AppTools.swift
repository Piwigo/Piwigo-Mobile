//
//  Notification.Name+AppTools.swift
//  PwgCacheKit
//
//  Created by Eddy Lelièvre-Berna on 10/08/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation

public extension Notification.Name {
    
    // MARK: - Data Migrator
    /// - Update progress bar
    static let pwgMigrationProgressUpdated = Notification.Name("pwgNotificationMigrationProgressUpdated")
    
    
    // MARK: - Users
    /// - Notifies that the Piwigo ID of a user has become known
    static let pwgUserIDdidChange = Notification.Name("pwgNotificationUserIDdidChange")
    
    
    // MARK: - Images
    /// - Notifies that place names are available
    static let pwgPlaceNamesAvailable = Notification.Name("pwgPlaceNamesAvailable")
    
    
    // MARK: - Uploads
    /// - Notifies that auto-uploading should be disabled
    static let pwgDisableAutoUpload = Notification.Name("pwgNotificationDisableAutoUpload")
}
