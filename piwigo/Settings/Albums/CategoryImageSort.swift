//
//  CategoryImageSort.swift
//  piwigo
//
//  Created by Spencer Baker on 3/3/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5 by Eddy Lelièvre-Berna on 28/06/2020.
//

import Foundation
import piwigoKit

@objc
class CategoryImageSort: NSObject {
    
    @objc
    class func getPiwigoSortObjcDescription(for typeObjc:kPiwigoSortObjc) -> String {
        let type = kPiwigoSort(rawValue: Int16(typeObjc.rawValue))
        let sortDesc = getPiwigoSortDescription(for: type!)
        return sortDesc
    }

    class func getPiwigoSortDescription(for type:kPiwigoSort) -> String {
        var sortDesc = ""
        switch type {
        case .nameAscending:          // Photo title, A → Z
            sortDesc = String(format: "%@ %@", kGetImageOrderName, kGetImageOrderAscending)
        case .nameDescending:         // Photo title, Z → A
            sortDesc = String(format: "%@ %@", kGetImageOrderName, kGetImageOrderDescending)

        case .fileNameAscending:      // File name, A → Z
            sortDesc = String(format: "%@ %@", kGetImageOrderFileName, kGetImageOrderAscending)
        case .fileNameDescending:     // File name, Z → A
            sortDesc = String(format: "%@ %@", kGetImageOrderFileName, kGetImageOrderDescending)
        
        case .dateCreatedAscending:   // Date created, old → new
            sortDesc = String(format: "%@ %@", kGetImageOrderDateCreated, kGetImageOrderAscending)
        case .dateCreatedDescending:  // Date created, new → old
            sortDesc = String(format: "%@ %@", kGetImageOrderDateCreated, kGetImageOrderDescending)
            
        case .datePostedAscending:    // Date posted, new → old
            sortDesc = String(format: "%@ %@", kGetImageOrderDatePosted, kGetImageOrderAscending)
        case .datePostedDescending:   // Date posted, old → new
            sortDesc = String(format: "%@ %@", kGetImageOrderDatePosted, kGetImageOrderDescending)

        case .ratingScoreDescending:  // Rating score, high → low
            sortDesc = String(format: "%@ %@", kGetImageOrderRating, kGetImageOrderDescending)
        case .ratingScoreAscending:   // Rating score, low → high
            sortDesc = String(format: "%@ %@", kGetImageOrderRating, kGetImageOrderAscending)

        case .visitsAscending:        // Visits, high → low
            sortDesc = String(format: "%@ %@", kGetImageOrderVisits, kGetImageOrderAscending)
        case .visitsDescending:       // Visits, low → high
            sortDesc = String(format: "%@ %@", kGetImageOrderVisits, kGetImageOrderDescending)
            
        case .random:                 // Random order
            sortDesc = kGetImageOrderRandom
            
        case .manual,                 // Manual order
             .count:
            fallthrough
        default:
            sortDesc = ""
        }
        return sortDesc
    }
}
