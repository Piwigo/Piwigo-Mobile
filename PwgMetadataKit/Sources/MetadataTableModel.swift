//
//  MetadataTableModel.swift
//  PwgMetadataKit
//
//  Created by Eddy Lelièvre-Berna on 30/10/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  Model of the table presenting the metadata of a photo: which sections it has, the rows of each
//  of them, their headers, and the sections which show only a few rows until the user asks for more.
//  It does not draw anything: each target renders the sections with its own cells.
//

import Foundation

/// Themes of the metadata, in the order they are presented: what the photo is about comes first, then when,
/// with which camera, where, by whom, and finally how the file is made. Each theme gathers the metadata of
/// all the directories of the file (Exif, IPTC, GPS, TIFF, PNG…) which belong to it.
public enum MetadataGroup: String, CaseIterable, Sendable {
    case description, dateTime, cameraLens, exposure, location, rights, image

    /// Title of the section
    public var title: String {
        switch self {
        case .description:  return String(localized: "imageGroup_description", bundle: .module, comment: "Description")
        case .dateTime:     return String(localized: "imageExifGroup_dateTime", bundle: .module, comment: "Date and Time")
        case .cameraLens:   return String(localized: "imageGroup_cameraLens", bundle: .module, comment: "Camera and Lens")
        case .exposure:     return String(localized: "imageExifGroup_exposure", bundle: .module, comment: "Exposure")
        case .location:     return String(localized: "imageLocation_title", bundle: .module, comment: "Location")
        case .rights:       return String(localized: "imageGroup_rights", bundle: .module, comment: "Authorship and Rights")
        case .image:        return String(localized: "imageExifGroup_image", bundle: .module, comment: "Image")
        }
    }
}

/// Metadata which a maker of cameras keeps in notes of its own, shown after the other themes
public enum MetadataMaker: String, CaseIterable, Sendable {
    case nikon, canon, apple, minolta, fuji, olympus, pentax

    /// Title of the section
    public var title: String {
        switch self {
        case .nikon:    return String(localized: "imageNikonHeader_title", bundle: .module, comment: "Nikon Camera")
        case .canon:    return String(localized: "imageCanonHeader_title", bundle: .module, comment: "Canon Camera")
        case .apple:    return String(localized: "imageAppleHeader_title", bundle: .module, comment: "Apple Camera")
        case .minolta:  return Self.cameraTitle(of: "Minolta")
        case .fuji:     return Self.cameraTitle(of: "Fuji")
        case .olympus:  return Self.cameraTitle(of: "Olympus")
        case .pentax:   return Self.cameraTitle(of: "Pentax")
        }
    }

    private static func cameraTitle(of brand: String) -> String {
        return String(format: String(localized: "imageMakerCamera_title", bundle: .module, comment: "%@ Camera"), brand)
    }
}

/// A section of the table presenting the metadata of a photo
public enum MetadataSection: Hashable, Sendable {
    case summary, location, group(MetadataGroup), maker(MetadataMaker), empty, loading

    /// A section listing the metadata of the file
    public var isList: Bool {
        switch self {
        case .summary, .location, .empty, .loading: return false
        default:                                    return true
        }
    }
}

/// Metadata of a section: at most a few rows are shown until the user asks for more
public struct MetadataList: Sendable {
    /// Number of metadata of a section shown before the user asks for more
    public static let rowsLimit = 5

    public var entries: [ImageMetadataEntry]
    public var isExpanded = false

    public init(entries: [ImageMetadataEntry] = []) {
        self.entries = entries
    }

    /// The "more" row stands for at least two entries: with one entry over the limit, it is shown instead
    public var displayedCount: Int {
        return showsMoreRow ? Self.rowsLimit : entries.count
    }

    public var showsMoreRow: Bool {
        return isExpanded == false && entries.count > Self.rowsLimit + 1
    }

    /// A section without metadata tells so in its only row
    public var rowCount: Int {
        return entries.isEmpty ? 1 : displayedCount + (showsMoreRow ? 1 : 0)
    }
}

/// Title and text of the header of a section
public struct MetadataSectionHeader: Sendable {
    public let title: String
    public let text: String
}

public struct MetadataTableModel: Sendable {
    /// Summary of the photo
    public var summary = ImageSummary()
    /// The photo has a location, which the target presents in a section of its own
    public var hasLocation = false
    /// The date and time and the description come after the metadata of the makers, instead of first
    public var movesDatesAndDescriptionToEnd = false

    /// The sections are shown once the file has been read: without metadata, they tell so
    public private(set) var isKnown = false
    private var lists = [MetadataSection: MetadataList]()

    public init() {}

    /// Directory of the file a metadata comes from
    private enum Source: String {
        case exif = "Exif", gps = "GPS", iptc = "IPTC", xmp = "XMP", webp = "WebP", tiff = "TIFF", jfif = "JFIF", png = "PNG",
             gif = "GIF", heics = "HEIC", dng = "DNG", ciff = "CIFF", tga = "TGA", photoshop = "8BIM", raw = "RAW"
    }

    /// Directories whose metadata a theme gathers, in the order they are listed
    private static let sources: [MetadataGroup: [Source]] = [
        .description: [.iptc, .exif, .tiff, .png, .xmp],
        .dateTime: [.exif, .tiff, .gps, .iptc, .xmp, .png],
        .cameraLens: [.exif],
        .exposure: [.exif],
        .location: [.gps, .iptc],
        .rights: [.exif, .iptc, .png, .xmp],
        .image: [.exif, .tiff, .jfif, .png, .gif, .heics, .dng, .ciff, .tga, .photoshop, .raw, .webp, .xmp, .iptc]
    ]

    /// Theme of a metadata: the keys which describe, date, locate or sign the photo go to the matching theme,
    /// the others describe the file
    private static func group(of source: Source, key: String, exifGroup: ImageExifGroup? = nil) -> MetadataGroup {
        switch source {
        case .exif:
            switch exifGroup {
            case .camera?:      return .cameraLens
            case .exposure?:    return .exposure
            case .dateTime?:    return .dateTime
            default:
                if ["ImageDescription", "UserComment"].contains(key) { return .description }
                if ["Artist", "Copyright"].contains(key) { return .rights }
                return .image
            }
        case .gps:
            return ["TimeStamp", "DateStamp"].contains(key) ? .dateTime : .location
        case .iptc:
            if ["ObjectName", "Headline", "Caption/Abstract", "Keywords", "StarRating", "Category",
                "SupplementalCategory", "SpecialInstructions", "Urgency"].contains(key) { return .description }
            if ["Writer/Editor", "Byline", "BylineTitle", "Credit", "Source", "CopyrightNotice", "UsageTerms",
                "Contact", "CreatorContactInfo"].contains(key) { return .rights }
            if key.hasSuffix("Date") || key.hasSuffix("Time") || key.hasSuffix("Created") { return .dateTime }
            if ["SubLocation", "City", "Province/State", "Country/PrimaryLocationName",
                "Country/PrimaryLocationCode"].contains(key) { return .location }
            return .image
        case .xmp:
            switch key {
            case "DigitalCreationDate", "ModifyDate", "DateCreated": return .dateTime
            case "WebStatement", "Marked":                      return .rights
            case "Label":                                       return .description
            default:                                            return .image
            }
        case .tiff:
            if key == "DateTime" { return .dateTime }
            return ["ImageDescription", "DocumentName"].contains(key) ? .description : .image
        case .png:
            if ["Title", "Description", "Comment"].contains(key) { return .description }
            if ["Author", "Copyright", "Disclaimer"].contains(key) { return .rights }
            if ["Creation Time", "ModificationTime"].contains(key) { return .dateTime }
            return .image
        default:
            return .image
        }
    }

    /// Metadata of the file, or nothing while they are not known
    public mutating func update(with metadata: ImageMetadata, isKnown: Bool) {
        // Gather the metadata of every directory in the theme they belong to
        var gathered = [MetadataGroup: [(source: Source, entry: ImageMetadataEntry)]]()
        func add(_ entries: [ImageMetadataEntry], from source: Source, exifGroup: ImageExifGroup? = nil) {
            for entry in entries {
                gathered[Self.group(of: source, key: entry.key, exifGroup: exifGroup), default: []]
                    .append((source, entry))
            }
        }
        for group in ImageExifGroup.allCases {
            add(metadata.exif?.groups[group] ?? [], from: .exif, exifGroup: group)
        }
        add(metadata.gps?.entries ?? [], from: .gps)
        add(metadata.iptc?.entries ?? [], from: .iptc)
        // The dates of the XMP packet are left out when the IPTC metadata, which ImageIO fills from it, already tell them
        let iptcKeys = Set((metadata.iptc?.entries ?? []).map(\.key))
        add((metadata.xmp?.entries ?? []).filter {
            let isTold = ($0.key == "DigitalCreationDate" && iptcKeys.contains("DigitalCreationDate"))
                || ($0.key == "DateCreated" && iptcKeys.contains("DateCreated"))
            return isTold == false
        }, from: .xmp)
        add(metadata.webp?.entries ?? [], from: .webp)
        var newLists = [MetadataSection: MetadataList]()
        for (kind, properties) in metadata.properties {
            let source: Source?
            switch kind {
            case .tiff:         source = .tiff
            case .jfif:         source = .jfif
            case .png:          source = .png
            case .gif:          source = .gif
            case .heics:        source = .heics
            case .dng:          source = .dng
            case .ciff:         source = .ciff
            case .tga:          source = .tga
            case .photoshop:    source = .photoshop
            case .minolta:      source = nil
            case .fuji:         source = nil
            case .olympus:      source = nil
            case .pentax:       source = nil
            case .raw:          source = .raw
            }
            if let source = source {
                add(properties.entries, from: source)
            } else if let maker = MetadataMaker(rawValue: kind.rawValue) {
                newLists[.maker(maker)] = MetadataList(entries: properties.entries)
            }
        }
        for (group, sources) in Self.sources {
            let order = Dictionary(uniqueKeysWithValues: sources.enumerated().map { ($1, $0) })
            let ordered = (gathered[group] ?? []).enumerated().sorted {
                let rank0 = order[$0.element.source] ?? Int.max, rank1 = order[$1.element.source] ?? Int.max
                return rank0 == rank1 ? $0.offset < $1.offset : rank0 < rank1
            }.map { $0.element }
            // Two directories may use the same key: the second one is named after its directory
            var keys = Set<String>()
            let entries = ordered.map { item -> ImageMetadataEntry in
                if keys.insert(item.entry.key).inserted { return item.entry }
                let key = item.source.rawValue + "." + item.entry.key
                keys.insert(key)
                return ImageMetadataEntry(key: key, name: item.entry.name, value: item.entry.value)
            }
            newLists[.group(group)] = MetadataList(entries: entries)
        }
        // The versions of the Exif and GPS tags are metadata like the others: the Exif version opens the description
        // of the file, the GPS version closes the location
        if let version = metadata.exif?.version {
            let name = String(localized: "imageExif_ExifVersion", bundle: .module, comment: "Exif Version")
            newLists[.group(.image), default: MetadataList()].entries.insert(
                ImageMetadataEntry(key: "ExifVersion", name: name, value: version), at: 0)
        }
        if let version = metadata.gps?.version {
            let name = String(localized: "imageGps_GPSVersion", bundle: .module, comment: "GPS Version")
            newLists[.group(.location), default: MetadataList()].entries.append(
                ImageMetadataEntry(key: "GPSVersion", name: name, value: version))
        }
        newLists[.maker(.nikon)] = MetadataList(entries: metadata.nikon?.entries ?? [])
        newLists[.maker(.canon)] = MetadataList(entries: metadata.canon?.entries ?? [])
        newLists[.maker(.apple)] = MetadataList(entries: metadata.apple?.entries ?? [])
        lists = newLists
        summary.exif = metadata.exif
        self.isKnown = isKnown
    }

    public func list(of section: MetadataSection) -> MetadataList {
        return lists[section] ?? MetadataList()
    }

    /// Shows all the metadata of a section, returns false if it had nothing more to show
    @discardableResult
    public mutating func expand(_ section: MetadataSection) -> Bool {
        guard var list = lists[section], list.showsMoreRow else { return false }
        list.isExpanded = true
        lists[section] = list
        return true
    }

    /// The sections shown, from the summary to the last metadata: the last one tells that the file has none
    public var sections: [MetadataSection] {
        /// A PDF has no other metadata than its summary
        if summary.source.isPDF { return [.summary] }
        var sections: [MetadataSection] = [.summary]
        if hasLocation { sections.append(.location) }
        if isKnown == false {
            /// The metadata are being read, or the file holding them is being downloaded
            sections.append(.loading)
            return sections
        }
        /// A target may show the dates and the description after the other metadata, the dates first
        let lastGroups: [MetadataGroup] = movesDatesAndDescriptionToEnd ? [.dateTime, .description] : []
        let firstGroups = MetadataGroup.allCases.filter { lastGroups.contains($0) == false }
        for group in firstGroups where list(of: .group(group)).entries.isEmpty == false {
            sections.append(.group(group))
        }
        for maker in MetadataMaker.allCases where list(of: .maker(maker)).entries.isEmpty == false {
            sections.append(.maker(maker))
        }
        for group in lastGroups where list(of: .group(group)).entries.isEmpty == false {
            sections.append(.group(group))
        }
        if sections == [.summary] { sections.append(.empty) }
        return sections
    }

    /// Title and text of the header of a section, e.g. "Image\n12 items"
    public func header(of section: MetadataSection) -> MetadataSectionHeader {
        guard section.isList else { return MetadataSectionHeader(title: "", text: "") }
        var title = ""
        switch section {
        case .group(let group):
            title = group.title
        case .maker(let maker):
            title = maker.title
        default:
            break
        }
        let text = String.localizedStringWithFormat(
            String(localized: "imageMetadata_itemCount", bundle: .module, comment: "%lld items"), list(of: section).entries.count)
        return MetadataSectionHeader(title: title + "\n", text: text)
    }
}
