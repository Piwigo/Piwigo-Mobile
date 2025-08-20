//
//  AlbumSmart.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 23/10/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - Album Sort Types
public enum pwgSmartAlbum: Int32 {
    case root      = 0          // Root album
    case search    = -1         // Search
    case visits    = -2         // Most visited
    case best      = -3         // Best rated
    case recent    = -4         // Recent photos
    case favorites = -5         // Favorites
    case tagged    = -10        // Tagged photos (offset applied to tag ID)
}

// When adopting iOS 16 as minimum target, migrate to LocalizedStringResource()
extension pwgSmartAlbum {
    public var name: String {
        switch self {
        case .root:
            return String(localized: "categorySelection_root", bundle: piwigoKit,
                          comment: "Root Album")
        case .search:
            return ""
        
        case .visits:
            return String(localized: "categoryDiscoverVisits_title", bundle: piwigoKit,
                          comment: "Most visited")
        case .best:
            return String(localized: "categoryDiscoverBest_title", bundle: piwigoKit,
                          comment: "Best rated")
        case .recent:
            return String(localized: "categoryDiscoverRecent_title", bundle: piwigoKit,
                          comment: "Recent photos")
        case .favorites:
            return String(localized: "categoryDiscoverFavorites_title", bundle: piwigoKit,
                          comment: "My Favorites")
        case .tagged:
            return String(localized: "categoryDiscoverTagged_title", bundle: piwigoKit,
                          comment: "Tagged")
        }
    }
}
