//
//  ImageError.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 18/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

public enum ImageError: Error {
    case fetchFailed
    case wrongDataFormat
    case missingData
    case creationError
}

extension ImageError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .fetchFailed:
            return NSLocalizedString("CoreDataFetch_ImageError",
                                     comment: "Fetch photos/videos error!")
        case .wrongDataFormat:
            return NSLocalizedString("CoreDataFetch_DigestError",
                                     comment: "Could not digest the fetched data.")
        case .missingData:
            return NSLocalizedString("CoreDataFetch_ImageMissingData",
                                     comment: "Found and will discard a photo/video missing a valid ID or URL.")
        case .creationError:
            return NSLocalizedString("CoreDataFetch_ImageCreateFailed",
                                     comment: "Failed to create a new Image object.")
        }
    }
}
