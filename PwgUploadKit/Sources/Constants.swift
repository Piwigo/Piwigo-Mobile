//
//  Constants.swift
//  PwgUploadKit
//
//  Created by Eddy Lelièvre-Berna on 20/08/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import Photos

// Swift Package Version
public enum PwgUploadKit {
    public static let version = "3.0.0"
    public static let build = 491
}

// Bundle for PwgUploadKit localized strings
public extension Bundle {
    static let pwgUploadKit: Bundle = .module
}

// Localized strings
public enum Localized {
    public static let autoUploadSourceInfo = String(localized: "settings_autoUploadSourceInfo", bundle: .pwgUploadKit,
                                                    comment: "Please select the album…")
    public static let autoUploadDestinationInfo = String(localized: "settings_autoUploadDestinationInfo", bundle: .pwgUploadKit,
                                                         comment: "Please select the album…")
    public static let preparingUploads = String(localized: "preparingUploads", bundle: .pwgUploadKit,
                                                comment: "Preparing uploads…")
}

// Constants used to manage background tasks
public let maxNberOfUploadsPerBckgTask = 25     // Queue upload requests to prepare and transfer in batches of 25
public let maxNberOfQueuedAutoUploads = 500     // i.e. do not queue more than 500 requests at a time

// Constants used to name and identify media
public let kClipboardPrefix = "pwgClipboard-"   // File extracted from the pasteboard
public let kSharedPrefix = "pwgShared-"         // File shared by another app
public let kIntentPrefix = "pwgIntent-"         // File selected by the shortcut app
public let kImageSuffix = "-img-"
public let kMovieSuffix = "-mov-"
public let kPdfSuffix = "-pdf-"
let kOriginalSuffix = "-original"

// Constant for producing filename suffixes
let chunkFormatter: NumberFormatter = {
    let numberFormatter = NumberFormatter()
    numberFormatter.numberStyle = .none
    numberFormatter.minimumIntegerDigits = 5
    return numberFormatter
}()
