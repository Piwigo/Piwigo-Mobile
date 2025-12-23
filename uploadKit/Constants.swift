//
//  Constants.swift
//  uploadKit
//
//  Created by Eddy Lelièvre-Berna on 20/08/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import Photos

// Bundle name
public let uploadKit = Bundle.allFrameworks.first(where: { ($0.bundleIdentifier ?? "").contains("uploadKit")})

// Constants used to manage foreground tasks
let maxNberPreparedUploads = 10             // Maximum number of images prepared in advance
let maxNberOfTransfers = 1                  // Maximum number of transfers executed in parallel
let maxNberOfFailedUploads = 5              // Stop transfers after 5 failures

// Constants used to manage background tasks
let maxCountOfBytesToUpload = 100 * 1024 * 1024  // Up to 100 MB transferred in a series
public let maxNberOfUploadsPerSeries = 500       // i.e. do not add more than 500 requests at a time

// Constants used to name and identify media
let kOriginalSuffix = "-original"
public let kIntentPrefix = "Intent-"
public let kClipboardPrefix = "Clipboard-"
public let kImageSuffix = "-img-"
public let kMovieSuffix = "-mov-"

// Constants returning the list of:
/// - image formats which can be converted with iOS
/// - movie formats which can be converted with iOS
/// See: https://developer.apple.com/documentation/uniformtypeidentifiers/system-declared_uniform_type_identifiers
let acceptedImageExtensions: [String] = {
    var utiTypes: [UTType] = [.ico, .icns,
                              .png, .gif, .jpeg, .webP, .tiff, .bmp, .svg, .rawImage,
                              .heic, .heif]
    if #available(iOS 18.2, *) {
        utiTypes += [.jpegxl]
    }
    return utiTypes.flatMap({$0.tags[.filenameExtension] ?? []})
}()
let acceptedMovieExtensions: [String] = {
    let utiTypes: [UTType] = [.quickTimeMovie,
                              .mpeg, .mpeg2Video, .mpeg2TransportStream,
                              .mpeg4Movie, .appleProtectedMPEG4Video, .avi]
    return utiTypes.flatMap({$0.tags[.filenameExtension] ?? []})
}()

// Constant for producing filename suffixes
let chunkFormatter: NumberFormatter = {
    let numberFormatter = NumberFormatter()
    numberFormatter.numberStyle = .none
    numberFormatter.minimumIntegerDigits = 5
    return numberFormatter
}()
