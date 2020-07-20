//
//  Tag.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/01/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
//  An NSManagedObject subclass for the Tag entity.

import CoreData

// MARK: - Core Data
/**
 Managed object subclass for the Tag entity.
 */

@objc
class Tag: NSManagedObject {

    // A unique identifier for removing duplicates. Constrain
    // the Piwigo Tag entity on this attribute in the data model editor.
    @NSManaged var tagId: Int64
    
    // The other attributes of a tag.
    @NSManaged var tagName: String
    @NSManaged var lastModified: Date
    @NSManaged var numberOfImagesUnderTag : Int64

    // Singleton
    @objc static let sharedInstance: Tag = Tag()
    
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
        tagName = newName

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
