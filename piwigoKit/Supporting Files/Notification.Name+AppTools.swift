//
//  Notification.Name+AppTools.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 10/08/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation

public extension Notification.Name {
    
    // MARK: - Uploads
    /// - Notifies that auto-uploading should be disabled
    static let pwgDisableAutoUpload = Notification.Name("pwgNotificationDisableAutoUpload")
}
