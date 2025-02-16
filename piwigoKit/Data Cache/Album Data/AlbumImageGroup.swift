//
//  AlbumImageGroup.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 12/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation

// Grouping options when sorting albums
public enum pwgAlbumGroup: Int16, CaseIterable {
    case none = 0
}

extension pwgAlbumGroup
{
    // See DataModel
    public var sectionKey: String {
        switch self {
        case .none:
            return "albumSection"
        }
    }
}


// Grouping options when sorting images by date
public enum pwgImageGroup: Int16, CaseIterable {
    case none = 0
    case day
    case week
    case month
}

extension pwgImageGroup
{
    // See DataModel
    public var dateCreatedSectionKey: String? {
        switch self {
        case .none:
            return nil
        case .day:
            return "sectionDayCreated"
        case .week:
            return "sectionWeekCreated"
        case .month:
            return "sectionMonthCreated"
        }
    }
    
    public var datePostedSectionKey: String? {
        switch self {
        case .none:
            return nil
        case .day:
            return "sectionDayPosted"
        case .week:
            return "sectionWeekPosted"
        case .month:
            return "sectionMonthPosted"
        }
    }
    
    public var segmentIndex: Int {
        switch self {
        case .none:
            return 3
        case .day:
            return 2
        case .week:
            return 1
        case .month:
            return 0
        }
    }
}
