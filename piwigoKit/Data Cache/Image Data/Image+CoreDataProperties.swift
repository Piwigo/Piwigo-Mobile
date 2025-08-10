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
    @NSManaged public var titleStr: String
    @NSManaged public var comment: NSAttributedString
    @NSManaged public var commentStr: String
    @NSManaged public var commentHTML: NSAttributedString
    @NSManaged public var visits: Int32
    @NSManaged public var fileName: String
    @NSManaged public var fileType: Int16
    @NSManaged public var datePosted: TimeInterval
    @NSManaged public var dateCreated: TimeInterval
    @NSManaged public var dateGetInfos: TimeInterval
    @NSManaged public var fullRes: Resolution?
    @NSManaged public var downloadUrl: NSURL?
    
    @NSManaged public var author: String
    @NSManaged public var privacyLevel: Int16
    @NSManaged public var tags: Set<Tag>?
    @NSManaged public var ratingScore: Float
    @NSManaged public var fileSize: Int64
    @NSManaged public var md5sum: String
    
    @NSManaged public var rankManual: Int64
    @NSManaged public var rankRandom: Int64
    
    @NSManaged public var sizes: Sizes
    @NSManaged public var server: Server?
    @NSManaged public var users: Set<User>?
    @NSManaged public var albums: Set<Album>?
    
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    
    static let calendar = Calendar.current
    static let byDay: Set<Calendar.Component> = [.year, .month, .day]
    static let byWeek: Set<Calendar.Component> = [.year, .weekOfYear]
    static let byMonth: Set<Calendar.Component> = [.year, .month]

    @objc var sectionDayCreated: String? {
        /* Sections are ogranised by day. The section identifier is a string representing
         the number (year * 100000) + (month * 1000) + day so it will be ordered chronologically
         regardless of the actual day/month/year */
        let dateCreated = Date(timeIntervalSinceReferenceDate: self.dateCreated)
        let dayComponents = Image.calendar.dateComponents(Image.byDay, from: dateCreated)
        var dayIdentifier: Int = (dayComponents.year ?? 0) * 100000
        dayIdentifier += (dayComponents.month ?? 0) * 1000
        dayIdentifier += (dayComponents.day ?? 0)
        return String(format: "%d", dayIdentifier)
    }
    
    @objc var sectionWeekCreated: String? {
        /* Sections are ogranised by week. The section identifier is a string representing
         the number (year * 100) + weekOfYear so it will be ordered chronologically
         regardless of the actual day/month/year */
        let dateCreated = Date(timeIntervalSinceReferenceDate: self.dateCreated)
        let weekComponents = Image.calendar.dateComponents(Image.byWeek, from: dateCreated)
        var weekIdentifier: Int = (weekComponents.year ?? 0) * 100
        weekIdentifier += (weekComponents.weekOfYear ?? 0)
        return String(format: "%d", weekIdentifier)
    }
    
    @objc var sectionMonthCreated: String? {
        /* Sections are ogranised by month. The section identifier is a string representing
         the number (year * 100) + month so it will be ordered chronologically
         regardless of the actual day/month/year */
        let dateCreated = Date(timeIntervalSinceReferenceDate: self.dateCreated)
        let monthComponents = Image.calendar.dateComponents(Image.byMonth, from: dateCreated)
        var monthIdentifier: Int = (monthComponents.year ?? 0) * 100
        monthIdentifier += (monthComponents.month ?? 0)
        return String(format: "%d", monthIdentifier)
    }
    
    @objc var sectionDayPosted: String? {
        /* Sections are ogranised by day. The section identifier is a string representing
         the number (year * 100000) + (month * 1000) + day so it will be ordered chronologically
         regardless of the actual day/month/year */
        let datePosted = Date(timeIntervalSinceReferenceDate: self.datePosted)
        let dayComponents = Image.calendar.dateComponents(Image.byDay, from: datePosted)
        var dayIdentifier: Int = (dayComponents.year ?? 0) * 100000
        dayIdentifier += (dayComponents.month ?? 0) * 1000
        dayIdentifier += (dayComponents.day ?? 0)
        return String(format: "%d", dayIdentifier)
    }
    
    @objc var sectionWeekPosted: String? {
        /* Sections are ogranised by week. The section identifier is a string representing
         the number (year * 100) + weekOfYear so it will be ordered chronologically
         regardless of the actual day/month/year */
        let datePosted = Date(timeIntervalSinceReferenceDate: self.datePosted)
        let weekComponents = Image.calendar.dateComponents(Image.byWeek, from: datePosted)
        var weekIdentifier: Int = (weekComponents.year ?? 0) * 100
        weekIdentifier += (weekComponents.weekOfYear ?? 0)
        return String(format: "%d", weekIdentifier)
    }
    
    @objc var sectionMonthPosted: String? {
        /* Sections are ogranised by month. The section identifier is a string representing
           the number (year * 100) + month so it will be ordered chronologically
           regardless of the actual day/month/year */
        let datePosted = Date(timeIntervalSinceReferenceDate: self.datePosted)
        let monthComponents = Image.calendar.dateComponents(Image.byMonth, from: datePosted)
        var monthIdentifier: Int = (monthComponents.year ?? 0) * 100
        monthIdentifier += (monthComponents.month ?? 0)
        return String(format: "%d", monthIdentifier)
    }
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
