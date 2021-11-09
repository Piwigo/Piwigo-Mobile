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
    
    @objc
    class func sortObjcImages(_ images: [PiwigoImageData]?, for sortOrder: kPiwigoSortObjc) -> [PiwigoImageData] {
        let type = kPiwigoSort(rawValue: Int16(sortOrder.rawValue))
        let newImageList = sortImages(images, for: type!)
        return newImageList
    }
    
    class func sortImages(_ images: [PiwigoImageData]?, for sortOrder: kPiwigoSort) -> [PiwigoImageData] {
        
        // Return empty image list if images is undefined or empty
        var newImageList: [PiwigoImageData] = []
        guard let images = images else {
            return newImageList
        }
        
        switch sortOrder {
        case .nameAscending:          // Photo title, A → Z
            // Pre-sort the list by filename, as the server does
            let tempImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.fileName.localizedStandardCompare(image2.fileName) == .orderedAscending
            })
            // Sort by image title
            newImageList = tempImageList.sorted(by: { (image1, image2) -> Bool in
                if let title1 = image1.imageTitle, let title2 = image2.imageTitle,
                    image1.imageTitle.count > 0, image2.imageTitle.count > 0 {
                    return title1.localizedStandardCompare(title2) == .orderedAscending
                } else {
                    return true
                }
            })
        case .nameDescending:         // Photo title, Z → A
            // Pre-sort the list by filename, as the server does
            let tempImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.fileName.localizedStandardCompare(image2.fileName) == .orderedAscending
            })
            // Sort by image title
            newImageList = tempImageList.sorted(by: { (image1, image2) -> Bool in
                if let title1 = image1.imageTitle, let title2 = image2.imageTitle,
                    image1.imageTitle.count > 0, image2.imageTitle.count > 0 {
                    return title1.localizedStandardCompare(title2) == .orderedDescending
                } else {
                    return true
                }
            })
        case .dateCreatedDescending:  // Date created, new → old
            // Pre-sort the list by filename, as the server does
            let tempImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.fileName.localizedStandardCompare(image2.fileName) == .orderedAscending
            })
            // Sort by creation date
            newImageList = tempImageList.sorted(by: { (image1, image2) -> Bool in
                if let date1 = image1.dateCreated, let date2 = image2.dateCreated {
                    return date1.compare(date2) == .orderedDescending
                } else {
                    return true
                }
            })
        case .dateCreatedAscending:   // Date created, old → new
            // Pre-sort the list by filename, as the server does
            let tempImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.fileName.localizedStandardCompare(image2.fileName) == .orderedAscending
            })
            // Sort by creation date
            newImageList = tempImageList.sorted(by: { (image1, image2) -> Bool in
                if let date1 = image1.dateCreated, let date2 = image2.dateCreated {
                    return date1.compare(date2) == .orderedAscending
                } else {
                    return true
                }
            })
        case .datePostedDescending:   // Date posted, new → old
            // Pre-sort the list by filename, as the server does
            let tempImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.fileName.localizedStandardCompare(image2.fileName) == .orderedAscending
            })
            // Sort by posted date
            newImageList = tempImageList.sorted(by: { (image1, image2) -> Bool in
                if let date1 = image1.datePosted, let date2 = image2.datePosted {
                    return date1.compare(date2) == .orderedDescending
                } else {
                    return true
                }
            })
        case .datePostedAscending:    // Date posted, old → new
            // Pre-sort the list by filename, as the server does
            let tempImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.fileName.localizedStandardCompare(image2.fileName) == .orderedAscending
            })
            // Sort by posted date
            newImageList = tempImageList.sorted(by: { (image1, image2) -> Bool in
                if let date1 = image1.datePosted, let date2 = image2.datePosted {
                    return date1.compare(date2) == .orderedAscending
                } else {
                    return true
                }
            })
        case .fileNameAscending:      // File name, A → Z
            newImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.fileName.localizedStandardCompare(image2.fileName) == .orderedAscending
            })
        case .fileNameDescending:     // File name, Z → A
            newImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.fileName.localizedStandardCompare(image2.fileName) == .orderedDescending
            })
        case .visitsDescending:       // Visits, high → low
            // Pre-sort the list by filename, as the server does
            let tempImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.fileName.localizedStandardCompare(image2.fileName) == .orderedAscending
            })
            newImageList = tempImageList.sorted(by: { (image1, image2) -> Bool in
                return NSNumber(value: image1.visits).compare(NSNumber(value: image2.visits)) == .orderedDescending
            })
        case .visitsAscending:        // Visits, low → high
            // Pre-sort the list by filename, as the server does
            let tempImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.fileName.localizedStandardCompare(image2.fileName) == .orderedAscending
            })
            newImageList = tempImageList.sorted(by: { (image1, image2) -> Bool in
                return NSNumber(value: image1.visits).compare(NSNumber(value: image2.visits)) == .orderedAscending
            })
        case .ratingScoreDescending:  // Rating score, high → low
            // Pre-sort the list by filename, as the server does
            let tempImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.fileName.localizedStandardCompare(image2.fileName) == .orderedAscending
            })
            newImageList = tempImageList.sorted(by: { (image1, image2) -> Bool in
                return NSNumber(value: image1.ratingScore).compare(NSNumber(value: image2.ratingScore)) == .orderedDescending
            })
        case .ratingScoreAscending:   // Rating score, low → high
            // Pre-sort the list by filename, as the server does
            let tempImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.fileName.localizedStandardCompare(image2.fileName) == .orderedAscending
            })
            newImageList = tempImageList.sorted(by: { (image1, image2) -> Bool in
                return NSNumber(value: image1.ratingScore).compare(NSNumber(value: image2.ratingScore)) == .orderedAscending
            })
        case .manual:                 // Manual i.e. no sort
            newImageList = images
        case .random:                 // Random order
            newImageList = images.shuffled()
        case .count:
            fallthrough
        default:
            break
        }

        return newImageList
    }
}
