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

// Bundle for PwgAPIKit localized strings
public extension Bundle {
    static let pwgAPIKit: Bundle = .module
}

// Shared localized strings
public enum Localized {
    public static func albumCount(_ count: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "albumCount", bundle: .pwgAPIKit, comment: "%lld albums"), count)
    }
    public static func subAlbumCount(_ count: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "subAlbumCount", bundle: .pwgAPIKit, comment: "%lld sub-albums"), count)
    }
    public static func imageCount(_ count: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "imageCount", bundle: .pwgAPIKit, comment: "%lld photos"), count)
    }
    public static func tagCount(_ count: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "tagCount", bundle: .pwgAPIKit, comment: "%lld tags"), count)
    }
    public static func userCount(_ count: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "userCount", bundle: .pwgAPIKit, comment: "%lld users"), count)
    }
    public static func groupCount(_ count: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "groupCount", bundle: .pwgAPIKit, comment: "%lld groups"), count)
    }
    public static func commentCount(_ count: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "commentCount", bundle: .pwgAPIKit, comment: "%lld comments"), count)
    }
}

// Disconnects and asks to update the Piwigo server if version is lower than:
public let pwgMinVersion = "12.0.0"

// At login, invites to update the Piwigo server if version is lower than:
public let pwgRecentVersion = "15.0.0"

// Name and page of the ShareAlbum plugin on piwigo.org, suggested to admin users when not installed
public let pwgShareAlbumPluginName = "ShareAlbum"
public let pwgShareAlbumPluginURL = "https://piwigo.org/ext/index.php?eid=865"

// Name and page of the rotateImage plugin on piwigo.org, suggested to admin users when not installed
public let pwgRotateImagePluginName = "rotateImage"
public let pwgRotateImagePluginURL = "https://piwigo.org/ext/index.php?eid=578"

// Custom HTTP headers
public let HTTPCatID = "X-PWG-categoryID"       // Header for cancelling tasks related with a specific album
public let HTTPAPIKey = "X-PIWIGO-API"          // Header used by API keys
