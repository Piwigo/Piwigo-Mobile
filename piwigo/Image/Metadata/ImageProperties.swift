//
//  ImageProperties.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 04/11/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  Properties of an image file kept in directories of ImageIO, other than EXIF, GPS, IPTC and the maker
//  notes of Nikon, Canon and Apple which have their own readers: the maker notes of other cameras,
//  the RAW properties and the properties specific to a format of image. They share their reading,
//  which opens the file once for all of them, and their presentation.
//

import Foundation
import ImageIO

/// A directory of the properties of ImageIO presented in its own section
enum ImagePropertiesKind: String, CaseIterable, Sendable {
    case minolta, fuji, olympus, pentax, raw
    case ciff, dng, gif, heics, jfif, png, tga, tiff, photoshop

    /// Name of the directory in the properties of ImageIO
    var dictionary: String {
        switch self {
        case .minolta:  return kCGImagePropertyMakerMinoltaDictionary as String
        case .fuji:     return kCGImagePropertyMakerFujiDictionary as String
        case .olympus:  return kCGImagePropertyMakerOlympusDictionary as String
        case .pentax:   return kCGImagePropertyMakerPentaxDictionary as String
        case .raw:      return kCGImagePropertyRawDictionary as String
        case .ciff:     return kCGImagePropertyCIFFDictionary as String
        case .dng:      return kCGImagePropertyDNGDictionary as String
        case .gif:      return kCGImagePropertyGIFDictionary as String
        case .heics:    return kCGImagePropertyHEICSDictionary as String
        case .jfif:     return kCGImagePropertyJFIFDictionary as String
        case .png:      return kCGImagePropertyPNGDictionary as String
        case .tga:      return kCGImagePropertyTGADictionary as String
        case .tiff:     return kCGImagePropertyTIFFDictionary as String
        case .photoshop: return kCGImageProperty8BIMDictionary as String
        }
    }

    /// The keys of a maker note are the numbers of its tags
    var isMakerNote: Bool {
        switch self {
        case .minolta, .fuji, .olympus, .pentax:    return true
        default:                                    return false
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
        case .ciff:     return Self.propertiesTitle(of: "CIFF")
        case .dng:      return Self.propertiesTitle(of: "DNG")
        case .gif:      return Self.propertiesTitle(of: "GIF")
        case .heics:    return Self.propertiesTitle(of: "HEIC")
        case .jfif:     return Self.propertiesTitle(of: "JFIF")
        case .png:      return Self.propertiesTitle(of: "PNG")
        case .tga:      return Self.propertiesTitle(of: "TGA")
        case .tiff:     return Self.propertiesTitle(of: "TIFF")
        case .photoshop: return Self.propertiesTitle(of: "8BIM")
        }
    }

    private static func propertiesTitle(of format: String) -> String {
        return String(format: String(localized: "imageProperties_title", comment: "%@ Properties"), format)
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
        func add(_ key: String, _ text: String?) {
            guard let text = text, text.isEmpty == false else { return }
            entries.append(ImageMetadataEntry(key: key, name: naturalName(ofKey: key, kind: kind), value: text))
        }
        for (key, value) in values where key != "FrameInfo" {
            add(key, formattedValue(of: value, forKey: key))
        }

        // The frames of an animation are summarised by their number and the duration of the animation
        if let frames = values["FrameInfo"] as? [[String: Any]], frames.isEmpty == false {
            add("FrameCount", ImageMetadataFormatter.plain(Double(frames.count)))
            let duration = frames.compactMap { number($0["UnclampedDelayTime"]) }.reduce(0, +)
            if duration > 0 {
                add("Duration", ImageMetadataFormatter.fixed(duration, digits: 2) + " s")
            }
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
        return ImageMetadataFormatter.naturalName(ofKey: key, prefixes: namePrefixes)
    }

    /// Names are shared with the other sections when their keys have the same meaning
    private static let namePrefixes = ["imageProp_", "imageExif_", "imageNikon_", "imageCanon_",
                                       "imageIptc_", "imageGps_", "imageWebP_"]


    // MARK: - Values
    /// Text presenting the value of a key
    static func formattedValue(of value: Any, forKey key: String) -> String? {
        typealias Formatter = ImageMetadataFormatter
        /// Versions are written as digits: [1, 4, 0, 0] → "1.4"
        if ["JFIFVersion", "DNGVersion", "DNGBackwardVersion"].contains(key),
           let version = Formatter.formattedVersion(value) {
            return version
        }
        return Formatter.formattedValue(of: value, forKey: key) { value, key in
            switch key {
            case "DelayTime", "UnclampedDelayTime":
                /// Seconds, written as numbers or as texts
                return number(value).map { Formatter.fixed($0, digits: 2) + " s" }
            case "LoopCount":
                /// 0 loops forever
                return number(value).map { $0 == 0 ? "∞" : Formatter.plain($0) }
            case "DateTime":
                /// Dates are written "2024:01:05 12:34:56"
                if let text = value as? String, let date = tiffDateFormatter.date(from: text) {
                    return displayDateFormatter.string(from: date)
                }
                return nil
            default:
                return nil
            }
        }
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let text = value as? String { return Double(text.trimmingCharacters(in: .whitespaces)) }
        return nil
    }

    private static let tiffDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter
    }()

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}
