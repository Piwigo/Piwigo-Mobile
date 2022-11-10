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
    @NSManaged public var dateLast: Date
    @NSManaged public var globalRank: String
    @NSManaged public var name: String
    @NSManaged public var nbImages: Int64
    @NSManaged public var nbSubAlbums: Int32
    @NSManaged public var parentId: Int32
    @NSManaged public var query: String
    @NSManaged public var thumbnailId: Int32
    @NSManaged public var thumbnailUrl: NSURL?
    @NSManaged public var totalNbImages: Int64
    @NSManaged public var upperIds: String
    @NSManaged public var server: Server?
    @NSManaged public var users: Set<User>?
    @NSManaged public var images: Set<Image>?

}

// MARK: Generated accessors for users
extension Album {

    @objc(addUsersObject:)
    @NSManaged public func addToUsers(_ value: User)

    @objc(removeUsersObject:)
    @NSManaged public func removeFromUsers(_ value: User)

    @objc(addUsers:)
    @NSManaged public func addToUsers(_ values: Set<User>)

    @objc(removeUsers:)
    @NSManaged public func removeFromUsers(_ values: Set<User>)

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
