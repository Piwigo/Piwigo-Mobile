//
//  Constants.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 20/08/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import Photos

// Bundle name
public let piwigoKit = Bundle.allFrameworks.first(where: { ($0.bundleIdentifier ?? "").contains("piwigoKit")})

// Disconnects and asks to update the Piwigo server if version is lower than:
public let pwgMinVersion = "2.10.0"

// At login, invites to update the Piwigo server if version is lower than:
public let pwgRecentVersion = "14.0.0"

// Custom HTTP headers
public let HTTPCatID = "X-PWG-categoryID"       // Header for cancelling tasks related with a specific album
public let HTTPAPIKey = "X-PIWIGO-API"          // Header used by API keys

// Accepts the image formats supported by UIImage
let acceptedTypes: String = {
    // Image types
    let imageTypes = [UTType.heic, UTType.heif, UTType.ico, UTType.icns, UTType.png, UTType.gif, UTType.jpeg, UTType.webP, UTType.tiff, UTType.bmp, UTType.svg, UTType.rawImage].compactMap {$0.tags[.mimeType]}.flatMap({$0})
    var acceptedTypes = imageTypes.map({$0 + " ,"}).reduce("", +)
    
    // Add text types for handling Piwigo errors and redirects
    acceptedTypes += "text/plain, text/html"
    return acceptedTypes
}()
