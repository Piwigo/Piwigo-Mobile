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
    case creationError
    case missingData
}

extension UploadError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingData:
            return NSLocalizedString("CoreDataFetch_UploadMissingData", comment: "Found and will discard an upload missing a valid identifier.")
        case .creationError:
            return NSLocalizedString("CoreDataFetch_UploadCreateFailed", comment: "Failed to create a new Upload object.")
        }
    }
}
