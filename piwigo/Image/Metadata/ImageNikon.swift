//
//  ImageNikon.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 01/11/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  Metadata of the maker note of Nikon cameras, as presented by the table of the metadata:
//  one entry per key, with the natural name of the key and a readable value.
//

import Foundation
import ImageIO

struct ImageNikon: Sendable {
    /// Entries in the order of their keys, the unknown ones alphabetically
    let entries: [ImageMetadataEntry]
}

enum ImageNikonReader
{
    // MARK: - Cache
    private static let cache = ImageMetadataCache<ImageNikon>()

    /// Returns the Nikon data of a file already read, without reading it again
    static func cachedNikon(at url: URL) -> ImageNikon?? {
        return cache.cachedValue(at: url)
    }


    // MARK: - Reading
    /// Reads the Nikon data of an image file. Returns nil if the file has none.
    static func read(from url: URL) -> ImageNikon? {
        if let cached = cachedNikon(at: url) { return cached }
        let nikon = readFile(at: url)
        cache.store(nikon, at: url)
        return nikon
    }

    /// Order of the keys: the body, the lens, the shooting, the image
    private static let keyOrder = ["CameraSerialNumber", "ShutterCount", "LensType", "LensInfo", "LensAdapter",
                                   "ShootingMode", "ISOSetting", "ISOSelection", "FocusMode", "FocusDistance",
                                   "DigitalZoom", "FlashSetting", "FlashExposureComp",
                                   "Quality", "ColorMode", "ImageAdjustment", "SharpenMode", "WhiteBalanceMode"]

    private static func readFile(at url: URL) -> ImageNikon? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [String: Any],
              let values = properties[kCGImagePropertyMakerNikonDictionary as String] as? [String: Any]
        else { return nil }

        // Entries in their natural order
        var entries = [ImageMetadataEntry]()
        for (key, value) in values {
            guard let text = formattedValue(of: value, forKey: key), text.isEmpty == false else { continue }
            entries.append(ImageMetadataEntry(key: key, name: naturalName(ofKey: key), value: text))
        }
        return entries.isEmpty ? nil : ImageNikon(entries: entries.sorted(byKeyOrder: keyOrder))
    }


    // MARK: - Names
    /// Natural name of a Nikon key: translated if known, otherwise the key split into words
    static func naturalName(ofKey key: String) -> String {
        return ImageMetadataFormatter.naturalName(ofKey: key, prefix: "imageNikon_")
    }


    // MARK: - Values
    /// Text presenting the value of a Nikon key
    static func formattedValue(of value: Any, forKey key: String) -> String? {
        typealias Formatter = ImageMetadataFormatter
        let numbers = (value as? [Any])?.compactMap { ($0 as? NSNumber)?.doubleValue }

        switch key {
        case "ISOSetting":
            /// Two numbers, the first of which is often zero: the last one is the sensitivity
            if let iso = numbers?.last(where: { $0 > 0 }) {
                return "ISO " + Formatter.plain(iso)
            }
        case "LensInfo":
            /// Shortest and longest focal lengths, then the widest apertures at both ends of the zoom
            if let text = Formatter.formattedLensSpecification(value) {
                return text
            }
        default:
            break
        }
        return Formatter.formattedValue(of: value, forKey: key)
    }
}
