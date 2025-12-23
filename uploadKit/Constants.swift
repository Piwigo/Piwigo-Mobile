//
//  Constants.swift
//  uploadKit
//
//  Created by Eddy Lelièvre-Berna on 20/08/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation

// Bundle name
public let uploadKit = Bundle.allFrameworks.first(where: { ($0.bundleIdentifier ?? "").contains("uploadKit")})

// Constants used to name and identify media
public let kOriginalSuffix = "-original"
public let kIntentPrefix = "Intent-"
public let kClipboardPrefix = "Clipboard-"
public let kImageSuffix = "-img-"
public let kMovieSuffix = "-mov-"

// Constants used to manage background tasks
public let maxCountOfBytesToUpload = 100 * 1024 * 1024  // Up to 100 MB transferred in a series
public let maxNberOfUploadsPerSeries = 500              // i.e. do not add more than 500 requests at a time
