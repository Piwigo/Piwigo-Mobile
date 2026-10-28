//
//  ImageIptc.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 29/10/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  IPTC metadata of an image file, as presented by the table of the metadata:
//  one entry per IPTC key, with the natural name of the key and a readable value.
//

import Foundation
import ImageIO

struct ImageIptc: Sendable {
    /// Entries sorted alphabetically by natural name
    let entries: [ImageMetadataEntry]
}

enum ImageIptcReader
{
    // MARK: - Cache
    private static let cache = ImageMetadataCache<ImageIptc>()

    /// Returns the IPTC data of a file already read, without reading it again
    static func cachedIptc(at url: URL) -> ImageIptc?? {
        return cache.cachedValue(at: url)
    }


    // MARK: - Reading
    /// Reads the IPTC data of an image file. Returns nil if the file has none.
    static func read(from url: URL) -> ImageIptc? {
        if let cached = cachedIptc(at: url) { return cached }
        let iptc = readFile(at: url)
        cache.store(iptc, at: url)
        return iptc
    }

    private static func readFile(at url: URL) -> ImageIptc? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [String: Any],
              let values = properties[kCGImagePropertyIPTCDictionary as String] as? [String: Any]
        else { return nil }

        // Entries sorted by natural name
        var entries = [ImageMetadataEntry]()
        for (key, value) in values {
            guard let text = formattedValue(of: value, forKey: key), text.isEmpty == false else { continue }
            entries.append(ImageMetadataEntry(key: key, name: naturalName(ofKey: key), value: text))
        }
        return entries.isEmpty ? nil : ImageIptc(entries: entries.sortedByName())
    }


    // MARK: - Names
    /// Natural name of an IPTC key: translated if known, otherwise the key split into words
    static func naturalName(ofKey key: String) -> String {
        return ImageMetadataFormatter.naturalName(ofKey: key, prefix: "imageIptc_")
    }


    // MARK: - Values
    /// Dates are written "20240105", times "153027+0100"
    private static let dateKeys: Set<String> = ["DateCreated", "DigitalCreationDate", "ReleaseDate",
                                                "ExpirationDate", "ReferenceDate"]
    private static let timeKeys: Set<String> = ["TimeCreated", "DigitalCreationTime", "ReleaseTime",
                                                "ExpirationTime"]

    private static let iptcDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    /// Text presenting the value of an IPTC key
    static func formattedValue(of value: Any, forKey key: String) -> String? {
        return ImageMetadataFormatter.formattedValue(of: value, forKey: key) { value, key in
            let text = (value as? String) ?? (value as? NSNumber)?.stringValue
            guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
            if dateKeys.contains(key), let date = iptcDateFormatter.date(from: String(text.prefix(8))) {
                return displayDateFormatter.string(from: date)
            }
            if timeKeys.contains(key), text.count >= 6, text.prefix(6).allSatisfy(\.isNumber) {
                let digits = Array(text.prefix(6))
                let time = "\(digits[0])\(digits[1]):\(digits[2])\(digits[3]):\(digits[4])\(digits[5])"
                var offset = String(text.dropFirst(6)).replacingOccurrences(of: ":", with: "")
                if offset.count == 5, offset.hasPrefix("+") || offset.hasPrefix("-") {
                    offset.insert(":", at: offset.index(offset.startIndex, offsetBy: 3))
                    return time + " " + offset
                }
                return time
            }
            return nil
        }
    }
}
