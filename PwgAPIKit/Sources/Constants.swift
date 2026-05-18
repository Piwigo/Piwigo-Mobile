//
//  Constants.swift
//  PwgAPIKit
//
//  Created by Eddy Lelièvre-Berna on 20/08/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import Photos

// Swift Package Version
public enum PwgAPIKit {
    public static let version = "4.0.0"
    public static let build = 677
}

// Bundle for PwgAPIKit localised strings
public extension Bundle {
    static let pwgAPIKit: Bundle = .module
}

// Disconnects and asks to update the Piwigo server if version is lower than:
public let pwgMinVersion = "12.0.0"

// At login, invites to update the Piwigo server if version is lower than:
public let pwgRecentVersion = "15.0.0"

// Custom HTTP headers
public let HTTPCatID = "X-PWG-categoryID"       // Header for cancelling tasks related with a specific album
public let HTTPAPIKey = "X-PIWIGO-API"          // Header used by API keys

// Accepts the image formats supported by UIImage
public let acceptedTypes: String = {
    // Image types
    let imageTypes = [UTType.heic, UTType.heif, UTType.ico, UTType.icns, UTType.png, UTType.gif, UTType.jpeg, UTType.webP, UTType.tiff, UTType.bmp, UTType.svg, UTType.rawImage].compactMap {$0.tags[.mimeType]}.flatMap({$0})
    var acceptedTypes = imageTypes.map({$0 + " ,"}).reduce("", +)
    
    // Add text types for handling Piwigo errors and redirects
    acceptedTypes += "text/plain, text/html"
    return acceptedTypes
}()
