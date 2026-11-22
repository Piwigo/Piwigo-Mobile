//
//  ImageGpsWriter.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/11/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  Writes the position of a photo into its file without re-encoding the image
//  and without touching the other metadata.
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ImageGpsWriterError: Error, Sendable {
    case unreadableFile
    case unsupportedFormat
    case writeFailed
}

public enum ImageGpsWriter
{
    // MARK: - Formats
    /// Formats whose GPS tags can be rewritten by ImageIO without re-encoding the image and which the Piwigo server
    /// reads: JPEG, TIFF and HEIF. PNG is not read by the PHP of the server, WebP cannot be written by ImageIO.
    public static func canWriteLocation(inFileWithExtension fileExtension: String) -> Bool {
        return ["jpg", "jpeg", "jpe", "tif", "tiff", "heic", "heif"].contains(fileExtension.lowercased())
    }

    /// GPS tags which no longer describe the photo once it is moved: altitude, speed, track, positioning error.
    /// The date and time of the fix, the direction of the camera and the other GPS tags are kept.
    static let obsoleteKeys = ["GPSAltitude", "GPSAltitudeRef", "GPSSpeed", "GPSSpeedRef",
                               "GPSTrack", "GPSTrackRef", "GPSHPositioningError"]


    // MARK: - Writing
    /// Copies `source` to `destination` with the new position. The destination is replaced if it exists.
    /// - Parameters:
    ///   - latitude: degrees north, negative south
    ///   - longitude: degrees east, negative west
    public static func write(latitude: Double, longitude: Double, from source: URL, to destination: URL) throws(ImageGpsWriterError) {
        guard abs(latitude) <= 90, abs(longitude) <= 180 else { throw .writeFailed }
        guard canWriteLocation(inFileWithExtension: source.pathExtension) else { throw .unsupportedFormat }

        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, options),
              let type = CGImageSourceGetType(imageSource), CGImageSourceGetCount(imageSource) > 0
        else { throw .unreadableFile }

        // Tags to merge with the existing metadata: the new position, and kCFNull for the tags to remove
        guard let metadata = CGImageMetadataCreateMutable() as CGMutableImageMetadata? else { throw .writeFailed }
        let exif = kCGImageMetadataPrefixExif as String
        func set(_ key: String, _ value: CFTypeRef) {
            CGImageMetadataSetValueWithPath(metadata, nil, "\(exif):\(key)" as CFString, value)
        }
        set("GPSLatitude", xmpCoordinate(abs(latitude), positive: "N", negative: "S", isNegative: latitude < 0) as CFString)
        set("GPSLongitude", xmpCoordinate(abs(longitude), positive: "E", negative: "W", isNegative: longitude < 0) as CFString)
        for key in obsoleteKeys { set(key, kCFNull) }

        // Copy of the image data with the merged metadata
        let temporary = destination.deletingLastPathComponent()
            .appendingPathComponent(".gps-" + UUID().uuidString + "." + destination.pathExtension)
        guard let imageDestination = CGImageDestinationCreateWithURL(temporary as CFURL, type,
                                                                     CGImageSourceGetCount(imageSource), nil)
        else { throw .writeFailed }
        let copyOptions: [CFString: Any] = [kCGImageDestinationMetadata: metadata,
                                            kCGImageDestinationMergeMetadata: true]
        var error: Unmanaged<CFError>?
        guard CGImageDestinationCopyImageSource(imageDestination, imageSource, copyOptions as CFDictionary, &error)
        else {
            try? FileManager.default.removeItem(at: temporary)
            throw .writeFailed
        }

        // The copy replaces the destination
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary)
            } else {
                try FileManager.default.moveItem(at: temporary, to: destination)
            }
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw .writeFailed
        }
    }

    /// Coordinate written the way XMP does: "48,51.3960N" i.e. degrees, decimal minutes and hemisphere
    static func xmpCoordinate(_ value: Double, positive: String, negative: String, isNegative: Bool) -> String {
        var degrees = Int(value)
        var minutes = ((value - Double(degrees)) * 60 * 10000).rounded() / 10000
        if minutes >= 60 {
            degrees += 1
            minutes = 0
        }
        return "\(degrees),\(String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), minutes))" + (isNegative ? negative : positive)
    }
}
