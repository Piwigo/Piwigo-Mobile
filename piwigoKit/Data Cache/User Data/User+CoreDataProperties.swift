//
//  User+CoreDataProperties.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 17/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//
//

import Foundation
import CoreData


extension User {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<User> {
        return NSFetchRequest<User>(entityName: "User")
    }

    @NSManaged public var id: Int16
    @NSManaged public var username: String
    @NSManaged public var email: String
    @NSManaged public var status: String
    @NSManaged public var recentPeriod: Int16
    @NSManaged public var registrationDate: TimeInterval
    @NSManaged public var lastUsed: TimeInterval
    @NSManaged public var name: String
    @NSManaged public var server: Server?
    @NSManaged public var groups: Set<UserGroup>?
    @NSManaged public var albums: Set<Album>?
    @NSManaged public var uploadRights: String
    @NSManaged public var downloadRights: Bool
    @NSManaged public var uploads: Set<Upload>?
    @NSManaged public var images: Set<Image>?

}

// MARK: Generated accessors for albums
extension User {

    @objc(addAlbumsObject:)
    @NSManaged public func addToAlbums(_ value: Album)

    @objc(removeAlbumsObject:)
    @NSManaged public func removeFromAlbums(_ value: Album)

    @objc(addAlbums:)
    @NSManaged public func addToAlbums(_ values: Set<Album>)

    @objc(removeAlbums:)
    @NSManaged public func removeFromAlbums(_ values: Set<Album>)

}

// MARK: Generated accessors for uploads
extension User {

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
extension User {

    @objc(addImagesObject:)
    @NSManaged public func addToImages(_ value: Image)

    @objc(removeImagesObject:)
    @NSManaged public func removeFromImages(_ value: Image)

    @objc(addImages:)
    @NSManaged public func addToImages(_ values: Set<Image>)

    @objc(removeImages:)
    @NSManaged public func removeFromImages(_ values: Set<Image>)

}

// MARK: Generated accessors for groups
extension User {

    @objc(addGroupsObject:)
    @NSManaged public func addToGroups(_ value: UserGroup)

    @objc(removeGroupsObject:)
    @NSManaged public func removeFromGroups(_ value: UserGroup)

    @objc(addGroups:)
    @NSManaged public func addToGroups(_ values: Set<UserGroup>)

    @objc(removeGroups:)
    @NSManaged public func removeFromGroups(_ values: Set<UserGroup>)

}
