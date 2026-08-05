//
//  User+CoreDataProperties.swift
//  PwgKit
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

    @NSManaged public var pwgID: Int16                          // Piwigo user ID
    @NSManaged public var login: String                         // Username or API public key
    @NSManaged public var username: String                      // User's account name
    @NSManaged public var name: String                          // User's name
    @NSManaged public var email: String                         // User's email
    @NSManaged public var status: String                        // See pwgUserStatus
    
    @NSManaged public var recentPeriod: Int16                   // Recent period in number of days
    @NSManaged public var registrationDate: TimeInterval        // Date of account creation
    @NSManaged public var lastUsed: TimeInterval                // Last time the account was accessed
    
    @NSManaged public var createAlbumRights: String?            // Allowed to create albums in album IDs
    @NSManaged public var uploadRights: String                  // Allowed to upload in album IDs
    @NSManaged public var downloadRights: Bool                  // Allowed to download
    
    @NSManaged public var server: Server?                       // Server of the account
    @NSManaged public var groups: Set<UserGroup>?               // Groups to which the user belongs to
    @NSManaged public var albums: Set<Album>?                   // Albums to which the user has access to
    @NSManaged public var images: Set<Image>?                   // Images to which the user has access to
    @NSManaged public var uploads: Set<Upload>?                 // Uploads requested by the user

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
