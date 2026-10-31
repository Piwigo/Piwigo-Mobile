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

public struct ImageMetadata: Sendable {
    public var exif: ImageExif?
    public var gps: ImageGps?
    public var iptc: ImageIptc?
    public var webp: ImageWebP?
    public var nikon: ImageNikon?
    public var canon: ImageCanon?
    public var apple: ImageApple?
    public var properties = [ImagePropertiesKind: ImageProperties]()

    public init() {}

    init(exif: ImageExif?, gps: ImageGps?, iptc: ImageIptc?, webp: ImageWebP?, nikon: ImageNikon?,
         canon: ImageCanon?, apple: ImageApple?, properties: [ImagePropertiesKind: ImageProperties]) {
        self.exif = exif
        self.gps = gps
        self.iptc = iptc
        self.webp = webp
        self.nikon = nikon
        self.canon = canon
        self.apple = apple
        self.properties = properties
    }

    /// True if the file has no metadata of any kind
    public var isEmpty: Bool {
        return exif == nil && gps == nil && iptc == nil && webp == nil && nikon == nil && canon == nil && apple == nil
            && properties.isEmpty
    }

    /// Metadata of the first file containing some: the files of an image keep the metadata of the original.
    public static func read(in urls: [URL]) -> ImageMetadata {
        for url in urls {
            let metadata = ImageMetadata(exif: ImageExifReader.read(from: url),
                                         gps: ImageGpsReader.read(from: url),
                                         iptc: ImageIptcReader.read(from: url),
                                         webp: ImageWebPReader.read(from: url),
                                         nikon: ImageNikonReader.read(from: url),
                                         canon: ImageCanonReader.read(from: url),
                                         apple: ImageAppleReader.read(from: url),
                                         properties: ImagePropertiesReader.read(from: url))
            if metadata.isEmpty == false { return metadata }
        }
        return ImageMetadata()
    }

    /// Same as `read(in:)` if all the files to read have already been read, nil otherwise
    public static func cached(in urls: [URL]) -> ImageMetadata? {
        for url in urls {
            guard let exif = ImageExifReader.cachedExif(at: url),
                  let gps = ImageGpsReader.cachedGps(at: url),
                  let iptc = ImageIptcReader.cachedIptc(at: url),
                  let webp = ImageWebPReader.cachedWebP(at: url),
                  let nikon = ImageNikonReader.cachedNikon(at: url),
                  let canon = ImageCanonReader.cachedCanon(at: url),
                  let apple = ImageAppleReader.cachedApple(at: url),
                  let properties = ImagePropertiesReader.cachedProperties(at: url)
            else { return nil }
            let metadata = ImageMetadata(exif: exif, gps: gps, iptc: iptc, webp: webp, nikon: nikon,
                                         canon: canon, apple: apple, properties: properties)
            if metadata.isEmpty == false { return metadata }
        }
        return ImageMetadata()
    }
}
