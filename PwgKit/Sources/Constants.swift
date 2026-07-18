//
//  Constants.swift
//  PwgKit
//
//  Created by Eddy Lelièvre-Berna on 20/08/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import Photos

// Swift Package Version
public enum PwgKit {
    public static let version = "4.0.0"
    public static let build = 677
}

// Bundle for PwgKit localized strings
public extension Bundle {
    static let pwgKit: Bundle = .module
}

// Shared localized strings
public enum Localized {
    public static let tabBar_albums = String(localized: "tabBar_albums", bundle: .pwgKit, comment: "Albums")
    public static let pdfNotAccepted = String(localized: "pdfNotAccepted", bundle: .pwgKit,
                                              comment: "This Piwigo server does not accept PDF files.")
}

// URL scheme for deep links from the share extension to the app
/// The debug and release versions use different schemes so that
/// the share extension always opens the app it was embedded in.
/// Must match CFBundleURLSchemes in Info-debug.plist and Info.plist.
#if DEBUG
public let pwgURLScheme = "piwigo-debug"
#else
public let pwgURLScheme = "piwigo"
#endif

// Image types which can be converted with iOS
/// PNG format in priority in case where JPEG is also available
/// See: https://developer.apple.com/documentation/uniformtypeidentifiers/system-declared_uniform_type_identifiers
public let acceptedImageTypes: [UTType] = {
    var utiTypes: [UTType] = [.heic, .heif, .webP,
                              .png, .jpeg, .tiff, .gif, .bmp, .svg, .rawImage,
                              .ico, .icns]
    if #available(iOS 18.0, *) {
        utiTypes += [.dng, .exr]
    }
    if #available(iOS 18.2, *) {
        utiTypes += [.jpegxl]
    }
    return utiTypes
}()

// Movie types which can be converted with iOS
/// See: https://developer.apple.com/documentation/uniformtypeidentifiers/system-declared_uniform_type_identifiers
public let acceptedMovieTypes: [UTType] = {
    var utiTypes: [UTType] = [.quickTimeMovie,
                              .mpeg, .mpeg2Video, .mpeg2TransportStream,
                              .mpeg4Movie, .appleProtectedMPEG4Video, .avi]
    if #available(iOS 18.0, *) {
        utiTypes += [.heics]
    }
    return utiTypes
}()
