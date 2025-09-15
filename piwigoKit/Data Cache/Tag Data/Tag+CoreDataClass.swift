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

/* Tag instances represent tags of a Piwigo server.
    - Each instance belongs to a Server.
    - Instances are associated to Images and Upload requests.
 */
@objc(Tag)
public class Tag: NSManagedObject {

    /**
     Updates a Tag instance with the values from a TagProperties.
     */
    func update(with tagProperties: TagProperties, server: Server) throws {
        
        // Update the tag only if the Id and Name properties have values.
        // NB: Only the ID and the url are returned by pwg.categories.getImages
        guard let newId = tagProperties.id?.int32Value
        else { throw PwgKitError.missingTagData }
        if tagId != newId {
            tagId = newId
        }
        
        // Update name if prrovided
        if let newName = tagProperties.name, newName.isEmpty == false {
            let newTagName = newName.utf8mb4Encoded
            if tagName != newTagName {
                tagName = newTagName
            }
        }

        // Update date only if new date is after 8 January 1900 at 00:00:00 UTC
        if let newInterval = DateUtilities.timeInterval(from: tagProperties.lastmodified),
           lastModified != newInterval {
            lastModified = newInterval
        }

        // In the absence of count, use max integer
        if let newCount = tagProperties.counter, newCount != Int64.max,
           numberOfImagesUnderTag != newCount {
            numberOfImagesUnderTag = newCount
        } else if numberOfImagesUnderTag == 0  {
            numberOfImagesUnderTag = Int64.max
        }
        
        // This tag belongs to the provided server
        if self.server?.objectID != server.objectID {
            self.server = server
        }
    }
}
