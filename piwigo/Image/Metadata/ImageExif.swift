//
//  ImageExif.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/10/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  EXIF metadata of an image file, as presented by the table of the metadata:
//  one entry per EXIF key, with the natural name of the key and a readable value.
//

import Foundation
import ImageIO

struct ImageExif: Sendable {
    /// Version of the EXIF standard, e.g. "2.3"
    let version: String?
    /// Entries sorted alphabetically by natural name
    let entries: [ImageMetadataEntry]
}

enum ImageExifReader
{
    // MARK: - Cache
    private static let cache = ImageMetadataCache<ImageExif>()

    /// Returns the EXIF data of a file already read, without reading it again
    static func cachedExif(at url: URL) -> ImageExif?? {
        return cache.cachedValue(at: url)
    }


    // MARK: - Reading
    /// Reads the EXIF data of an image file. Returns nil if the file has none.
    static func read(from url: URL) -> ImageExif? {
        if let cached = cachedExif(at: url) { return cached }
        let exif = readFile(at: url)
        cache.store(exif, at: url)
        return exif
    }

    private static func readFile(at url: URL) -> ImageExif? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [String: Any]
        else { return nil }

        // Collect the EXIF values
        var values = [String: Any]()
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            values = exif
        }
        // Make, model and others are stored in the TIFF directory but belong to the EXIF set
        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            for key in tiffKeys {
                if let value = tiff[key] { values[key] = value }
            }
        }
        guard values.isEmpty == false else { return nil }

        // Version of the EXIF standard
        let version = (values[kCGImagePropertyExifVersion as String]).flatMap { ImageMetadataFormatter.formattedVersion($0) }

        // Entries sorted by natural name
        var entries = [ImageMetadataEntry]()
        for (key, value) in values where key != kCGImagePropertyExifVersion as String {
            guard let text = formattedValue(of: value, forKey: key), text.isEmpty == false else { continue }
            entries.append(ImageMetadataEntry(key: key, name: naturalName(ofKey: key), value: text))
        }
        return entries.isEmpty ? nil : ImageExif(version: version, entries: entries.sortedByName())
    }

    private static let tiffKeys = [kCGImagePropertyTIFFMake, kCGImagePropertyTIFFModel,
                                   kCGImagePropertyTIFFSoftware, kCGImagePropertyTIFFArtist,
                                   kCGImagePropertyTIFFCopyright].map { $0 as String }


    // MARK: - Names
    /// Natural name of an EXIF key: translated if known, otherwise the key split into words
    static func naturalName(ofKey key: String) -> String {
        return ImageMetadataFormatter.naturalName(ofKey: key, prefix: "imageExif_")
    }


    // MARK: - Values
    private static let exifDateFormatter: DateFormatter = {
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

    /// Text presenting the value of an EXIF key
    static func formattedValue(of value: Any, forKey key: String) -> String? {
        return ImageMetadataFormatter.formattedValue(of: value, forKey: key) { value, key in
            typealias Formatter = ImageMetadataFormatter
            if let number = (value as? NSNumber)?.doubleValue {
                switch key {
                case "ExposureTime":
                    guard number > 0 else { return nil }
                    return number < 1 ? "1/\(Int((1 / number).rounded())) s" : "\(Formatter.plain(number)) s"
                case "FNumber":
                    return "f/" + Formatter.fixed(number, digits: 1)
                case "FocalLength", "FocalLenIn35mmFilm":
                    return Formatter.plain(number) + " mm"
                case "SubjectDistance":
                    return Formatter.plain(number) + " m"
                case "ExposureBiasValue":
                    return (number > 0 ? "+" : "") + Formatter.plain(number) + " EV"
                default:
                    return nil
                }
            }
            // Dates are written "2024:01:05 12:34:56"
            if let text = value as? String, key == "DateTimeOriginal" || key == "DateTimeDigitized",
               let date = exifDateFormatter.date(from: text) {
                return displayDateFormatter.string(from: date)
            }
            return nil
        }
    }

    /// "SubjectDistRange" → "Subject Dist Range", "ISOSpeed" → "ISO Speed"
    static func humanized(_ key: String) -> String {
        return ImageMetadataFormatter.humanized(key)
    }
}
