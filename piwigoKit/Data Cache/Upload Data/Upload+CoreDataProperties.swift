//
//  Upload+CoreDataProperties.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 03/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import CoreData

extension Upload {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Upload> {
        return NSFetchRequest<Upload>(entityName: "Upload")
    }

    @NSManaged public var author: String
    @NSManaged public var category: Int64
    @NSManaged public var comment: String
    @NSManaged public var compressImageOnUpload: Bool
    @NSManaged public var creationDate: TimeInterval
    @NSManaged public var defaultPrefix: String
    @NSManaged public var deleteImageAfterUpload: Bool
    @NSManaged public var fileName: String
    @NSManaged public var imageId: Int64
    @NSManaged public var imageName: String
    @NSManaged public var isVideo: Bool
    @NSManaged public var localIdentifier: String
    @NSManaged public var md5Sum: String
    @NSManaged public var mimeType: String
    @NSManaged public var photoQuality: Int16
    @NSManaged public var photoMaxSize: Int16
    @NSManaged public var videoMaxSize: Int16
    @NSManaged public var prefixFileNameBeforeUpload: Bool
    @NSManaged public var privacyLevel: Int16
    @NSManaged public var requestDate: TimeInterval
    @NSManaged public var requestError: String
    @NSManaged public var requestSectionKey: String
    @NSManaged public var requestState: Int16
    @NSManaged public var resizeImageOnUpload: Bool
    @NSManaged public var stripGPSdataOnUpload: Bool
    @NSManaged public var markedForAutoUpload: Bool
    @NSManaged public var tags: Set<Tag>?
    @NSManaged public var user: User?

}

// MARK: Generated accessors for tags
extension Upload {

    @objc(addTagsObject:)
    @NSManaged public func addToTags(_ value: Tag)

    @objc(removeTagsObject:)
    @NSManaged public func removeFromTags(_ value: Tag)

    @objc(addTags:)
    @NSManaged public func addToTags(_ values: NSSet)

    @objc(removeTags:)
    @NSManaged public func removeFromTags(_ values: NSSet)

}
