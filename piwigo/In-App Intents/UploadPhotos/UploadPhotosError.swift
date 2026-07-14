//
//  UploadPhotosError.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 03/07/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import Foundation
import PwgCacheKit

public enum UploadPhotosError: Error, Sendable {
    case migrationRequired
    case noPhotos
    case invalidAlbum
    case pdfNotAccepted
    case importFailed
}

extension UploadPhotosError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .migrationRequired:
            return Localized.migrationRequired
        case .noPhotos:
            return String(localized: "UploadPhotosError_NoPhotos", table: "In-AppIntents",
                          comment: "No photo or video was provided to the shortcut.")
        case .invalidAlbum:
            return String(localized: "UploadPhotosError_InvalidAlbum", table: "In-AppIntents",
                          comment: "You do not have permission to upload to this album.")
        case .pdfNotAccepted:
            return String(localized: "UploadPhotosError_PdfNotAccepted", table: "In-AppIntents",
                          comment: "This Piwigo server does not accept PDF files.")
        case .importFailed:
            return "Could not create upload requests."
        }
    }
}
