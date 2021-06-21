//
//  PwgNotifications.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 20/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

@objc public
class PwgNotifications: NSObject {
    
    /// - Change palette colour
    @objc public static let paletteChangedObjc = "kPiwigoNotificationPaletteChanged"
    public static let paletteChanged = NSNotification.Name("kPiwigoNotificationPaletteChanged")
    
    /// - Add category ID to the top of the list of recent albums
    @objc public static let addRecentAlbumObjc = "kPiwigoNotificationAddRecentAlbum"
    public static let addRecentAlbum = NSNotification.Name("kPiwigoNotificationAddRecentAlbum")
    
    /// - Remove category ID from the list of recent albums
    @objc public static let removeRecentAlbumObjc = "kPiwigoNotificationRemoveRecentAlbum"
    let removeRecentAlbum = NSNotification.Name("kPiwigoNotificationRemoveRecentAlbum")
    
}
