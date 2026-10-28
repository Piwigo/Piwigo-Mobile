//
//  ImageProperties.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 04/11/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  Properties of an image file kept in directories of ImageIO, other than EXIF, GPS, IPTC and the maker
//  notes of Nikon, Canon and Apple which have their own readers: the maker notes of other cameras
//  and the properties specific to a format of image. They share their reading, which opens
//  the file once for all of them, and their presentation.
//

import Foundation
import ImageIO

/// A directory of the properties of ImageIO presented in its own section
enum ImagePropertiesKind: String, CaseIterable, Sendable {
    case minolta, fuji, olympus, pentax, raw

    /// Name of the directory in the properties of ImageIO
    var dictionary: String {
        switch self {
        case .minolta:  return kCGImagePropertyMakerMinoltaDictionary as String
        case .fuji:     return kCGImagePropertyMakerFujiDictionary as String
        case .olympus:  return kCGImagePropertyMakerOlympusDictionary as String
        case .pentax:   return kCGImagePropertyMakerPentaxDictionary as String
        case .raw:      return kCGImagePropertyRawDictionary as String
        }
    }

    /// The keys of a maker note are the numbers of its tags
    var isMakerNote: Bool {
        switch self {
        case .minolta, .fuji, .olympus, .pentax:    return true
        case .raw:                                  return false
        }
    }

    /// Title of the section
    var title: String {
        switch self {
        case .minolta:  return Self.cameraTitle(of: "Minolta")
        case .fuji:     return Self.cameraTitle(of: "Fuji")
        case .olympus:  return Self.cameraTitle(of: "Olympus")
        case .pentax:   return Self.cameraTitle(of: "Pentax")
        case .raw:      return "RAW"
        }
    }

    private static func cameraTitle(of brand: String) -> String {
        return String(format: String(localized: "imageMakerCamera_title", comment: "%@ Camera"), brand)
    }
}

struct ImageProperties: Sendable {
    /// Entries sorted alphabetically by natural name, or by number for the keys of a maker note
    let entries: [ImageMetadataEntry]
}

enum ImagePropertiesReader
{
    // MARK: - Cache
    private struct PropertiesSet: Sendable {
        let sections: [ImagePropertiesKind: ImageProperties]
    }
    private static let cache = ImageMetadataCache<PropertiesSet>()

    /// Returns the properties of a file already read, without reading it again
    static func cachedProperties(at url: URL) -> [ImagePropertiesKind: ImageProperties]? {
        guard let cached = cache.cachedValue(at: url) else { return nil }
        return cached?.sections ?? [:]
    }


    // MARK: - Reading
    /// Reads the properties of an image file. Returns none if the file has none.
    static func read(from url: URL) -> [ImagePropertiesKind: ImageProperties] {
        if let cached = cachedProperties(at: url) { return cached }
        let sections = readFile(at: url)
        cache.store(sections.isEmpty ? nil : PropertiesSet(sections: sections), at: url)
        return sections
    }

    private static func readFile(at url: URL) -> [ImagePropertiesKind: ImageProperties] {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else { return [:] }

        // Properties of the file and of its first image: animations keep some of them in the file
        let ofFile = CGImageSourceCopyProperties(source, options) as? [String: Any] ?? [:]
        let ofImage = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [String: Any] ?? [:]

        var sections = [ImagePropertiesKind: ImageProperties]()
        for kind in ImagePropertiesKind.allCases {
            var values = ofFile[kind.dictionary] as? [String: Any] ?? [:]
            for (key, value) in ofImage[kind.dictionary] as? [String: Any] ?? [:] where values[key] == nil {
                values[key] = value
            }
            if let properties = entries(of: kind, from: values) {
                sections[kind] = properties
            }
        }
        return sections
    }

    private static func entries(of kind: ImagePropertiesKind, from values: [String: Any]) -> ImageProperties? {
        var entries = [ImageMetadataEntry]()
        for (key, value) in values {
            guard let text = formattedValue(of: value, forKey: key), text.isEmpty == false else { continue }
            entries.append(ImageMetadataEntry(key: key, name: naturalName(ofKey: key, kind: kind), value: text))
        }
        guard entries.isEmpty == false else { return nil }

        // The keys of a maker note are numbers, which are sorted as such
        if kind.isMakerNote {
            entries.sort { (Int($0.key) ?? Int.max, $0.key) < (Int($1.key) ?? Int.max, $1.key) }
            return ImageProperties(entries: entries)
        }
        return ImageProperties(entries: entries.sortedByName())
    }


    // MARK: - Names
    /// Natural name of a key: translated if known, "Maker Key" and its number for a maker note,
    /// otherwise the key split into words
    static func naturalName(ofKey key: String, kind: ImagePropertiesKind) -> String {
        if kind.isMakerNote, Int(key) != nil {
            return String(format: String(localized: "imageAppleMakerKey_name", comment: "Maker Key %@"), key)
        }
        return ImageMetadataFormatter.naturalName(ofKey: key, prefix: "imageProp_")
    }


    // MARK: - Values
    /// Text presenting the value of a key
    static func formattedValue(of value: Any, forKey key: String) -> String? {
        typealias Formatter = ImageMetadataFormatter
        return Formatter.formattedValue(of: value, forKey: key)
    }
}
