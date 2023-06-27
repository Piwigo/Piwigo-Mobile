//
//  ImageSessionErrors.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/01/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation

public enum ImageSessionError: Error {
    case networkUnavailable
}

extension ImageSessionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return NSLocalizedString("internetErrorGeneral_broken",
                                     comment: "Sorry, the communication was broken.\nTry logging in again.")
        }
    }
}
