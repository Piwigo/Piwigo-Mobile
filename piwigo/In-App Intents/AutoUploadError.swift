//
//  AutoUploadError.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/06/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import PwgKit
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
            return String(localized: "CoreData_MigrationRequired",
                                     comment: "The persistent database of your Piwigo data requires migration. Please launch the application.")
        case .autoUploadDisabled:
            return String(localized: "AutoUploadError_Disabled",
                                     comment: "Auto-uploading is disabled in the app settings.")
        case .invalidSource:
            return PwgKitError.autoUploadSourceInvalid.localizedDescription + ": " +
                   String(localized: "settings_autoUploadSourceInfo", bundle: .pwgUploadKit, comment: "Please select the album…")
        case .invalidDestination:
            return PwgKitError.autoUploadDestinationInvalid.localizedDescription + ": " +
                   String(localized: "settings_autoUploadDestinationInfo", bundle: .pwgUploadKit, comment: "Please select the album…")
        case .importFailed:
            return "Could not create upload requests."
        }
    }
}
