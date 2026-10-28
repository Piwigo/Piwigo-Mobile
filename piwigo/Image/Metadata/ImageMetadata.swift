//
//  ImageMetadata.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 31/10/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  All the metadata of an image file presented by the table of the metadata.
//

import Foundation

struct ImageMetadata: Sendable {
    var exif: ImageExif?
    var gps: ImageGps?
    var iptc: ImageIptc?
    var webp: ImageWebP?

    /// True if the file has no metadata of any kind
    var isEmpty: Bool {
        return exif == nil && gps == nil && iptc == nil && webp == nil
    }

    /// Metadata of the first file containing some: the files of an image keep the metadata of the original.
    static func read(in urls: [URL]) -> ImageMetadata {
        for url in urls {
            let metadata = ImageMetadata(exif: ImageExifReader.read(from: url),
                                         gps: ImageGpsReader.read(from: url),
                                         iptc: ImageIptcReader.read(from: url),
                                         webp: ImageWebPReader.read(from: url))
            if metadata.isEmpty == false { return metadata }
        }
        return ImageMetadata()
    }

    /// Same as `read(in:)` if all the files to read have already been read, nil otherwise
    static func cached(in urls: [URL]) -> ImageMetadata? {
        for url in urls {
            guard let exif = ImageExifReader.cachedExif(at: url),
                  let gps = ImageGpsReader.cachedGps(at: url),
                  let iptc = ImageIptcReader.cachedIptc(at: url),
                  let webp = ImageWebPReader.cachedWebP(at: url)
            else { return nil }
            let metadata = ImageMetadata(exif: exif, gps: gps, iptc: iptc, webp: webp)
            if metadata.isEmpty == false { return metadata }
        }
        return ImageMetadata()
    }
}
