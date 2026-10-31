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

/// A section of the table presenting the metadata of a photo
public enum MetadataSection: Hashable, Sendable {
    case summary, location, exif(ImageExifGroup), gps, iptc, webp, nikon, canon, apple
    case properties(ImagePropertiesKind), empty, loading

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

    /// The sections are shown once the file has been read: without metadata, they tell so
    public private(set) var isKnown = false
    private var lists = [MetadataSection: MetadataList]()
    private var exifVersion: String?
    private var gpsVersion: String?

    public init() {}

    /// Metadata of the file, or nothing while they are not known
    public mutating func update(with metadata: ImageMetadata, isKnown: Bool) {
        var newLists = [MetadataSection: MetadataList]()
        for (kind, properties) in metadata.properties {
            newLists[.properties(kind)] = MetadataList(entries: properties.entries)
        }
        for (group, entries) in metadata.exif?.groups ?? [:] {
            newLists[.exif(group)] = MetadataList(entries: entries)
        }
        newLists[.gps] = MetadataList(entries: metadata.gps?.entries ?? [])
        newLists[.iptc] = MetadataList(entries: metadata.iptc?.entries ?? [])
        newLists[.webp] = MetadataList(entries: metadata.webp?.entries ?? [])
        newLists[.nikon] = MetadataList(entries: metadata.nikon?.entries ?? [])
        newLists[.canon] = MetadataList(entries: metadata.canon?.entries ?? [])
        newLists[.apple] = MetadataList(entries: metadata.apple?.entries ?? [])
        lists = newLists
        exifVersion = metadata.exif?.version
        gpsVersion = metadata.gps?.version
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
        for group in ImageExifGroup.allCases where list(of: .exif(group)).entries.isEmpty == false {
            sections.append(.exif(group))
        }
        let others: [MetadataSection] = [.gps, .iptc, .webp, .nikon, .canon, .apple]
        sections += others.filter { list(of: $0).entries.isEmpty == false }
        for kind in ImagePropertiesKind.allCases where list(of: .properties(kind)).entries.isEmpty == false {
            sections.append(.properties(kind))
        }
        if sections == [.summary] { sections.append(.empty) }
        return sections
    }

    /// Title and text of the header of a section, e.g. "Exif • Version 2.3 • 31 items"
    public func header(of section: MetadataSection) -> MetadataSectionHeader {
        guard section.isList else { return MetadataSectionHeader(title: "", text: "") }
        var parts = [String]()
        var version: String?
        var title = ""
        switch section {
        case .exif(let group):
            /// The groups of the Exif metadata name their content: the first one tells what they are
            title = group.title
            parts.append("Exif")
            let firstExif = sections.first(where: { if case .exif = $0 { return true } else { return false } })
            if firstExif == section {
                version = exifVersion
            }
        case .gps:
            title = "GPS"
            version = gpsVersion
        case .iptc:
            title = "IPTC"
        case .webp:
            title = "WebP"
        case .nikon:
            title = String(localized: "imageNikonHeader_title", bundle: .module, comment: "Nikon Camera")
        case .canon:
            title = String(localized: "imageCanonHeader_title", bundle: .module, comment: "Canon Camera")
        case .apple:
            title = String(localized: "imageAppleHeader_title", bundle: .module, comment: "Apple Camera")
        case .properties(let kind):
            title = kind.title
        default:
            break
        }
        if let version = version {
            parts.append(String(format: String(localized: "imageExifHeader_version", bundle: .module, comment: "Version %@"), version))
        }
        parts.append(String.localizedStringWithFormat(
            String(localized: "imageMetadata_itemCount", bundle: .module, comment: "%lld items"), list(of: section).entries.count))
        return MetadataSectionHeader(title: title + "\n", text: parts.joined(separator: " • "))
    }
}
