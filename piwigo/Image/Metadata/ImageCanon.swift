//
//  ImageCanon.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/11/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  Metadata of the maker note of Canon cameras, as presented by the table of the metadata:
//  one entry per key, with the natural name of the key and a readable value.
//

import Foundation
import ImageIO

struct ImageCanon: Sendable {
    /// Entries sorted alphabetically by natural name
    let entries: [ImageMetadataEntry]
}

enum ImageCanonReader
{
    // MARK: - Cache
    private static let cache = ImageMetadataCache<ImageCanon>()

    /// Returns the Canon data of a file already read, without reading it again
    static func cachedCanon(at url: URL) -> ImageCanon?? {
        return cache.cachedValue(at: url)
    }


    // MARK: - Reading
    /// Reads the Canon data of an image file. Returns nil if the file has none.
    static func read(from url: URL) -> ImageCanon? {
        if let cached = cachedCanon(at: url) { return cached }
        let canon = readFile(at: url)
        cache.store(canon, at: url)
        return canon
    }

    private static func readFile(at url: URL) -> ImageCanon? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [String: Any],
              let values = properties[kCGImagePropertyMakerCanonDictionary as String] as? [String: Any]
        else { return nil }

        // Entries sorted by natural name
        var entries = [ImageMetadataEntry]()
        for (key, value) in values {
            guard let text = formattedValue(of: value, forKey: key), text.isEmpty == false else { continue }
            entries.append(ImageMetadataEntry(key: key, name: naturalName(ofKey: key), value: text))
        }
        return entries.isEmpty ? nil : ImageCanon(entries: entries.sortedByName())
    }


    // MARK: - Names
    /// Natural name of a Canon key: translated if known, otherwise the key split into words
    static func naturalName(ofKey key: String) -> String {
        return ImageMetadataFormatter.naturalName(ofKey: key, prefix: "imageCanon_")
    }


    // MARK: - Values
    /// Text presenting the value of a Canon key
    static func formattedValue(of value: Any, forKey key: String) -> String? {
        typealias Formatter = ImageMetadataFormatter
        return Formatter.formattedValue(of: value, forKey: key) { value, key in
            guard let number = (value as? NSNumber)?.doubleValue else { return nil }
            switch key {
            case "MaxAperture", "MinAperture":
                return "f/" + Formatter.fixed(number, digits: 1)
            case "FlashExposureComp":
                return (number > 0 ? "+" : "") + Formatter.plain(number) + " EV"
            default:
                return nil
            }
        }
    }
}
