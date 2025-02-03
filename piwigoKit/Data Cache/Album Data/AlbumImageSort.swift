//
//  AlbumImageSort.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 18/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - Image Sort Options
public enum pwgImageAttr: String {
    case identifier = "id"
    case rank = "rank"
    case title = "name"
    case fileName = "file"
    case dateCreated = "date_creation"
    case datePosted = "date_available"
    case rating = "rating_score"
    case visits = "hit"
}

public enum pwgImageOrder: String {
    case ascending = "asc"
    case descending = "desc"
    case random = "random"
}

public enum pwgImageSort: Int16, CaseIterable {
    case nameAscending = 0              // Photo title, A → Z
    case nameDescending                 // Photo title, Z → A
            
    case dateCreatedDescending          // Date created, new → old
    case dateCreatedAscending           // Date created, old → new
            
    case datePostedDescending           // Date posted, new → old
    case datePostedAscending            // Date posted, old → new
            
    case fileNameAscending              // File name, A → Z
    case fileNameDescending             // File name, Z → A
            
    case ratingScoreDescending          // Rating score, high → low
    case ratingScoreAscending           // Rating score, low → high
        
    case visitsDescending               // Visits, high → low
    case visitsAscending                // Visits, low → high
        
    case rankAscending                  // Manual order
    case random                         // Random order
    
    case idAscending                    // Identifier, 1 → 9
    case idDescending                   // Identifier, 9 → 1
    
    case albumDefault                   // Returned by Piwigo 14+
}

extension pwgImageSort {
    public var param: String {
        switch self {
        case .nameAscending:            // Photo title, A → Z
            return String(format: "%@ %@, %@ %@, %@ %@",
                          pwgImageAttr.title.rawValue, pwgImageOrder.ascending.rawValue,
                          pwgImageAttr.dateCreated.rawValue, pwgImageOrder.ascending.rawValue,
                          pwgImageAttr.identifier.rawValue, pwgImageOrder.descending.rawValue)
        case .nameDescending:           // Photo title, Z → A
            return String(format: "%@ %@, %@ %@, %@ %@",
                          pwgImageAttr.title.rawValue, pwgImageOrder.descending.rawValue,
                          pwgImageAttr.dateCreated.rawValue, pwgImageOrder.ascending.rawValue,
                          pwgImageAttr.identifier.rawValue, pwgImageOrder.ascending.rawValue)
        
        case .dateCreatedDescending:    // Date created, new → old
            return String(format: "%@ %@, %@ %@, %@ %@", 
                          pwgImageAttr.dateCreated.rawValue, pwgImageOrder.descending.rawValue,
                          pwgImageAttr.fileName.rawValue, pwgImageOrder.ascending.rawValue,
                          pwgImageAttr.identifier.rawValue, pwgImageOrder.descending.rawValue)
        case .dateCreatedAscending:     // Date created, old → new
            return String(format: "%@ %@, %@ %@, %@ %@", 
                          pwgImageAttr.dateCreated.rawValue, pwgImageOrder.ascending.rawValue,
                          pwgImageAttr.fileName.rawValue, pwgImageOrder.ascending.rawValue,
                          pwgImageAttr.identifier.rawValue, pwgImageOrder.ascending.rawValue)

        case .datePostedDescending:     // Date posted, old → new
            return String(format: "%@ %@, %@ %@, %@ %@", 
                          pwgImageAttr.datePosted.rawValue, pwgImageOrder.descending.rawValue,
                          pwgImageAttr.fileName.rawValue, pwgImageOrder.ascending.rawValue,
                          pwgImageAttr.identifier.rawValue, pwgImageOrder.ascending.rawValue)
        case .datePostedAscending:      // Date posted, new → old
            return String(format: "%@ %@, %@ %@, %@ %@", 
                          pwgImageAttr.datePosted.rawValue, pwgImageOrder.ascending.rawValue,
                          pwgImageAttr.fileName.rawValue, pwgImageOrder.ascending.rawValue,
                          pwgImageAttr.identifier.rawValue, pwgImageOrder.descending.rawValue)

        case .fileNameAscending:        // File name, A → Z
            return String(format: "%@ %@, %@ %@",
                          pwgImageAttr.fileName.rawValue, pwgImageOrder.ascending.rawValue,
                          pwgImageAttr.identifier.rawValue, pwgImageOrder.ascending.rawValue)
        case .fileNameDescending:       // File name, Z → A
            return String(format: "%@ %@, %@ %@",
                          pwgImageAttr.fileName.rawValue, pwgImageOrder.descending.rawValue,
                          pwgImageAttr.identifier.rawValue, pwgImageOrder.descending.rawValue)
            
        case .ratingScoreDescending:    // Rating score, high → low
            return String(format: "%@ %@, %@ %@", 
                          pwgImageAttr.rating.rawValue, pwgImageOrder.descending.rawValue,
                          pwgImageAttr.dateCreated.rawValue, pwgImageOrder.ascending.rawValue)
        case .ratingScoreAscending:     // Rating score, low → high
            return String(format: "%@ %@, %@ %@", 
                          pwgImageAttr.rating.rawValue, pwgImageOrder.ascending.rawValue,
                          pwgImageAttr.dateCreated.rawValue, pwgImageOrder.ascending.rawValue)

        case .visitsAscending:          // Visits, low → high
            return String(format: "%@ %@, %@ %@, %@ %@",
                          pwgImageAttr.visits.rawValue, pwgImageOrder.ascending.rawValue,
                          pwgImageAttr.dateCreated.rawValue, pwgImageOrder.ascending.rawValue,
                          pwgImageAttr.fileName.rawValue, pwgImageOrder.ascending.rawValue)
        case .visitsDescending:         // Visits, high → low
            return String(format: "%@ %@, %@ %@, %@ %@",
                          pwgImageAttr.visits.rawValue, pwgImageOrder.descending.rawValue,
                          pwgImageAttr.dateCreated.rawValue, pwgImageOrder.ascending.rawValue,
                          pwgImageAttr.fileName.rawValue, pwgImageOrder.ascending.rawValue)

        case .rankAscending:            // Manual order
            return String(format: "%@ %@", pwgImageAttr.rank.rawValue, pwgImageOrder.ascending.rawValue)
        case .random:               // Random order
            return pwgImageOrder.random.rawValue

        case .idAscending:              // Identifier, 1 → 9
            return String(format: "%@ %@", pwgImageAttr.identifier.rawValue, pwgImageOrder.ascending.rawValue)
        case .idDescending:             // Identifier, 9 → 1
            return String(format: "%@ %@", pwgImageAttr.identifier.rawValue, pwgImageOrder.descending.rawValue)
            
        case .albumDefault:             // Use album.imageSort attribute
            return ""
        }
    }
    
    public var name: String {
        switch self {
        case .nameAscending:
            return NSLocalizedString("categorySort_nameAscending", comment: "Photo Title, A → Z")
        case .nameDescending:
            return NSLocalizedString("categorySort_nameDescending", comment: "Photo Title, Z → A")
        
        case .dateCreatedDescending:
            return NSLocalizedString("categorySort_dateCreatedDescending", comment: "Date Created, new → old")
        case .dateCreatedAscending:
            return NSLocalizedString("categorySort_dateCreatedAscending", comment: "Date Created, old → new")
        
        case .datePostedDescending:
            return NSLocalizedString("categorySort_datePostedDescending", comment: "Date Posted, new → old")
        case .datePostedAscending:
            return NSLocalizedString("categorySort_datePostedAscending", comment: "Date Posted, old → new")
        
        case .fileNameAscending:
            return NSLocalizedString("categorySort_fileNameAscending", comment: "File Name, A → Z")
        case .fileNameDescending:
            return NSLocalizedString("categorySort_fileNameDescending", comment: "File Name, Z → A")
        
        case .ratingScoreDescending:
            return NSLocalizedString("categorySort_ratingScoreDescending", comment: "Rating Score, high → low")
        case .ratingScoreAscending:
            return NSLocalizedString("categorySort_ratingScoreAscending", comment: "Rating Score, low → high")
        
        case .visitsDescending:
            return NSLocalizedString("categorySort_visitsDescending", comment: "Visits, high → low")
        case .visitsAscending:
            return NSLocalizedString("categorySort_visitsAscending", comment: "Visits, low → high")
        
        case .rankAscending:
            return NSLocalizedString("categorySort_manual", comment: "Manual Order")
        case .random:
            return NSLocalizedString("categorySort_random", comment: "Random Order")
            
        case .idDescending:
            return NSLocalizedString("categorySort_idDescending", comment: "Identifier, 9 → 1")
        case .idAscending:
            return NSLocalizedString("categorySort_idAscending", comment: "Identifier, 1 → 9")
            
        case .albumDefault:
            return NSLocalizedString("categorySort_default", comment: "Default")
        }
    }
}
