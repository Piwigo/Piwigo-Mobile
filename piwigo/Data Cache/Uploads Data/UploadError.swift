//
//  UploadError.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/03/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
//  An enumeration of Tag fetch and consumption errors.

import Foundation

enum UploadError: Error {
    case networkUnavailable
    case wrongDataFormat
    case creationError
    case missingData
    case missingAsset
}

extension UploadError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return NSLocalizedString("internetErrorGeneral_broken", comment: "Sorry, the communication was broken.\nTry logging in again.")
        case .wrongDataFormat:
            return NSLocalizedString("CoreDataFetch_DigestError", comment: "Could not digest the fetched data.")
        case .missingData:
            return NSLocalizedString("CoreDataFetch_UploadMissingData", comment: "Found and will discard an upload missing a valid identifier.")
        case .creationError:
            return NSLocalizedString("CoreDataFetch_UploadCreateFailed", comment: "Failed to create a new Upload object.")
        case .missingAsset:
            return NSLocalizedString("CoreDataFetch_UploadMissingAsset", comment: "Failed to retrieve photo")
        }
    }
}
