//
//  VideoMetadata.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 13/01/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import AVFoundation

// MARK: Private Metadata Properties
class VideoMetadata {
    // MP4 creation date (YY-MM-DD'T'HH:mm:ss format)
    /// https://en.wikipedia.org/wiki/MP4_file_format
    fileprivate static var mp4DateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

extension Array where Element == AVMetadataItem {
    // Returns the creation date (time zone info removed to retrieve the 'local' time)
    public func creationDate() -> Date? {
        let items = AVMetadataItem.metadataItems(from: self, filteredByIdentifier: .commonIdentifierCreationDate)
        if let dateCreatedStr = items.first?.stringValue,
           let dateCreated = VideoMetadata.mp4DateFormatter.date(from: String(dateCreatedStr.prefix(19))) {
            return dateCreated
        }
        return nil
    }
    
    // Return whether metadata contains private data
    public func containsPrivateMetadata() -> Bool {
        let metadata = self as [AVMetadataItem]

        // Common Metadata Identifiers
        var locationID = AVMetadataIdentifier.commonIdentifierLocation
        var locations = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: locationID)
        if let _ = locations.first {
//            if let position = location.stringValue {
//                debugPrint("position => \(position)")
//            }
            return true
        }
        
        // iTunes Metadata Identifiers
        var userID = AVMetadataIdentifier.id3MetadataUserText
        var user = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: userID)
        if let _ = user.first { return true }
        userID = AVMetadataIdentifier.iTunesMetadataUserComment
        user = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: userID)
        if let _ = user.first { return true }
        userID = AVMetadataIdentifier.iTunesMetadataUserGenre
        user = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: userID)
        if let _ = user.first { return true }

        // ID3 Metadata Identifiers
        let commentsID = AVMetadataIdentifier.id3MetadataComments
        let comments = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: commentsID)
        if let _ = comments.first { return true }
        let ownerID = AVMetadataIdentifier.id3MetadataFileOwner
        let owner = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: ownerID)
        if let _ = owner.first { return true }
        userID = AVMetadataIdentifier.id3MetadataUserText
        user = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: userID)
        if let _ = user.first { return true }
        userID = AVMetadataIdentifier.id3MetadataUserURL
        user = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: userID)
        if let _ = user.first { return true }

        // QuickTime Metadata Identifiers
        locationID = AVMetadataIdentifier.quickTimeMetadataLocationBody
        locations = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: locationID)
        if let _ = locations.first { return true }
        locationID = AVMetadataIdentifier.quickTimeMetadataLocationISO6709
        locations = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: locationID)
        if let _ = locations.first { return true }
        locationID = AVMetadataIdentifier.quickTimeMetadataLocationName
        locations = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: locationID)
        if let _ = locations.first { return true }
        locationID = AVMetadataIdentifier.quickTimeMetadataLocationNote
        locations = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: locationID)
        if let _ = locations.first { return true }
        if #available(iOS 14.0, *) {
            locationID = AVMetadataIdentifier.quickTimeMetadataLocationHorizontalAccuracyInMeters
            locations = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: locationID)
            if let _ = locations.first { return true }
        }
        userID = AVMetadataIdentifier.quickTimeMetadataCollectionUser
        user = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: userID)
        if let _ = user.first { return true }
        userID = AVMetadataIdentifier.quickTimeMetadataComment
        user = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: userID)
        if let _ = user.first { return true }
        userID = AVMetadataIdentifier.quickTimeMetadataRatingUser
        user = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: userID)
        if let _ = user.first { return true }

        // 3GP User Metadata Identifiers
        locationID = AVMetadataIdentifier.identifier3GPUserDataLocation
        locations = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: locationID)
        if let _ = locations.first { return true }
        userID = AVMetadataIdentifier.identifier3GPUserDataUserRating
        user = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: userID)
        if let _ = user.first { return true }

        return false
    }
}

extension AVAssetTrack {
    // Return media format description
    var mediaFormat: String {
        var format = ""
        let descriptions = self.formatDescriptions as! [CMFormatDescription]
        for (index, formatDesc) in descriptions.enumerated() {
            // Get String representation of media type (vide, soun, sbtl, etc.)
            let type = CMFormatDescriptionGetMediaType(formatDesc).toString()
            // Get String representation media subtype (avc1, aac, tx3g, etc.)
            let subType = CMFormatDescriptionGetMediaSubType(formatDesc).toString()
            // Format string as type/subType
            format += "\(type)/\(subType)"
            // Comma separate if more than one format description
            if index < descriptions.count - 1 {
                format += ","
            }
        }
        return format
    }
}

extension FourCharCode {
    // Create a String representation of a FourCC
    func toString() -> String {
        let bytes: [CChar] = [
            CChar((self >> 24) & 0xff),
            CChar((self >> 16) & 0xff),
            CChar((self >> 8) & 0xff),
            CChar(self & 0xff),
            0
        ]
        let result = String(cString: bytes)
        let characterSet = CharacterSet.whitespaces
        return result.trimmingCharacters(in: characterSet)
    }
}
