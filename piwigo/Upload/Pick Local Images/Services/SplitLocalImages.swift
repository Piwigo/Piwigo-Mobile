//
//  SplitLocalImages.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/03/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5.1 by Eddy Lelièvre-Berna on 15/04/2020
//

import Foundation
import Photos

class SplitLocalImages: NSObject {
    
    @objc
    class func splitImages(byDate images: PHFetchResult<PHAsset>?) -> [[PHAsset]]? {
        
        // NOP if no image
        guard let images = images else {
            return []
        }
        
        var imagesByDate: [[PHAsset]] = []

        // Initialise loop conditions
        let calendar = Calendar.current
        var currentDateComponents: DateComponents? = nil
        if let creation = images.firstObject?.creationDate {
            currentDateComponents = calendar.dateComponents([.year, .month, .day], from: creation)
        }
        var currentDate: Date? = nil
        if let currentDateComponents = currentDateComponents {
            currentDate = calendar.date(from: currentDateComponents)
        }
        var imagesOfSameDate: [PHAsset] = []

        // Sort imageAssets
        images.enumerateObjects({ obj, idx, stop in

            // Get current image creation date
            var dateComponents: DateComponents? = nil
            if let creation = obj.creationDate {
                dateComponents = calendar.dateComponents([.year, .month, .day], from: creation)
            }
            var date: Date? = nil
            if let dateComponents = dateComponents {
                date = calendar.date(from: dateComponents)
            }

            // Image taken at same date?
            var result: ComparisonResult? = nil
            if let currentDate = currentDate {
                result = date?.compare(currentDate)
            }
            if result == .orderedSame {
                // Same date -> Append object to section
                imagesOfSameDate.append(obj)
            } else {
                // Append section to collection
                imagesByDate.append(imagesOfSameDate)

                // Initialise for next items
                imagesOfSameDate.removeAll()
                if let creation = obj.creationDate {
                    currentDateComponents = calendar.dateComponents([.year, .month, .day], from: creation)
                }
                if let currentDateComponents = currentDateComponents {
                    currentDate = calendar.date(from: currentDateComponents)
                }

                // Add current item
                imagesOfSameDate.append(obj)
            }
        })

        // Append last section to collection
        imagesByDate.append(imagesOfSameDate)

        return imagesByDate
    }
}
