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
    /// Entries in the order of their keys, the unknown ones alphabetically
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

    /// Order of the known tags: the identifiers, the capture, the exposure and focus, the device, the quality
    private static let keyOrder = ["1", "17", "43", "11", "32", "23", "20", "10", "33", "13",
                                   "2", "4", "5", "6", "7", "35", "12", "45", "3", "8",
                                   "25", "26", "29", "39", "37"]

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

        // Known tags in the order below, then the other ones sorted by number
        var known = [ImageMetadataEntry]()
        var unknown = [ImageMetadataEntry]()
        for (key, value) in values {
            guard let text = formattedValue(of: value, forKey: key), text.isEmpty == false else { continue }
            let entry = ImageMetadataEntry(key: key, name: naturalName(ofKey: key), value: text)
            if knownKeys.contains(key) { known.append(entry) } else { unknown.append(entry) }
        }
        unknown.sort { (Int($0.key) ?? Int.max, $0.key) < (Int($1.key) ?? Int.max, $1.key) }
        let entries = known.sorted(byKeyOrder: keyOrder) + unknown
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
        case "8":
            /// Acceleration of the device along its three axes, in units of g: (x, y, z) g
            if let array = value as? [Any], array.count == 3 {
                let components = array.compactMap { ($0 as? NSNumber)?.doubleValue }
                if components.count == 3 {
                    return "(" + components.map { Formatter.fixed($0, digits: 2) }.joined(separator: ", ") + ") g"
                }
            }
        case "4", "7":
            /// Flags telling whether the auto exposure and the auto focus had settled
            switch (value as? NSNumber)?.intValue {
            case 0:     return String(localized: "imageAppleStable_0", comment: "No")
            case 1:     return String(localized: "imageAppleStable_1", comment: "Yes")
            default:    break
            }
        case "12":
            /// Range of the distances in focus, in metres: nearest and farthest
            if let array = value as? [Any], array.count == 2,
               let distances = Optional(array.compactMap { ($0 as? NSNumber)?.doubleValue }), distances.count == 2 {
                let (near, far) = (min(distances[0], distances[1]), max(distances[0], distances[1]))
                func metres(_ value: Double) -> String { Formatter.plain((value * 100).rounded() / 100) }
                return metres(near) + " – " + metres(far) + " m"
            }
            return nil
        case "20":
            /// Type of capture: only the values known with certainty are decoded
            switch (value as? NSNumber)?.intValue {
            case 1:     return "ProRAW"
            case 2:     return String(localized: "imageAppleCaptureType_2", comment: "Portrait")
            case 10:    return String(localized: "imageAppleCaptureType_10", comment: "Photo")
            default:    break
            }
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
