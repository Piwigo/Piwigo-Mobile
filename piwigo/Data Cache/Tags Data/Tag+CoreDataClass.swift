//
//  Tag+CoreDataClass.swift
//  piwigo
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
    func update(with tagProperties: TagProperties) throws {
        
        // Update the tag only if the Id and Name properties have values.
        guard let newId = tagProperties.id,
              let newName = tagProperties.name else {
                throw TagError.missingData
        }
        tagId = newId
        tagName = NetworkUtilities.utf8mb4String(from: newName)

        // In the absence of date, use today
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        lastModified = dateFormatter.date(from: tagProperties.lastmodified ?? "") ?? Date()

        // In the absence of count, use max integer
        if let newCount = tagProperties.counter {
            numberOfImagesUnderTag = newCount
        } else {
            numberOfImagesUnderTag = Int64.max
        }
    }
}
