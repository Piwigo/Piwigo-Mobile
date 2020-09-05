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

@objc
class CategoryImageSort: NSObject {
    
    @objc
    class func sortImages(_ images: [PiwigoImageData]?, for sortOrder: kPiwigoSort) -> [PiwigoImageData] {
        
        // Return empty image list if images is undefined or empty
        var newImageList: [PiwigoImageData] = []
        guard let images = images else {
            return newImageList
        }
        
        switch sortOrder {
        case kPiwigoSortNameAscending:          // Photo title, A → Z
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
        case kPiwigoSortNameDescending:         // Photo title, Z → A
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
        case kPiwigoSortDateCreatedDescending:  // Date created, new → old
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
        case kPiwigoSortDateCreatedAscending:   // Date created, old → new
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
        case kPiwigoSortDatePostedDescending:   // Date posted, new → old
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
        case kPiwigoSortDatePostedAscending:    // Date posted, old → new
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
        case kPiwigoSortFileNameAscending:      // File name, A → Z
            newImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.fileName.localizedStandardCompare(image2.fileName) == .orderedAscending
            })
        case kPiwigoSortFileNameDescending:     // File name, Z → A
            newImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.fileName.localizedStandardCompare(image2.fileName) == .orderedDescending
            })
        case kPiwigoSortVisitsDescending:       // Visits, high → low
            // Pre-sort the list by filename, as the server does
            let tempImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.fileName.localizedStandardCompare(image2.fileName) == .orderedAscending
            })
            newImageList = tempImageList.sorted(by: { (image1, image2) -> Bool in
                return NSNumber(value: image1.visits).compare(NSNumber(value: image2.visits)) == .orderedDescending
            })
        case kPiwigoSortVisitsAscending:        // Visits, low → high
            // Pre-sort the list by filename, as the server does
            let tempImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.fileName.localizedStandardCompare(image2.fileName) == .orderedAscending
            })
            newImageList = tempImageList.sorted(by: { (image1, image2) -> Bool in
                return NSNumber(value: image1.visits).compare(NSNumber(value: image2.visits)) == .orderedAscending
            })
        case kPiwigoSortRatingScoreDescending:  // Rating score, high → low
            // Pre-sort the list by filename, as the server does
            let tempImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.fileName.localizedStandardCompare(image2.fileName) == .orderedAscending
            })
            newImageList = tempImageList.sorted(by: { (image1, image2) -> Bool in
                return NSNumber(value: image1.ratingScore).compare(NSNumber(value: image2.ratingScore)) == .orderedDescending
            })
        case kPiwigoSortRatingScoreAscending:   // Rating score, low → high
            // Pre-sort the list by filename, as the server does
            let tempImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.fileName.localizedStandardCompare(image2.fileName) == .orderedAscending
            })
            newImageList = tempImageList.sorted(by: { (image1, image2) -> Bool in
                return NSNumber(value: image1.ratingScore).compare(NSNumber(value: image2.ratingScore)) == .orderedAscending
            })
        case kPiwigoSortManual:                 // Manual i.e. no sort
            newImageList = images
        case kPiwigoSortCount:
            fallthrough
        default:
            break
        }

        return newImageList
    }
}
