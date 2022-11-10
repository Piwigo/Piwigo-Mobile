//
//  AlbumError.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 11/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

public enum AlbumError: Error {
    case fetchFailed
    case wrongDataFormat
    case missingData
    case creationError
    case notFound
}

extension AlbumError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .fetchFailed:
            return NSLocalizedString("CoreDataFetch_AlbumError",
                                     comment: "Fetch albums error!")
        case .wrongDataFormat:
            return NSLocalizedString("CoreDataFetch_DigestError",
                                     comment: "Could not digest the fetched data.")
        case .missingData:
            return NSLocalizedString("CoreDataFetch_AlbumMissingData",
                                     comment: "Found and will discard an album missing a valid ID or name.")
        case .creationError:
            return NSLocalizedString("CoreDataFetch_AlbumCreateFailed",
                                     comment: "Failed to create a new Album object.")
        case .notFound:
            return NSLocalizedString("CoreData_AlbumNotFound",
                                     comment: "Album not in persistent cache.")
        }
    }
}
