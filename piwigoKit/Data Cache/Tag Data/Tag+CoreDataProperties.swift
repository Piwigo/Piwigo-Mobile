//
//  Tag+CoreDataProperties.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 22/02/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import CoreData

extension Tag {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Tag> {
        return NSFetchRequest<Tag>(entityName: "Tag")
    }

    @NSManaged public var lastModified: Date
    @NSManaged public var numberOfImagesUnderTag: Int64
    @NSManaged public var tagId: Int32
    @NSManaged public var tagName: String
    @NSManaged public var server: Server?
    @NSManaged public var uploads: Set<Upload>?
    @NSManaged public var images: Set<Image>?

}

// MARK: Generated accessors for uploads
extension Tag {

    @objc(addUploadsObject:)
    @NSManaged public func addToUploads(_ value: Upload)

    @objc(removeUploadsObject:)
    @NSManaged public func removeFromUploads(_ value: Upload)

    @objc(addUploads:)
    @NSManaged public func addToUploads(_ values: Set<Upload>)

    @objc(removeUploads:)
    @NSManaged public func removeFromUploads(_ values: Set<Upload>)

}

// MARK: Generated accessors for images
extension Tag {

    @objc(addImagesObject:)
    @NSManaged public func addToImages(_ value: Image)

    @objc(removeImagesObject:)
    @NSManaged public func removeFromImages(_ value: Image)

    @objc(addImages:)
    @NSManaged public func addToImages(_ values: Set<Image>)

    @objc(removeImages:)
    @NSManaged public func removeFromImages(_ values: Set<Image>)

}

extension Array where Element == Tag {
    public func filterTags(for query: String) -> [Tag] {
        // Return whole list if query is empty
        if query.isEmpty { return self }
        
        // Return filtered list
        return self.filter { $0.tagName.lowercased().contains(query.lowercased())}
    }
}
