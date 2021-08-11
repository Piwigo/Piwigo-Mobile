//
//  AlbumVars.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 25/05/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

class AlbumVars: NSObject {
        
    // Remove deprecated stored objects if needed
//    override init() {
//        // Deprecated data?
//        if let _ = UserDefaults.dataSuite.object(forKey: "test") {
//            UserDefaults.dataSuite.removeObject(forKey: "test")
//        }
//    }

    // MARK: - Vars in UserDefaults / Standard
    // Album variables stored in UserDefaults / Standard
    /// - Default root album, 0 by default
    @UserDefault("defaultCategory", defaultValue: 0)
    @objc static var defaultCategory: Int

    /// - Default album thumbnail size determined from the available image sizes to present 144x144 pixel thumbnails
    @UserDefault("defaultAlbumThumbnailSize", defaultValue: PiwigoImageData.optimumAlbumThumbnailSizeForDevice().rawValue)
    @objc static var defaultAlbumThumbnailSize: UInt32

    /// - List of albums recently visited / used
    @UserDefault("recentCategories", defaultValue: "0")
    @objc static var recentCategories: String
    
    /// - Maximum number of recent categories  presented to the user
    @UserDefault("maxNberRecentCategories", defaultValue: 5)
    @objc static var maxNberRecentCategories: Int

    /// - Default image sort option
    @UserDefault("defaultSort", defaultValue: kPiwigoSort.dateCreatedAscending.rawValue)
    @objc static var defaultSort: Int16

    /// - Display images titles in collection views
    @UserDefault("displayImageTitles", defaultValue: true)
    @objc static var displayImageTitles: Bool

    /// - Album thumbnail size determined from the available image sizes to present 144x144 pixel thumbnails
    @UserDefault("defaultThumbnailSize", defaultValue: PiwigoImageData.optimumImageThumbnailSizeForDevice().rawValue)
    @objc static var defaultThumbnailSize: UInt32

    /// - Number of images per row in portrait mode
    @UserDefault("thumbnailsPerRowInPortrait", defaultValue: UIDevice.current.userInterfaceIdiom == .phone ? 4 : 6)
    @objc static var thumbnailsPerRowInPortrait: Int

    
    // MARK: - Vars in UserDefaults / App Group
    // Album variables stored in UserDefaults / App Group
    /// - None


    // MARK: - Vars in Memory
    // Album variables kept in memory
    /// - Available image sizes
    @objc static var hasSquareSizeImages = true
    @objc static var hasThumbSizeImages = true
    @objc static var hasXXSmallSizeImages = false
    @objc static var hasXSmallSizeImages = false
    @objc static var hasSmallSizeImages = false
    @objc static var hasMediumSizeImages = true
    @objc static var hasLargeSizeImages = false
    @objc static var hasXLargeSizeImages = false
    @objc static var hasXXLargeSizeImages = false
}
