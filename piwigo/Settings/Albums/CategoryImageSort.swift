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
        
        var newImageList: [PiwigoImageData] = []
        guard let images = images else {
            return newImageList
        }
        
        switch sortOrder {
        case kPiwigoSortNameAscending:          // Photo title, A → Z
            let tempImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.fileName.localizedStandardCompare(image2.fileName) == .orderedAscending
            })
            newImageList = tempImageList.sorted(by: { (image1, image2) -> Bool in
                if let title1 = image1.imageTitle, let title2 = image2.imageTitle,
                    image1.imageTitle.count > 0, image2.imageTitle.count > 0 {
                    return title1.localizedStandardCompare(title2) == .orderedAscending
                } else {
                    return true
                }
            })
        case kPiwigoSortNameDescending:         // Photo title, Z → A
            let tempImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.fileName.localizedStandardCompare(image2.fileName) == .orderedAscending
            })
            newImageList = tempImageList.sorted(by: { (image1, image2) -> Bool in
                if let title1 = image1.imageTitle, let title2 = image2.imageTitle,
                    image1.imageTitle.count > 0, image2.imageTitle.count > 0 {
                    return title1.localizedStandardCompare(title2) == .orderedDescending
                } else {
                    return true
                }
            })
        case kPiwigoSortDateCreatedDescending:  // Date created, new → old
            newImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.dateCreated.compare(image2.dateCreated) == .orderedDescending
            })
        case kPiwigoSortDateCreatedAscending:   // Date created, old → new
            newImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.dateCreated.compare(image2.dateCreated) == .orderedAscending
            })
        case kPiwigoSortDatePostedDescending:   // Date posted, new → old
            newImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.datePosted.compare(image2.datePosted) == .orderedDescending
            })
        case kPiwigoSortDatePostedAscending:    // Date posted, old → new
            newImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.datePosted.compare(image2.datePosted) == .orderedAscending
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
            let tempImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.fileName.localizedStandardCompare(image2.fileName) == .orderedAscending
            })
            newImageList = tempImageList.sorted(by: { (image1, image2) -> Bool in
                return NSNumber(value: image1.visits).compare(NSNumber(value: image2.visits)) == .orderedDescending
            })
        case kPiwigoSortVisitsAscending:        // Visits, low → high
            let tempImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.fileName.localizedStandardCompare(image2.fileName) == .orderedAscending
            })
            newImageList = tempImageList.sorted(by: { (image1, image2) -> Bool in
                return NSNumber(value: image1.visits).compare(NSNumber(value: image2.visits)) == .orderedAscending
            })
        case kPiwigoSortRatingScoreDescending:  // Rating score, high → low
            let tempImageList = images.sorted(by: { (image1, image2) -> Bool in
                return image1.fileName.localizedStandardCompare(image2.fileName) == .orderedAscending
            })
            newImageList = tempImageList.sorted(by: { (image1, image2) -> Bool in
                return NSNumber(value: image1.ratingScore).compare(NSNumber(value: image2.ratingScore)) == .orderedDescending
            })
        case kPiwigoSortRatingScoreAscending:   // Rating score, low → high
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
