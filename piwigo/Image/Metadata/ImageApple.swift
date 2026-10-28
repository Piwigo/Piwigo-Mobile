//
//  ImageApple.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 03/11/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  Metadata of the maker note of Apple cameras, as presented by the table of the metadata:
//  one entry per key, with the natural name of the key and a readable value.
//  ImageIO names the keys of this maker note with the numbers of its tags: those whose meaning
//  is known come first, sorted by name, then the others as "Maker Key N", sorted by number.
//

import Foundation
import ImageIO

struct ImageApple: Sendable {
    /// Entries sorted alphabetically by natural name
    let entries: [ImageMetadataEntry]
}

enum ImageAppleReader
{
    // MARK: - Cache
    private static let cache = ImageMetadataCache<ImageApple>()

    /// Returns the Apple data of a file already read, without reading it again
    static func cachedApple(at url: URL) -> ImageApple?? {
        return cache.cachedValue(at: url)
    }


    // MARK: - Reading
    /// Tags of the maker note whose meaning is known
    private static let knownKeys: Set<String> = [
        "1", "2", "3", "4", "5", "6", "7", "8", "10", "11", "12", "13", "17", "20", "23", "25", "26",
        "29", "32", "33", "35", "37", "39", "43", "45"
    ]

    /// Reads the Apple data of an image file. Returns nil if the file has none.
    static func read(from url: URL) -> ImageApple? {
        if let cached = cachedApple(at: url) { return cached }
        let apple = readFile(at: url)
        cache.store(apple, at: url)
        return apple
    }

    private static func readFile(at url: URL) -> ImageApple? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [String: Any],
              let values = properties[kCGImagePropertyMakerAppleDictionary as String] as? [String: Any]
        else { return nil }

        // Known tags sorted by natural name, then the other ones sorted by number
        var known = [ImageMetadataEntry]()
        var unknown = [ImageMetadataEntry]()
        for (key, value) in values {
            guard let text = formattedValue(of: value, forKey: key), text.isEmpty == false else { continue }
            let entry = ImageMetadataEntry(key: key, name: naturalName(ofKey: key), value: text)
            if knownKeys.contains(key) { known.append(entry) } else { unknown.append(entry) }
        }
        unknown.sort { (Int($0.key) ?? Int.max, $0.key) < (Int($1.key) ?? Int.max, $1.key) }
        let entries = known.sortedByName() + unknown
        return entries.isEmpty ? nil : ImageApple(entries: entries)
    }


    // MARK: - Names
    /// Natural name of an Apple tag: translated if known, otherwise "Maker Key" and its number
    static func naturalName(ofKey key: String) -> String {
        guard knownKeys.contains(key) else {
            return String(format: String(localized: "imageAppleMakerKey_name", comment: "Maker Key %@"), key)
        }
        return ImageMetadataFormatter.naturalName(ofKey: key, prefix: "imageApple_")
    }


    // MARK: - Values
    private static let uptimeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.maximumUnitCount = 3
        return formatter
    }()

    /// Text presenting the value of an Apple tag
    static func formattedValue(of value: Any, forKey key: String) -> String? {
        typealias Formatter = ImageMetadataFormatter
        switch key {
        case "3":
            /// Time since the device started: a count of ticks and the number of ticks per second
            if let time = value as? [String: Any],
               let ticks = (time["value"] as? NSNumber)?.doubleValue,
               let scale = (time["timescale"] as? NSNumber)?.doubleValue, scale > 0 {
                return uptimeFormatter.string(from: ticks / scale)
            }
            return nil
        case "39":
            /// Signal-to-noise ratio in decibels
            if let ratio = (value as? NSNumber)?.doubleValue {
                return Formatter.fixed(ratio, digits: 1) + " dB"
            }
        default:
            break
        }
        return Formatter.formattedValue(of: value, forKey: key)
    }
}
