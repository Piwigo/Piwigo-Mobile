//
//  TagError.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/01/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
//  An enumeration of Tag fetch and consumption errors.

import Foundation

enum TagError: Error {
    case networkUnavailable
    case wrongDataFormat
    case missingData
    case creationError
}

extension TagError: LocalizedError {
    public var localizedDescription: String {
        switch self {
        case .networkUnavailable:
            return NSLocalizedString("internetErrorGeneral_broken", comment: "Sorry, the communication was broken.\nTry logging in again.")
        case .wrongDataFormat:
            return NSLocalizedString("CoreDataFetch_DigestError", comment: "Could not digest the fetched data.")
        case .missingData:
            return NSLocalizedString("CoreDataFetch_TagMissingData", comment: "Found and will discard a tag missing a valid code or name.")
        case .creationError:
            return NSLocalizedString("CoreDataFetch_TagCreateFailed", comment: "Failed to create a new Tag object.")
        }
    }
}
