//
//  Constants.swift
//  PwgCacheKit
//
//  Created by Eddy Lelièvre-Berna on 20/08/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import Photos

// Swift Package Version
public enum PwgCacheKit {
    public static let version = "4.0.0"
    public static let build = 677
}

// Bundle for PwgCacheKit localized strings
public extension Bundle {
    static let pwgCacheKit: Bundle = .module
}

// Localized strings
public enum Localized {
    public static let error = String(localized: "errorHUD_label", bundle: .pwgCacheKit, comment: "Error")
    public static let migrationRequired = String(localized: "CoreData_MigrationRequired", bundle: .pwgCacheKit,
                                                 comment: "The persistent database of your Piwigo data requires migration. Please launch the application.")
}

// Name extension of thumbnails optimised for the device
public let optimisedImageNameExtension = "-opt"

// Appended to the PHAsset identifier to name the upload files of the video half of a Live Photo,
// so that both halves of the same asset get distinct files (see UploadProperties.fileKey).
// Never used to look up a PHAsset: the identifier itself is stored unchanged.
public let kLivePhotoMovieSuffix = "-livemov"
