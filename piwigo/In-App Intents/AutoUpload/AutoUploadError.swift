//
//  AutoUploadError.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/06/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import PwgKit
import PwgCacheKit
import PwgUploadKit

public enum AutoUploadError: Error, Sendable {
    case migrationRequired
    case autoUploadDisabled
    case invalidSource
    case invalidDestination
    case importFailed
}

extension AutoUploadError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .migrationRequired:
            return Localized.migrationRequired
        case .autoUploadDisabled:
            return String(localized: "AutoUploadError_Disabled",
                          comment: "Auto-uploading is disabled in the app settings.")
        case .invalidSource:
            return PwgKitError.autoUploadSourceInvalid.localizedDescription + ": " + Localized.autoUploadSourceInfo
        case .invalidDestination:
            return PwgKitError.autoUploadDestinationInvalid.localizedDescription + ": " + Localized.autoUploadDestinationInfo
        case .importFailed:
            return "Could not create upload requests."
        }
    }
}
