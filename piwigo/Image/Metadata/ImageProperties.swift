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

    /// Keys presented elsewhere: the Exif section shows the make, model, software, artist and copyright
    /// of the TIFF directory with the camera information, and the resolutions and densities show their unit
    var hidden: Set<String> {
        switch self {
        case .tiff: return ["Make", "Model", "Software", "Artist", "Copyright", "ResolutionUnit"]
        case .jfif: return ["DensityUnit"]
        default:    return []
        }
    }

    /// Order of the keys of the formats whose keys have a natural one, the others being alphabetical
    var keyOrder: [String] {
        switch self {
        case .tiff:
            return ["DateTime", "Orientation", "XResolution", "YResolution", "ResolutionUnit", "Compression",
                    "PhotometricInterpretation", "DocumentName", "ImageDescription", "HostComputer",
                    "TileWidth", "TileLength"]
        case .jfif:
            return ["JFIFVersion", "DensityUnit", "XDensity", "YDensity", "IsProgressive"]
        case .png:
            return ["Title", "Author", "Description", "Comment", "Copyright", "Creation Time",
                    "ModificationTime", "Software", "Source", "Disclaimer", "Warning", "Gamma", "sRGBIntent",
                    "InterlaceType", "XPixelsPerMeter", "YPixelsPerMeter"]
        case .gif:
            return ["FrameCount", "Duration", "LoopCount", "DelayTime", "UnclampedDelayTime", "HasGlobalColorMap"]
        default:
            return []
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
        for (key, value) in values where key != "FrameInfo" && kind.hidden.contains(key) == false {
            if kind == .tiff, key == "XResolution" || key == "YResolution" {
                add(key, resolution(value, unit: number(values["ResolutionUnit"])))
            } else if kind == .jfif, key == "XDensity" || key == "YDensity" {
                /// 1: dots per inch, 2: dots per centimeter, 0: no unit (the density gives the aspect ratio)
                let unit = number(values["DensityUnit"]).flatMap { Int(exactly: $0) }
                add(key, number(value).map {
                    let text = ImageMetadataFormatter.plain($0)
                    return unit == 1 ? text + " dpi" : unit == 2 ? text + " dpcm" : text
                })
            } else {
                add(key, formattedValue(of: value, forKey: key))
            }
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
        return ImageProperties(entries: entries.sorted(byKeyOrder: kind.keyOrder))
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
            case "Orientation":
                /// How the image is to be rotated or mirrored to be displayed upright
                switch number(value).flatMap({ Int(exactly: $0) }) {
                case 1: return String(localized: "imagePropOrientation_1", comment: "Normal")
                case 2: return String(localized: "imagePropOrientation_2", comment: "Mirrored horizontally")
                case 3: return String(localized: "imagePropOrientation_3", comment: "Rotated 180°")
                case 4: return String(localized: "imagePropOrientation_4", comment: "Mirrored vertically")
                case 5: return String(localized: "imagePropOrientation_5", comment: "Mirrored horizontally, rotated 90° counterclockwise")
                case 6: return String(localized: "imagePropOrientation_6", comment: "Rotated 90° clockwise")
                case 7: return String(localized: "imagePropOrientation_7", comment: "Mirrored horizontally, rotated 90° clockwise")
                case 8: return String(localized: "imagePropOrientation_8", comment: "Rotated 90° counterclockwise")
                default: return nil
                }
            case "Compression":
                /// Method of compression of the pixel data; the names of the methods are not translated
                switch number(value).flatMap({ Int(exactly: $0) }) {
                case 1:     return String(localized: "imagePropCompression_1", comment: "Uncompressed")
                case 2:     return "CCITT 1D"
                case 3:     return "CCITT Group 3"
                case 4:     return "CCITT Group 4"
                case 5:     return "LZW"
                case 6, 7:  return "JPEG"
                case 8:     return "Deflate (ZIP)"
                case 32773: return "PackBits"
                case 32946: return "Deflate"
                case 34712: return "JPEG 2000"
                case 34925: return "LZMA2"
                case 50000: return "Zstandard"
                case 50001: return "WebP"
                default:    return nil
                }
            case "PhotometricInterpretation":
                /// How the values of the pixels map to colours; the names of the colour models are not translated
                switch number(value).flatMap({ Int(exactly: $0) }) {
                case 0: return String(localized: "imagePropPhotometric_0", comment: "Grayscale (0 is white)")
                case 1: return String(localized: "imagePropPhotometric_1", comment: "Grayscale (0 is black)")
                case 3: return String(localized: "imagePropPhotometric_3", comment: "Color palette")
                case 4: return String(localized: "imagePropPhotometric_4", comment: "Transparency mask")
                case 32803: return String(localized: "imagePropPhotometric_32803", comment: "Color filter array")
                case 34892: return String(localized: "imagePropPhotometric_34892", comment: "Linear raw")
                case 2: return "RGB"
                case 5: return "CMYK"
                case 6: return "YCbCr"
                case 8: return "CIE L*a*b*"
                default: return nil
                }
            case "sRGBIntent":
                /// Rendering intent of the sRGB profile of a PNG
                switch number(value).flatMap({ Int(exactly: $0) }) {
                case 0: return String(localized: "imagePropSRGBIntent_0", comment: "Perceptual")
                case 1: return String(localized: "imagePropSRGBIntent_1", comment: "Relative colorimetric")
                case 2: return String(localized: "imagePropSRGBIntent_2", comment: "Saturation")
                case 3: return String(localized: "imagePropSRGBIntent_3", comment: "Absolute colorimetric")
                default: return nil
                }
            case "InterlaceType":
                switch number(value).flatMap({ Int(exactly: $0) }) {
                case 0: return String(localized: "imagePropInterlaceType_0", comment: "None")
                case 1: return "Adam7"
                default: return nil
                }
            case "XPixelsPerMeter", "YPixelsPerMeter":
                return number(value).map { Formatter.plain($0) + " px/m" }
            case "TileWidth", "TileLength":
                return number(value).map { Formatter.plain($0) + " px" }
            case "HasGlobalColorMap", "IsProgressive":
                /// Yes or no, written with the translations used for the flags of the Apple tags
                switch number(value).flatMap({ Int(exactly: $0) }) {
                case 0: return String(localized: "imageAppleStable_0", comment: "No")
                case 1: return String(localized: "imageAppleStable_1", comment: "Yes")
                default: return nil
                }
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

    /// Resolution followed by its unit: 72 → "72 dpi" (unit 2, the default), "28 dpcm" (unit 3), "72" (unit 1)
    private static func resolution(_ value: Any, unit: Double?) -> String? {
        guard let resolution = number(value) else { return nil }
        let text = ImageMetadataFormatter.plain(resolution)
        switch Int(unit ?? 2) {
        case 2:     return text + " dpi"
        case 3:     return text + " dpcm"
        default:    return text
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
