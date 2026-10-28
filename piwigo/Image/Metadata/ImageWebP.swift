//
//  ImageWebP.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 31/10/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  WebP metadata of an image file, as presented by the table of the metadata:
//  one entry per WebP key, with the natural name of the key and a readable value.
//  Only animated images carry such metadata: canvas size, number of loops, frames and duration.
//

import Foundation
import ImageIO

struct ImageWebP: Sendable {
    /// Entries sorted alphabetically by natural name
    let entries: [ImageMetadataEntry]
}

enum ImageWebPReader
{
    // MARK: - Cache
    private static let cache = ImageMetadataCache<ImageWebP>()

    /// Returns the WebP data of a file already read, without reading it again
    static func cachedWebP(at url: URL) -> ImageWebP?? {
        return cache.cachedValue(at: url)
    }


    // MARK: - Reading
    /// Reads the WebP data of an image file. Returns nil if the file has none.
    static func read(from url: URL) -> ImageWebP? {
        if let cached = cachedWebP(at: url) { return cached }
        let webp = readFile(at: url)
        cache.store(webp, at: url)
        return webp
    }

    private static func readFile(at url: URL) -> ImageWebP? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options),
              let properties = CGImageSourceCopyProperties(source, options) as? [String: Any],
              let values = properties[kCGImagePropertyWebPDictionary as String] as? [String: Any]
        else { return nil }

        // Entries sorted by natural name
        var entries = [ImageMetadataEntry]()
        func add(_ key: String, _ text: String?) {
            guard let text = text, text.isEmpty == false else { return }
            entries.append(ImageMetadataEntry(key: key, name: naturalName(ofKey: key), value: text))
        }
        let frameInfoKey = kCGImagePropertyWebPFrameInfoArray as String
        for (key, value) in values where key != frameInfoKey {
            add(key, formattedValue(of: value, forKey: key))
        }

        // The frames are summarised by their number and the duration of the animation
        if let frames = values[frameInfoKey] as? [[String: Any]], frames.isEmpty == false {
            add("FrameCount", ImageMetadataFormatter.plain(Double(frames.count)))
            let delayKey = kCGImagePropertyWebPUnclampedDelayTime as String
            let duration = frames.compactMap { ($0[delayKey] as? NSNumber)?.doubleValue }.reduce(0, +)
            if duration > 0 {
                add("Duration", ImageMetadataFormatter.fixed(duration, digits: 2) + " s")
            }
        }
        return entries.isEmpty ? nil : ImageWebP(entries: entries.sortedByName())
    }


    // MARK: - Names
    /// Natural name of a WebP key: translated if known, otherwise the key split into words
    static func naturalName(ofKey key: String) -> String {
        return ImageMetadataFormatter.naturalName(ofKey: key, prefix: "imageWebP_")
    }


    // MARK: - Values
    /// Text presenting the value of a WebP key
    static func formattedValue(of value: Any, forKey key: String) -> String? {
        return ImageMetadataFormatter.formattedValue(of: value, forKey: key) { value, key in
            guard let number = (value as? NSNumber)?.doubleValue else { return nil }
            switch key {
            case "LoopCount":
                /// 0 loops forever
                return number == 0 ? "∞" : ImageMetadataFormatter.plain(number)
            default:
                return nil
            }
        }
    }
}
