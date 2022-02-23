//
//  AlbumVars.shared.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 25/05/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

class AlbumVars: NSObject {
        
    // Singleton
    @objc static let shared = AlbumVars()
    
    // Remove deprecated stored objects if needed
    override init() {
        // Deprecated data?
        if let _ = UserDefaults.dataSuite.object(forKey: "recentPeriod") {
            UserDefaults.dataSuite.removeObject(forKey: "recentPeriod")
        }
    }

    // MARK: - Vars in UserDefaults / Standard
    // Album variables stored in UserDefaults / Standard
    /// - Default root album, 0 by default
    @UserDefault("defaultCategory", defaultValue: 0)
    @objc var defaultCategory: Int

    /// - Default album thumbnail size determined from the available image sizes to present 144x144 pixel thumbnails
    @UserDefault("defaultAlbumThumbnailSize", defaultValue: PiwigoImageData.optimumAlbumThumbnailSizeForDevice().rawValue)
    @objc var defaultAlbumThumbnailSize: UInt32

    /// - List of albums recently visited / used
    @UserDefault("recentCategories", defaultValue: "0")
    @objc var recentCategories: String
    
    /// - Maximum number of recent categories  presented to the user
    @UserDefault("maxNberRecentCategories", defaultValue: 5)
    @objc var maxNberRecentCategories: Int

    /// - Default image sort option
    @UserDefault("defaultSort", defaultValue: kPiwigoSort.dateCreatedAscending.rawValue)
    @objc var defaultSort: Int16

    /// - Display images titles in collection views
    @UserDefault("displayImageTitles", defaultValue: true)
    @objc var displayImageTitles: Bool

    /// - Album thumbnail size determined from the available image sizes to present 144x144 pixel thumbnails
    @UserDefault("defaultThumbnailSize", defaultValue: PiwigoImageData.optimumImageThumbnailSizeForDevice().rawValue)
    @objc var defaultThumbnailSize: UInt32

    /// - Number of images per row in portrait mode
    @UserDefault("thumbnailsPerRowInPortrait", defaultValue: UIDevice.current.userInterfaceIdiom == .phone ? 4 : 6)
    @objc var thumbnailsPerRowInPortrait: Int

    /// - Recent period in number of days
    let recentPeriodKey = 594 // i.e. key used to detect the behaviour of the slider (sum of all periods)
    let recentPeriodList:[Int] = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,25,30,40,50,60,80,99]
    @UserDefault("recentPeriodIndex", defaultValue: 6)      // i.e index of the period of 7 days
    var recentPeriodIndex: Int
    

    // MARK: - Vars in UserDefaults / App Group
    // Album variables stored in UserDefaults / App Group
    /// - None


    // MARK: - Vars in Memory
    // Album variables kept in memory
    /// - Available image sizes
    @objc var hasSquareSizeImages = true
    @objc var hasThumbSizeImages = true
    @objc var hasXXSmallSizeImages = false
    @objc var hasXSmallSizeImages = false
    @objc var hasSmallSizeImages = false
    @objc var hasMediumSizeImages = true
    @objc var hasLargeSizeImages = false
    @objc var hasXLargeSizeImages = false
    @objc var hasXXLargeSizeImages = false
}
