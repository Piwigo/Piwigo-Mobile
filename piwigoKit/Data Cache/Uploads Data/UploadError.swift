//
//  UploadError.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/03/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
//  An enumeration of Tag fetch and consumption errors.

import Foundation

public enum UploadError: Error {
    case wrongDataFormat
    case creationError
    case deletionError
    case missingData
    case missingAsset
    case wrongJSONobject
    case missingFile
}

extension UploadError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .wrongDataFormat:
            return NSLocalizedString("CoreDataFetch_DigestError",
                                     comment: "Could not digest the fetched data.")
        case .missingData:
            return NSLocalizedString("CoreDataFetch_UploadMissingData",
                                     comment: "Found and will discard an upload missing a valid identifier.")
        case .creationError:
            return NSLocalizedString("CoreDataFetch_UploadCreateFailed",
                                     comment: "Failed to create a new Upload object.")
        case .deletionError:
            return NSLocalizedString("CoreDataFetch_UploadDeleteFailed",
                                     comment: "Failed to delete an Upload object.")
        case .missingAsset:
            return NSLocalizedString("CoreDataFetch_UploadMissingAsset",
                                     comment: "Failed to retrieve photo")
        case .wrongJSONobject:
            return NSLocalizedString("PiwigoServer_wrongJSONobject",
                                     comment: "Could not digest JSON object returned by Piwigo server.")
        case .missingFile:
            return ""
        }
    }
}
