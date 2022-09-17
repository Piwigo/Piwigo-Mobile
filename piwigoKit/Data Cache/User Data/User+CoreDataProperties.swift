//
//  User+CoreDataProperties.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 28/08/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//
//

import Foundation
import CoreData


extension User {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<User> {
        return NSFetchRequest<User>(entityName: "User")
    }

    @NSManaged public var name: String
    @NSManaged public var username: String
    @NSManaged public var lastUsed: Date
    @NSManaged public var server: Server?
    @NSManaged public var uploads: Set<Upload>?

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
