//
//  TagError.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/01/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
//  An enumeration of Tag fetch and consumption errors.

import Foundation

public enum TagError: Error {
    case wrongDataFormat
    case missingData
    case creationError
}

extension TagError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .wrongDataFormat:
            return NSLocalizedString("CoreDataFetch_DigestError",
                                     comment: "Could not digest the fetched data.")
        case .missingData:
            return NSLocalizedString("CoreDataFetch_TagMissingData",
                                     comment: "Found and will discard a tag missing a valid code or name.")
        case .creationError:
            return NSLocalizedString("CoreDataFetch_TagCreateFailed",
                                     comment: "Failed to create a new Tag object.")
        }
    }
}
