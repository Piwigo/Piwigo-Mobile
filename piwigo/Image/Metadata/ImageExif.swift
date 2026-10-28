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

struct ImageExifEntry: Sendable {
    let key: String         // Name of the EXIF key, e.g. "FNumber"
    let name: String        // Natural name, e.g. "F-Number"
    let value: String       // Readable value, e.g. "f/1.8"
}

struct ImageExif: Sendable {
    /// Version of the EXIF standard, e.g. "2.3"
    let version: String?
    /// Entries sorted alphabetically by natural name
    let entries: [ImageExifEntry]
}

enum ImageExifReader
{
    // MARK: - Cache
    /// EXIF data of the files read during the session, which are re-read when a file changes
    private static let cache = NSCache<NSString, CachedExif>()
    private final class CachedExif {
        let exif: ImageExif?
        let modificationDate: Date?
        init(exif: ImageExif?, modificationDate: Date?) {
            self.exif = exif
            self.modificationDate = modificationDate
        }
    }

    /// Returns the EXIF data of a file already read, without reading it again
    static func cachedExif(at url: URL) -> ImageExif?? {
        guard let cached = cache.object(forKey: url.path as NSString),
              cached.modificationDate == modificationDate(of: url)
        else { return nil }
        return .some(cached.exif)
    }

    private static func modificationDate(of url: URL) -> Date? {
        return (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }


    // MARK: - Reading
    /// Reads the EXIF data of an image file. Returns nil if the file has none.
    static func read(from url: URL) -> ImageExif? {
        if let cached = cachedExif(at: url) { return cached }
        let exif = readFile(at: url)
        cache.setObject(CachedExif(exif: exif, modificationDate: modificationDate(of: url)),
                        forKey: url.path as NSString)
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
        let version = (values[kCGImagePropertyExifVersion as String]).flatMap { formattedVersion($0) }

        // Entries sorted by natural name
        var entries = [ImageExifEntry]()
        for (key, value) in values where key != kCGImagePropertyExifVersion as String {
            guard let text = formattedValue(of: value, forKey: key), text.isEmpty == false else { continue }
            entries.append(ImageExifEntry(key: key, name: naturalName(ofKey: key), value: text))
        }
        entries.sort {
            let result = $0.name.localizedStandardCompare($1.name)
            return result == .orderedSame ? $0.key < $1.key : result == .orderedAscending
        }
        return entries.isEmpty ? nil : ImageExif(version: version, entries: entries)
    }

    private static let tiffKeys = [kCGImagePropertyTIFFMake, kCGImagePropertyTIFFModel,
                                   kCGImagePropertyTIFFSoftware, kCGImagePropertyTIFFArtist,
                                   kCGImagePropertyTIFFCopyright].map { $0 as String }


    // MARK: - Names
    /// Natural name of an EXIF key: translated if known, otherwise the key split into words
    static func naturalName(ofKey key: String) -> String {
        // Keys without translation are not looked up, which the system would report as errors
        let localizationKey = "imageExif_" + key
        guard translatedKeys?.contains(localizationKey) ?? true else { return humanized(key) }
        let name = Bundle.main.localizedString(forKey: localizationKey, value: nil, table: nil)
        // NSShowNonLocalizedStrings returns the key in upper case
        return name.caseInsensitiveCompare(localizationKey) == .orderedSame ? humanized(key) : name
    }

    /// Keys of the names translated in the app, read once from its source language
    private static let translatedKeys: Set<String>? = {
        guard let path = Bundle.main.path(forResource: "Localizable", ofType: "strings",
                                          inDirectory: nil, forLocalization: "en"),
              let strings = NSDictionary(contentsOfFile: path) as? [String: Any]
        else { return nil }
        return Set(strings.keys.filter { $0.hasPrefix("imageExif_") })
    }()

    /// "SubjectDistRange" → "Subject Dist Range", "ISOSpeed" → "ISO Speed"
    static func humanized(_ key: String) -> String {
        var result = ""
        let characters = Array(key)
        for (index, character) in characters.enumerated() {
            if index > 0, character.isUppercase {
                let previous = characters[index - 1]
                let next = index + 1 < characters.count ? characters[index + 1] : nil
                if previous.isLowercase || previous.isNumber || (previous.isUppercase && next?.isLowercase == true) {
                    result.append(" ")
                }
            }
            result.append(character)
        }
        return result
    }


    // MARK: - Values
    private static func formattedVersion(_ value: Any) -> String? {
        // [2, 3, 0] → "2.3", [2, 2, 1] → "2.21"
        guard let digits = (value as? [Any])?.compactMap({ ($0 as? NSNumber)?.intValue }),
              let major = digits.first
        else { return nil }
        var minor = digits.dropFirst().map(String.init).joined()
        while minor.hasSuffix("0") { minor.removeLast() }
        return minor.isEmpty ? "\(major)" : "\(major).\(minor)"
    }

    private static func number(_ value: Any) -> Double? {
        return (value as? NSNumber)?.doubleValue
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    private static func plain(_ value: Double) -> String {
        return numberFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private static func fixed(_ value: Double, digits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = digits
        formatter.minimumFractionDigits = digits
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

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
        // Specific presentations
        if let number = number(value) {
            switch key {
            case "ExposureTime":
                guard number > 0 else { break }
                return number < 1 ? "1/\(Int((1 / number).rounded())) s" : "\(plain(number)) s"
            case "FNumber":
                return "f/" + fixed(number, digits: 1)
            case "FocalLength":
                return plain(number) + " mm"
            case "FocalLenIn35mmFilm":
                return plain(number) + " mm"
            case "SubjectDistance":
                return plain(number) + " m"
            case "ExposureBiasValue":
                return (number > 0 ? "+" : "") + plain(number) + " EV"
            default:
                break
            }
            return plain(number)
        }
        if let text = value as? String {
            // Dates are written "2024:01:05 12:34:56"
            if key == "DateTimeOriginal" || key == "DateTimeDigitized",
               let date = exifDateFormatter.date(from: text) {
                return displayDateFormatter.string(from: date)
            }
            return text.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
        }
        if let data = value as? Data {
            // Binary data, such as the maker note
            return ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
        }
        if let array = value as? [Any] {
            return array.compactMap { formattedValue(of: $0, forKey: key) }.joined(separator: "; ")
        }
        return nil
    }
}
