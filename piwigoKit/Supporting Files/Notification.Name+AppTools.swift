//
//  Notification.Name+AppTools.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 10/08/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation

public extension Notification.Name {
    
    // MARK: - Data Migrator
    /// - Update progress bar
    static let pwgMigrationProgressUpdated = Notification.Name("pwgNotificationMigrationProgressUpdated")
    
    
    // MARK: - Images
    /// - Notifies that place names are available
    static let pwgPlaceNamesAvailable = Notification.Name("pwgPlaceNamesAvailable")

    
    // MARK: - Uploads
    /// - Notifies that auto-uploading should be disabled
    static let pwgDisableAutoUpload = Notification.Name("pwgNotificationDisableAutoUpload")
}

