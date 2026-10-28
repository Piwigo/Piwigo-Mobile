//
//  ImageGps.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 30/10/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  GPS metadata of an image file, as presented by the table of the metadata:
//  one entry per GPS key, with the natural name of the key and a readable value.
//  The reference of a value (N or S for a latitude, K or M for a speed…) is written with the value.
//

import Foundation
import ImageIO

struct ImageGps: Sendable {
    /// Version of the GPS tags, e.g. "2.2"
    let version: String?
    /// Entries sorted alphabetically by natural name
    let entries: [ImageMetadataEntry]
}

enum ImageGpsReader
{
    // MARK: - Cache
    private static let cache = ImageMetadataCache<ImageGps>()

    /// Returns the GPS data of a file already read, without reading it again
    static func cachedGps(at url: URL) -> ImageGps?? {
        return cache.cachedValue(at: url)
    }


    // MARK: - Reading
    /// Reads the GPS data of an image file. Returns nil if the file has none.
    static func read(from url: URL) -> ImageGps? {
        if let cached = cachedGps(at: url) { return cached }
        let gps = readFile(at: url)
        cache.store(gps, at: url)
        return gps
    }

    private static func readFile(at url: URL) -> ImageGps? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [String: Any],
              let values = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any]
        else { return nil }

        // Version of the GPS tags
        let versionKey = kCGImagePropertyGPSVersion as String
        let version = values[versionKey].flatMap { ImageMetadataFormatter.formattedVersion($0) }

        // References written with their value
        let merged = Set(references.compactMap { values[$0.key] != nil && values[$0.value] != nil ? $0.value : nil })

        // Entries sorted by natural name
        var entries = [ImageMetadataEntry]()
        for (key, value) in values where key != versionKey && merged.contains(key) == false {
            let reference = references[key].flatMap { values[$0] }
            guard let text = formattedValue(of: value, forKey: key, reference: reference), text.isEmpty == false
            else { continue }
            entries.append(ImageMetadataEntry(key: key, name: naturalName(ofKey: key), value: text))
        }
        return entries.isEmpty ? nil : ImageGps(version: version, entries: entries.sortedByName())
    }


    // MARK: - Names
    /// Natural name of a GPS key: translated if known, otherwise the key split into words
    static func naturalName(ofKey key: String) -> String {
        return ImageMetadataFormatter.naturalName(ofKey: key, prefix: "imageGps_")
    }


    // MARK: - Values
    /// Key of the reference of a value
    private static let references = ["Latitude": "LatitudeRef", "Longitude": "LongitudeRef",
                                     "DestLatitude": "DestLatitudeRef", "DestLongitude": "DestLongitudeRef",
                                     "Altitude": "AltitudeRef", "Speed": "SpeedRef",
                                     "ImgDirection": "ImgDirectionRef", "Track": "TrackRef",
                                     "DestBearing": "DestBearingRef", "DestDistance": "DestDistanceRef"]

    private static let gpsDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd"
        return formatter
    }()

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    /// Text presenting the value of a GPS key, with its reference if any
    static func formattedValue(of value: Any, forKey key: String, reference: Any?) -> String? {
        typealias Formatter = ImageMetadataFormatter
        let letter = (reference as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""

        return Formatter.formattedValue(of: value, forKey: key) { value, key in
            if let number = (value as? NSNumber)?.doubleValue {
                switch key {
                case "Latitude", "Longitude", "DestLatitude", "DestLongitude":
                    return Formatter.fixed(abs(number), digits: 5) + "°" + (letter.isEmpty ? "" : " " + letter)
                case "Altitude":
                    /// 0 above sea level, 1 below
                    let below = (reference as? NSNumber)?.intValue == 1
                    return Formatter.fixed(below ? -abs(number) : number, digits: 1) + " m"
                case "Speed":
                    let units = ["K": "km/h", "M": "mph", "N": "kn"]
                    return Formatter.fixed(number, digits: 1) + (units[letter].map { " " + $0 } ?? "")
                case "ImgDirection", "Track", "DestBearing":
                    /// T true north, M magnetic north
                    return Formatter.fixed(number, digits: 1) + "°" + (letter.isEmpty ? "" : " " + letter)
                case "DestDistance":
                    let units = ["K": "km", "M": "mi", "N": "nmi"]
                    return Formatter.fixed(number, digits: 1) + (units[letter].map { " " + $0 } ?? "")
                case "HPositioningError":
                    return Formatter.fixed(number, digits: 1) + " m"
                default:
                    return nil
                }
            }
            // Dates are written "2024:01:05"
            if let text = value as? String, key == "DateStamp",
               let date = gpsDateFormatter.date(from: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return displayDateFormatter.string(from: date)
            }
            return nil
        }
    }
}
