//
//  Tag+CoreDataProperties.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/02/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//
//  Properties of the Tag entity.
//

import Foundation
import CoreData

extension Tag {

    public class func fetchRequest() -> NSFetchRequest<Tag> {
        return NSFetchRequest<Tag>(entityName: "Tag")
    }

    @NSManaged public var lastModified: Date
    @NSManaged public var numberOfImagesUnderTag: Int64
    @NSManaged public var tagId: Int32
    @NSManaged public var tagName: String

}
