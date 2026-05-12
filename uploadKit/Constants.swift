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
public extension Bundle {
    static let uploadKit = Bundle.allFrameworks.first(where: { ($0.bundleIdentifier ?? "").contains("uploadKit")})
}

// Constants used to manage background tasks
public let maxNberOfUploadsPerBckgTask = 25     // Queue upload requests to prepare and transfer in batches of 25
public let maxNberOfQueuedAutoUploads = 500     // i.e. do not queue more than 500 requests at a time

// Constants used to name and identify media
public let kClipboardPrefix = "pwgClipboard-"   // File extracted from the pasteboard
public let kSharedPrefix = "pwgShared-"         // File shared from another app
public let kIntentPrefix = "pwgIntent-"         // File selected by the shortcut app
public let kImageSuffix = "-img-"
public let kMovieSuffix = "-mov-"
let kOriginalSuffix = "-original"

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
