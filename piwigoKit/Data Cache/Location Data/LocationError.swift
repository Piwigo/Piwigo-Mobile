//
//  LocationError.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 17/04/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
//  An enumeration of Location fetch and consumption errors.

import Foundation

public enum LocationError: Error {
    case creationError
    case missingData
}

extension LocationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingData:
            return NSLocalizedString("CoreDataFetch_LocationMissingData",
                                     comment: "Found and will discard a location missing a valid identifier.")
        case .creationError:
            return NSLocalizedString("CoreDataFetch_LocationCreateFailed",
                                     comment: "Failed to create a new Location object.")
        }
    }
}
