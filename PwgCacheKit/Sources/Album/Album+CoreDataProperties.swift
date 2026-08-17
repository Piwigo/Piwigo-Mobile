//
//  Album+CoreDataProperties.swift
//  PwgCacheKit
//
//  Created by Eddy Lelièvre-Berna on 24/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//
//

import Foundation
import CoreData
import PwgKit

extension Album {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Album> {
        return NSFetchRequest<Album>(entityName: "Album")
    }

    @NSManaged public var uuid: String
    @NSManaged public var pwgID: Int32
    @NSManaged public var name: String
    @NSManaged public var status: Int16                     // See pwgAlbumStatus enum (.privateStatus, .publicStatus,…)
    @NSManaged public var commentRaw: String                // Potentially containing HTML encoded characters, selected language
    @NSManaged public var commentStr: String                // Potentially containing HTML encoded characters, all languages
    @NSManaged public var comment: NSAttributedString       // Plain version
    @NSManaged public var commentHTML: NSAttributedString   // HTML version
    @NSManaged public var pageUrl: NSURL?                   // Album page URL
    @NSManaged public var thumbnailId: Int64                // ID of the thumbnail
    @NSManaged public var thumbnailUrl: NSURL?              // URL of the thumbnail
    @NSManaged public var query: String

    @NSManaged public var parentId: Int32
    @NSManaged public var upperIds: String
    @NSManaged public var globalRank: String
    @NSManaged public var nbSubAlbums: Int32

    @NSManaged public var nbImages: Int64
    @NSManaged public var totalNbImages: Int64
    @NSManaged public var currentCounter: Int64
    @NSManaged public var imageSort: String
    @NSManaged public var dateGetImages: TimeInterval

    @NSManaged public var dateLast: TimeInterval
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
