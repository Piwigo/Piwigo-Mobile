//
//  AlbumImageSort.swift
//  PwgKit
//
//  Created by Eddy Lelièvre-Berna on 18/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - Image Sort Options
public enum pwgImageAttr: String, Sendable {
    case identifier = "id"
    case rank = "rank"
    case title = "name"
    case fileName = "file"
    case dateCreated = "date_creation"
    case datePosted = "date_available"
    case rating = "rating_score"
    case visits = "hit"
}

public enum pwgImageOrder: String, Sendable {
    case ascending = "asc"
    case descending = "desc"
    case random = "random"
}

public enum pwgImageSort: Int16, CaseIterable, Sendable {
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
    
    // When adopting iOS 16 as minimum target, migrate to LocalizedStringResource()
   public var name: String {
        switch self {
        case .nameAscending:
            return String(localized: "categorySort_nameAscending", bundle: .pwgKit,
                          comment: "Photo Title, A → Z")
        case .nameDescending:
            return String(localized: "categorySort_nameDescending", bundle: .pwgKit,
                          comment: "Photo Title, Z → A")
            
        case .dateCreatedDescending:
            return String(localized: "categorySort_dateCreatedDescending", bundle: .pwgKit,
                          comment: "Date Created, new → old")
        case .dateCreatedAscending:
            return String(localized: "categorySort_dateCreatedAscending", bundle: .pwgKit,
                          comment: "Date Created, old → new")
            
        case .datePostedDescending:
            return String(localized: "categorySort_datePostedDescending", bundle: .pwgKit,
                          comment: "Date Posted, new → old")
        case .datePostedAscending:
            return String(localized: "categorySort_datePostedAscending", bundle: .pwgKit,
                          comment: "Date Posted, old → new")
            
        case .fileNameAscending:
            return String(localized: "categorySort_fileNameAscending", bundle: .pwgKit,
                          comment: "File Name, A → Z")
        case .fileNameDescending:
            return String(localized: "categorySort_fileNameDescending", bundle: .pwgKit,
                          comment: "File Name, Z → A")
            
        case .ratingScoreDescending:
            return String(localized: "categorySort_ratingScoreDescending", bundle: .pwgKit,
                          comment: "Rating Score, high → low")
        case .ratingScoreAscending:
            return String(localized: "categorySort_ratingScoreAscending", bundle: .pwgKit,
                          comment: "Rating Score, low → high")
            
        case .visitsDescending:
            return String(localized: "categorySort_visitsDescending", bundle: .pwgKit,
                          comment: "Visits, high → low")
        case .visitsAscending:
            return String(localized: "categorySort_visitsAscending", bundle: .pwgKit,
                          comment: "Visits, low → high")
            
        case .rankAscending:
            return String(localized: "categorySort_manual", bundle: .pwgKit,
                          comment: "Manual Order")
        case .random:
            return String(localized: "categorySort_random", bundle: .pwgKit,
                          comment: "Random Order")
            
        case .idDescending:
            return String(localized: "categorySort_idDescending", bundle: .pwgKit,
                          comment: "Identifier, 9 → 1")
        case .idAscending:
            return String(localized: "categorySort_idAscending", bundle: .pwgKit,
                          comment: "Identifier, 1 → 9")
            
        case .albumDefault:
            return String(localized: "categorySort_default", bundle: .pwgKit,
                          comment: "Default")
        }
    }
    
    // When adopting iOS 16 as minimum target, migrate to LocalizedStringResource()
    public var shortName: String? {
        switch self {
        case .nameAscending:
            return String(localized: "categorySort_nameAscendingShort", bundle: .pwgKit,
                          comment: "A → Z")
        case .nameDescending:
            return String(localized: "categorySort_nameDescendingShort", bundle: .pwgKit,
                          comment: "Z → A")
        
        case .dateCreatedDescending:
            return String(localized: "categorySort_dateDescendingShort", bundle: .pwgKit,
                          comment: "Newest → Oldest")
        case .dateCreatedAscending:
            return String(localized: "categorySort_dateAscendingShort", bundle: .pwgKit,
                          comment: "Oldest → Newest")
        
        case .datePostedDescending:
            return String(localized: "categorySort_dateDescendingShort", bundle: .pwgKit,
                          comment: "Newest → Oldest")
        case .datePostedAscending:
            return String(localized: "categorySort_dateAscendingShort", bundle: .pwgKit,
                          comment: "Oldest → Newest")
        
        case .fileNameAscending:
            return String(localized: "categorySort_nameAscendingShort", bundle: .pwgKit,
                          comment: "A → Z")
        case .fileNameDescending:
            return String(localized: "categorySort_nameDescendingShort", bundle: .pwgKit,
                          comment: "Z → A")
        
        case .ratingScoreDescending:
            return String(localized: "categorySort_rateDescendingShort", bundle: .pwgKit,
                          comment: "Highest → Lowest")
        case .ratingScoreAscending:
            return String(localized: "categorySort_rateAscendingShort", bundle: .pwgKit,
                          comment: "Lowest → Highest")
        
        case .visitsDescending:
            return String(localized: "categorySort_visitDescendingShort", bundle: .pwgKit,
                          comment: "Highest → Lowest")
        case .visitsAscending:
            return String(localized: "categorySort_visitAscendingShort", bundle: .pwgKit,
                          comment: "Lowest → Highest")
        
        case .rankAscending:
            return nil
        case .random:
            return nil
            
        case .idDescending:
            return String(localized: "categorySort_idDescendingShort", bundle: .pwgKit,
                          comment: "9 → 1")
        case .idAscending:
            return String(localized: "categorySort_idAscendingShort", bundle: .pwgKit,
                          comment: "1 → 9")
            
        case .albumDefault:
            return nil
        }
    }
}
