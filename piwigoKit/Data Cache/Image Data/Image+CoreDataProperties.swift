//
//  Image+CoreDataProperties.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 25/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//
//

import Foundation
import CoreData


extension Image {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Image> {
        return NSFetchRequest<Image>(entityName: "Image")
    }

    @NSManaged public var uuid: String
    @NSManaged public var pwgID: Int64
    @NSManaged public var title: NSAttributedString
    @NSManaged public var comment: NSAttributedString
    @NSManaged public var visits: Int32
    @NSManaged public var fileName: String
    @NSManaged public var datePosted: Date
    @NSManaged public var dateCreated: Date
    @NSManaged public var fullRes: Resolution?
    @NSManaged public var isVideo: Bool

    @NSManaged public var author: String
    @NSManaged public var privacyLevel: Int16
    @NSManaged public var tags: Set<Tag>?
    @NSManaged public var ratingScore: Float
    @NSManaged public var fileSize: Int64
    @NSManaged public var md5sum: String

    @NSManaged public var squareRes: Resolution?
    @NSManaged public var thumbRes: Resolution?
    @NSManaged public var mediumRes: Resolution?

    @NSManaged public var smallRes: Resolution?
    @NSManaged public var xsmallRes: Resolution?
    @NSManaged public var xxsmallRes: Resolution?

    @NSManaged public var largeRes: Resolution?
    @NSManaged public var xlargeRes: Resolution?
    @NSManaged public var xxlargeRes: Resolution?

    @NSManaged public var server: Server?
    @NSManaged public var users: Set<User>?
    @NSManaged public var albums: Set<Album>?

}

// MARK: Generated accessors for tags
extension Image {

    @objc(addTagsObject:)
    @NSManaged public func addToTags(_ value: Tag)

    @objc(removeTagsObject:)
    @NSManaged public func removeFromTags(_ value: Tag)

    @objc(addTags:)
    @NSManaged public func addToTags(_ values: Set<Tag>)

    @objc(removeTags:)
    @NSManaged public func removeFromTags(_ values: Set<Tag>)

}

// MARK: Generated accessors for users
extension Image {

    @objc(addUsersObject:)
    @NSManaged public func addToUsers(_ value: User)

    @objc(removeUsersObject:)
    @NSManaged public func removeFromUsers(_ value: User)

    @objc(addUsers:)
    @NSManaged public func addToUsers(_ values: Set<User>)

    @objc(removeUsers:)
    @NSManaged public func removeFromUsers(_ values: Set<User>)

}

// MARK: Generated accessors for albums
extension Image {

    @objc(addAlbumsObject:)
    @NSManaged public func addToAlbums(_ value: Album)

    @objc(removeAlbumsObject:)
    @NSManaged public func removeFromAlbums(_ value: Album)

    @objc(addAlbums:)
    @NSManaged public func addToAlbums(_ values: Set<Album>)

    @objc(removeAlbums:)
    @NSManaged public func removeFromAlbums(_ values: Set<Album>)

}
