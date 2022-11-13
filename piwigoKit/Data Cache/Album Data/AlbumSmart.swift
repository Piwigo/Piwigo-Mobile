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

extension pwgSmartAlbum {
    public var name: String {
        switch self {
        case .root:
            return NSLocalizedString("categorySelection_root", comment: "Root Album")
        case .search:
            return ""
        case .visits:
            return NSLocalizedString("categoryDiscoverVisits_title", comment: "Most visited")
        case .best:
            return NSLocalizedString("categoryDiscoverBest_title", comment: "Best rated")
        case .recent:
            return NSLocalizedString("categoryDiscoverRecent_title", comment: "Recent photos")
        case .favorites:
            return NSLocalizedString("categoryDiscoverFavorites_title", comment: "My Favorites")
        case .tagged:
            return NSLocalizedString("categoryDiscoverTagged_title", comment: "Tagged")
        }
    }
}
