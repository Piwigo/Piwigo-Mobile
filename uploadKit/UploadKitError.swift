//
//  UploadKitError.swift
//  uploadKit
//
//  Created by Eddy Lelièvre-Berna on 20 August 2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation

public enum UploadKitError: Error {
    case unacceptedImageFormat
    case unacceptedAudioFormat
    case unacceptedVideoFormat
    case unacceptedDataFormat
    
    case autoUploadSourceInvalid
    case autoUploadDestinationInvalid
    
    case cannotStripPrivateMetadata
}

extension UploadKitError: LocalizedError {
    // When adopting iOS 16 as minimum target, migrate to LocalizedStringResource()
    public var errorDescription: String? {
        switch self {
        case .unacceptedImageFormat:
            return String(localized: "imageFormat_error", bundle: uploadKit,
                          comment: "Photo file format not supported.")
        case .unacceptedAudioFormat:
            return String(localized: "audioFormat_error", bundle: uploadKit,
                          comment: "Sorry, audio files are not supported by Piwigo Mobile yet.")
        case .unacceptedVideoFormat:
            return String(localized: "videoFormat_error", bundle: uploadKit,
                          comment: "Video file format not supported.")
        case .unacceptedDataFormat:
            return String(localized: "otherFormat_error", bundle: uploadKit,
                          comment: "File format not supported.")
        
        case .autoUploadSourceInvalid:
            return String(localized: "settings_autoUploadSourceInvalid", bundle: uploadKit, comment: "Invalid source album")
        case .autoUploadDestinationInvalid:
            return String(localized: "settings_autoUploadDestinationInvalid", bundle: uploadKit, comment: "Invalid destination album")
        
        case .cannotStripPrivateMetadata:
            return String(localized: "shareMetadataError_message", bundle: uploadKit, comment: "Cannot strip private metadata")
        }
    }
}
