//
//  Constants.swift
//  PwgUIKit
//
//  Created by Eddy Lelièvre-Berna on 19/05/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import Foundation

// Swift Package Version
public enum PwgUIKit {
    public static let version = "1.0.0"
    public static let build = 1
}

// Bundle for PwgUIKit localised strings
public extension Bundle {
    static let pwgUIKit: Bundle = .module
}

// Localized strings
public enum Localized {
    public static let loading = String(localized: "loadingHUD_label", bundle: .pwgUIKit, comment:"Loading…")
    public static let yes = String(localized: "alertYesButton", bundle: .pwgUIKit, comment: "Yes")
    public static let cancel = String(localized: "alertCancelButton", bundle: .pwgUIKit, comment: "Cancel")
    public static let dismiss = String(localized: "alertDismissButton", bundle: .pwgUIKit, comment: "Dismiss")
    public static let recentAlbums = String(localized: "recentAlbums", bundle: .pwgUIKit, comment: "Recent Albums")
}

// Constants
/// - Preferred popover view width on iPad
public let pwgPadSubViewWidth = CGFloat(425.0)
/// - Preferred Settings view width on iPad
public let pwgPadSettingsWidth = CGFloat(512.0)
