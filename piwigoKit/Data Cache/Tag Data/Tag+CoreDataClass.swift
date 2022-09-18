//
//  Tag+CoreDataClass.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 22/02/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//
//  An NSManagedObject subclass for the Tag entity.
//

import Foundation
import CoreData

public class Tag: NSManagedObject {

    /**
     Updates a Tag instance with the values from a TagProperties.
     */
    func update(with tagProperties: TagProperties, server: Server) throws {
        
        // Update the tag only if the Id and Name properties have values.
        guard let newId = tagProperties.id?.value,
              let newName = tagProperties.name else {
                throw TagError.missingData
        }
        tagId = newId
        tagName = NetworkUtilities.utf8mb4String(from: newName)

        // In the absence of date, keep 1st January 1900 at 00:00:00 (see DataModel)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let newDate = dateFormatter.date(from: tagProperties.lastmodified ?? "") {
            lastModified = newDate
        }

        // In the absence of count, use max integer
        if let newCount = tagProperties.counter, newCount != Int64.max {
            numberOfImagesUnderTag = newCount
        } else if numberOfImagesUnderTag == 0  {
            numberOfImagesUnderTag = Int64.max
        }
        
        // This tag belongs to the provided server
        self.server = server
    }
}
