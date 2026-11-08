//
//  ImageXmp.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 08/11/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  XMP metadata of an image file which the IPTC directory of ImageIO does not give: ImageIO reconciles the
//  XMP packet with the IPTC data, so that the title, caption, keywords, rating, creators, rights, contact
//  details, place names and credits are already read with the IPTC metadata, whichever of the two holds them.
//  What remains is read here: the dates of the packet (its creation date is the digital creation date of IPTC), the tool which created the file, the label,
//  and the web page and mark of the rights.
//

import Foundation
import ImageIO

public struct ImageXmp: Sendable {
    /// Entries in the order of their keys
    public let entries: [ImageMetadataEntry]
}

enum ImageXmpReader
{
    // MARK: - Cache
    private static let cache = ImageMetadataCache<ImageXmp>()

    /// Returns the XMP data of a file already read, without reading it again
    static func cachedXmp(at url: URL) -> ImageXmp?? {
        return cache.cachedValue(at: url)
    }


    // MARK: - Reading
    /// Reads the XMP data of an image file. Returns nil if the file has none.
    static func read(from url: URL) -> ImageXmp? {
        if let cached = cachedXmp(at: url) { return cached }
        let xmp = readFile(at: url)
        cache.store(xmp, at: url)
        return xmp
    }

    /// Keys, in the order they are presented, with the path of their property in the XMP packet
    private static let paths: [(key: String, path: String)] = [
        ("DigitalCreationDate", "xmp:CreateDate"), ("ModifyDate", "xmp:ModifyDate"), ("DateCreated", "photoshop:DateCreated"),
        ("CreatorTool", "xmp:CreatorTool"), ("Label", "xmp:Label"),
        ("WebStatement", "xmpRights:WebStatement"), ("Marked", "xmpRights:Marked")
    ]

    private static func readFile(at url: URL) -> ImageXmp? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options),
              let metadata = CGImageSourceCopyMetadataAtIndex(source, 0, options)
        else { return nil }

        var entries = [ImageMetadataEntry]()
        for (key, path) in paths {
            guard let value = CGImageMetadataCopyStringValueWithPath(metadata, nil, path as CFString) as String?,
                  let text = formattedValue(of: value, forKey: key), text.isEmpty == false
            else { continue }
            entries.append(ImageMetadataEntry(key: key, name: naturalName(ofKey: key), value: text))
        }
        return entries.isEmpty ? nil : ImageXmp(entries: entries)
    }


    // MARK: - Names
    /// Natural name of an XMP key: translated if known, otherwise the key split into words
    static func naturalName(ofKey key: String) -> String {
        return ImageMetadataFormatter.naturalName(ofKey: key, prefixes: ["imageXmp_", "imageIptc_"])
    }


    // MARK: - Values
    /// Text presenting the value of an XMP key
    static func formattedValue(of value: String, forKey key: String) -> String? {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch key {
        case "DigitalCreationDate", "ModifyDate", "DateCreated":
            return formattedDate(text) ?? text
        case "Marked":
            /// A boolean, written "True" or "False"
            switch text.lowercased() {
            case "true":    return String(localized: "imageAppleStable_1", bundle: .module, comment: "Yes")
            case "false":   return String(localized: "imageAppleStable_0", bundle: .module, comment: "No")
            default:        return text
            }
        default:
            return text
        }
    }

    /// Dates are written "2024-01-05T12:34:56+01:00", the time, its seconds and its offset being optional:
    /// the date and the time are shown as they are written, followed by the offset ("Z" being UTC)
    static func formattedDate(_ text: String) -> String? {
        guard let match = datePattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        func group(_ index: Int) -> String? {
            return Range(match.range(at: index), in: text).map { String(text[$0]) }
        }
        let day = String(text[range])
        guard let date = dayFormatter.date(from: day) else { return nil }
        guard let time = group(2) else { return displayDay.string(from: date) }
        var result = displayDay.string(from: date) + " " + time.dropFirst().prefix(8)
        if let offset = group(3) {
            result += " " + (offset == "Z" ? "UTC" : offset)
        }
        return result
    }

    /// 1: the day, 2: the time with its "T", 3: the offset
    private static let datePattern = try! NSRegularExpression(
        pattern: #"^(\d{4}-\d{2}-\d{2})(T\d{2}:\d{2}(?::\d{2})?)?(?:\.\d+)?(Z|[+-]\d{2}:\d{2})?$"#)

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let displayDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
