//
//  PwgNotifications.swift
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
    @objc public static let paletteChanged = PwgNotifications.paletteChanged.rawValue
    
    
    // MARK: - Recent albums
    /// - Add category ID to the top of the list of recent albums
    @objc public static let addRecentAlbum = PwgNotifications.addRecentAlbum.rawValue
    
    /// - Remove category ID from the list of recent albums
    @objc public static let removeRecentAlbum = PwgNotifications.removeRecentAlbum.rawValue
    
    
    // MARK: - Uploads
    /// - Update left number of upload requests
    @objc public static let leftUploads = PwgNotifications.leftUploads.rawValue
    
    /// - Update progress bars of upload requests
    @objc public static let uploadProgress = PwgNotifications.uploadProgress.rawValue
}
