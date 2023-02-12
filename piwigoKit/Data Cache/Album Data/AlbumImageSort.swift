//
//  AlbumImageSort.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 18/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - Image Sort Options
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
        
    case manual                         // Manual order
    case random                         // Random order
}

extension pwgImageSort {
    public var param: String {
        let pwgImageOrderId = "id"
        let pwgImageOrderFileName = "file"
        let pwgImageOrderName = "name"
        let pwgImageOrderVisits = "hit"
        let pwgImageOrderRating = "rating_score"
        let pwgImageOrderDateCreated = "date_creation"
        let pwgImageOrderDatePosted = "date_available"
        let pwgImageOrderRandom = "random"
        let pwgImageOrderAscending = "asc"
        let pwgImageOrderDescending = "desc"

        switch self {
        case .nameAscending:            // Photo title, A → Z
            return String(format: "%@ %@", pwgImageOrderId, pwgImageOrderAscending)
        case .nameDescending:           // Photo title, Z → A
            return String(format: "%@ %@", pwgImageOrderName, pwgImageOrderDescending)
        
        case .dateCreatedDescending:    // Date created, new → old
            return String(format: "%@ %@", pwgImageOrderDateCreated, pwgImageOrderDescending)
        case .dateCreatedAscending:     // Date created, old → new
            return String(format: "%@ %@", pwgImageOrderDateCreated, pwgImageOrderAscending)
            
        case .datePostedDescending:     // Date posted, old → new
            return String(format: "%@ %@", pwgImageOrderDatePosted, pwgImageOrderDescending)
        case .datePostedAscending:      // Date posted, new → old
            return String(format: "%@ %@", pwgImageOrderDatePosted, pwgImageOrderAscending)
            
        case .fileNameAscending:        // File name, A → Z
            return String(format: "%@ %@", pwgImageOrderFileName, pwgImageOrderAscending)
        case .fileNameDescending:       // File name, Z → A
            return String(format: "%@ %@", pwgImageOrderFileName, pwgImageOrderDescending)
            
        case .ratingScoreDescending:    // Rating score, high → low
            return String(format: "%@ %@", pwgImageOrderRating, pwgImageOrderDescending)
        case .ratingScoreAscending:     // Rating score, low → high
            return String(format: "%@ %@", pwgImageOrderRating, pwgImageOrderAscending)

        case .visitsAscending:        // Visits, high → low
            return String(format: "%@ %@", pwgImageOrderVisits, pwgImageOrderAscending)
        case .visitsDescending:       // Visits, low → high
            return String(format: "%@ %@", pwgImageOrderVisits, pwgImageOrderDescending)

        case .manual:               // Manual order
            return pwgImageOrderAscending
        case .random:               // Random order
            return pwgImageOrderRandom
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
        
        case .manual:
            return NSLocalizedString("categorySort_manual", comment: "Manual Order")
        case .random:
            return NSLocalizedString("categorySort_random", comment: "Random Order")
        }
    }
}
