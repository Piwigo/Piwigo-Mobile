//
//  ImageMetadataEntry.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 29/10/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  Elements shared by the readers of the metadata of an image file (EXIF, IPTC…):
//  entries, cache of the data read, natural names of the keys and readable values.
//

import Foundation

/// One metadata of an image file, e.g. the f-number of the EXIF directory
struct ImageMetadataEntry: Sendable {
    let key: String         // Name of the key, e.g. "FNumber"
    let name: String        // Natural name, e.g. "F-Number"
    let value: String       // Readable value, e.g. "f/1.8"
}

extension Array where Element == ImageMetadataEntry {
    /// Entries sorted alphabetically by natural name
    func sortedByName() -> [ImageMetadataEntry] {
        return sorted {
            let result = $0.name.localizedStandardCompare($1.name)
            return result == .orderedSame ? $0.key < $1.key : result == .orderedAscending
        }
    }
}


// MARK: - Cache
/// Data of the files read during the session, which are read again when a file changes
final class ImageMetadataCache<Value: Sendable>: @unchecked Sendable
{
    private final class Box {
        let value: Value?
        let modificationDate: Date?
        init(value: Value?, modificationDate: Date?) {
            self.value = value
            self.modificationDate = modificationDate
        }
    }
    private let cache = NSCache<NSString, Box>()

    /// Data already read: nil if the file has not been read, .some(nil) if it contains none
    func cachedValue(at url: URL) -> Value?? {
        guard let box = cache.object(forKey: url.path as NSString),
              box.modificationDate == Self.modificationDate(of: url)
        else { return nil }
        return .some(box.value)
    }

    func store(_ value: Value?, at url: URL) {
        cache.setObject(Box(value: value, modificationDate: Self.modificationDate(of: url)),
                        forKey: url.path as NSString)
    }

    private static func modificationDate(of url: URL) -> Date? {
        return (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }
}


// MARK: - Names and Values
enum ImageMetadataFormatter
{
    // MARK: Names
    /// Natural name of a key: translated if known, otherwise the key split into words
    static func naturalName(ofKey key: String, prefix: String) -> String {
        // Keys without translation are not looked up, which the system would report as errors
        let localizationKey = prefix + key
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
        return Set(strings.keys.filter { $0.hasPrefix("imageExif_") || $0.hasPrefix("imageGps_")
                                         || $0.hasPrefix("imageIptc_") || $0.hasPrefix("imageWebP_") })
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


    // MARK: Versions
    /// Version written as digits: [2, 3, 0] → "2.3", [2, 2, 1] → "2.21"
    static func formattedVersion(_ value: Any) -> String? {
        guard let digits = (value as? [Any])?.compactMap({ ($0 as? NSNumber)?.intValue }),
              let major = digits.first
        else { return nil }
        var minor = digits.dropFirst().map(String.init).joined()
        while minor.hasSuffix("0") { minor.removeLast() }
        return minor.isEmpty ? "\(major)" : "\(major).\(minor)"
    }


    // MARK: Numbers
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    static func plain(_ value: Double) -> String {
        return numberFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func fixed(_ value: Double, digits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = digits
        formatter.minimumFractionDigits = digits
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }


    // MARK: Values
    /// Text presenting the value of a key
    /// - `scalar` gives the presentation of a number or a string specific to a key, or nil for the default one
    static func formattedValue(of value: Any, forKey key: String,
                               scalar: (Any, String) -> String? = { _, _ in nil }) -> String? {
        if let number = value as? NSNumber {
            return scalar(number, key) ?? plain(number.doubleValue)
        }
        if let text = value as? String {
            return scalar(text, key)
                ?? text.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
        }
        if let data = value as? Data {
            // Binary data, such as the maker note
            return ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
        }
        if let array = value as? [Any] {
            return array.compactMap { formattedValue(of: $0, forKey: key, scalar: scalar) }
                .filter { $0.isEmpty == false }.joined(separator: "; ")
        }
        if let dictionary = value as? [String: Any] {
            // Nested directories, such as the contact info of the creator
            return dictionary.sorted { $0.key < $1.key }
                .compactMap { formattedValue(of: $0.value, forKey: $0.key, scalar: scalar) }
                .filter { $0.isEmpty == false }.joined(separator: "; ")
        }
        return nil
    }
}
