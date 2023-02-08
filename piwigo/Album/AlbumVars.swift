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
    static let shared = AlbumVars()
    
    // Remove deprecated stored objects if needed
    override init() {
        // Deprecated data?
        if let _ = UserDefaults.dataSuite.object(forKey: "recentPeriod") {
            UserDefaults.dataSuite.removeObject(forKey: "recentPeriod")
        }
        if let defaultSort = UserDefaults.dataSuite.object(forKey: "defaultSort") {
            UserDefaults.dataSuite.removeObject(forKey: "defaultSort")
            UserDefaults.dataSuite.set(defaultSort, forKey: "defaultSortRaw")
        }
    }

    // MARK: - Vars in UserDefaults / Standard
    // Album variables stored in UserDefaults / Standard
    /// - Default root album, 0 by default
    @UserDefault("defaultCategory", defaultValue: Int32.zero)
    var defaultCategory: Int32

    /// - Default album thumbnail size determined from the available image sizes to present 144x144 pixel thumbnails
    @UserDefault("defaultAlbumThumbnailSize", defaultValue: AlbumUtilities.optimumAlbumThumbnailSizeForDevice().rawValue)
    var defaultAlbumThumbnailSize: Int16

    /// - List of albums recently visited / used
    @UserDefault("recentCategories", defaultValue: "0")
    var recentCategories: String
    
    /// - Maximum number of recent categories  presented to the user
    @UserDefault("maxNberRecentCategories", defaultValue: 5)
    var maxNberRecentCategories: Int

    /// - Default image sort option
    @UserDefault("defaultSortRaw", defaultValue: pwgImageSort.dateCreatedAscending.rawValue)
    private var defaultSortRaw: Int16
    var defaultSort: pwgImageSort {
        get { return pwgImageSort(rawValue: defaultSortRaw) ?? .dateCreatedAscending }
        set(value) {
            if pwgImageSort.allCases.contains(value) {
                defaultSortRaw = value.rawValue
            }
        }
    }

    /// - Display images titles in collection views
    @UserDefault("displayImageTitles", defaultValue: true)
    var displayImageTitles: Bool

    /// - Image thumbnail size determined from the available image sizes
    @UserDefault("defaultThumbnailSize", defaultValue: AlbumUtilities.optimumThumbnailSizeForDevice().rawValue)
    var defaultThumbnailSize: Int16

    /// - Number of images per row in portrait mode
    @UserDefault("thumbnailsPerRowInPortrait", defaultValue: UIDevice.current.userInterfaceIdiom == .phone ? 4 : 6)
    var thumbnailsPerRowInPortrait: Int

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
    var hasSquareSizeImages = true
    var hasThumbSizeImages = true
    var hasXXSmallSizeImages = false
    var hasXSmallSizeImages = false
    var hasSmallSizeImages = false
    var hasMediumSizeImages = true
    var hasLargeSizeImages = false
    var hasXLargeSizeImages = false
    var hasXXLargeSizeImages = false
}
