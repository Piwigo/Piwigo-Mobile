//
//  Album+CoreDataProperties.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 24/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//
//

import Foundation
import CoreData


extension Album {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Album> {
        return NSFetchRequest<Album>(entityName: "Album")
    }

    @NSManaged public var uuid: String
    @NSManaged public var pwgID: Int32
    @NSManaged public var comment: NSAttributedString
    @NSManaged public var commentStr: String
    @NSManaged public var commentHTML: NSAttributedString
    @NSManaged public var currentCounter: Int64
    @NSManaged public var dateLast: TimeInterval
    @NSManaged public var dateGetImages: TimeInterval
    @NSManaged public var globalRank: String
    @NSManaged public var name: String
    @NSManaged public var imageSort: String
    @NSManaged public var nbImages: Int64
    @NSManaged public var nbSubAlbums: Int32
    @NSManaged public var parentId: Int32
    @NSManaged public var query: String
    @NSManaged public var thumbnailId: Int64
    @NSManaged public var thumbnailUrl: NSURL?
    @NSManaged public var totalNbImages: Int64
    @NSManaged public var upperIds: String
    @NSManaged public var server: Server?
    @NSManaged public var user: User?
    @NSManaged public var images: Set<Image>?

    @objc var albumSection: String? {
        /* Used to name the album section */
        return pwgAlbumGroup.none.sectionKey
    }
}

// MARK: Generated accessors for images
extension Album {

    @objc(addImagesObject:)
    @NSManaged public func addToImages(_ value: Image)

    @objc(removeImagesObject:)
    @NSManaged public func removeFromImages(_ value: Image)

    @objc(addImages:)
    @NSManaged public func addToImages(_ values: Set<Image>)

    @objc(removeImages:)
    @NSManaged public func removeFromImages(_ values: Set<Image>)

}
