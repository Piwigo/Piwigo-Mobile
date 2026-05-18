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

// Bundle for PwgCacheKit localised strings
public extension Bundle {
    static let pwgCacheKit: Bundle = .module
}

// Name extension of thumbnails optimised for the device
public let optimisedImageNameExtension = "-opt"
