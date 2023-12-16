//
//  PwgSessionErrors.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 13/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

public enum PwgSessionErrors: Error {
    case networkUnavailable
    case emptyJSONobject
    case invalidJSONobject
    case wrongJSONobject
    case authenticationFailed
    case unexpectedError
    case incompatiblePwgVersion
    
    // Piwigo server errors
    case invalidMethod          // 501
    case invalidCredentials     // 999
    case missingParameter       // 1002
    case invalidParameter       // 1003
}

extension PwgSessionErrors: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return NSLocalizedString("internetErrorGeneral_broken",
                                     comment: "Sorry, the communication was broken.\nTry logging in again.")
        case .emptyJSONobject:
            return NSLocalizedString("PiwigoServer_emptyJSONobject",
                                     comment: "Piwigo server did return an empty JSON object.")
        case .invalidJSONobject:
            return NSLocalizedString("PiwigoServer_invalidJSONobject",
                                     comment: "Piwigo server did not return a valid JSON object.")
        case .wrongJSONobject:
            return NSLocalizedString("PiwigoServer_wrongJSONobject",
                                     comment: "Could not digest JSON object returned by Piwigo server.")
        case .authenticationFailed:
            return NSLocalizedString("sessionStatusError_message",
                                     comment: "Failed to authenticate with server.\nTry logging in again.")
        case .unexpectedError:
            return NSLocalizedString("serverUnknownError_message",
                                     comment: "Unexpected error encountered while calling server method with provided parameters.")
        case .invalidMethod:
            return NSLocalizedString("loginError_message",
                                     comment: "The username and password don't match on the given server.")
        case .invalidCredentials:
            return NSLocalizedString("loginError_message",
                                     comment: "The username and password don't match on the given server")
        case .missingParameter:
            return NSLocalizedString("serverMissingParamError_message",
                                     comment: "Failed to execute server method with missing parameter.")
        case .invalidParameter:
            return NSLocalizedString("serverUnknownError_message",
                                     comment: "Unexpected error encountered while calling server method with provided parameters.")
        case .incompatiblePwgVersion:
            return NSLocalizedString("serverVersionNotCompatible_message",
                                     comment: "Your server version is %@. Piwigo Mobile only supports a version of at least %@. Please update your server to use Piwigo Mobile.")
        }
    }
}

extension PwgSession {
    public func localizedError(for errorCode: Int, errorMessage: String = "") -> Error {
        switch errorCode {
        case 501:
            return PwgSessionErrors.invalidMethod
        case 999:
            return PwgSessionErrors.invalidCredentials
        case 1002:
            return PwgSessionErrors.missingParameter
        case 1003:
            return PwgSessionErrors.invalidParameter
        default:
            let error = NSError(domain: "Piwigo", code: errorCode,
                                userInfo: [NSLocalizedDescriptionKey : errorMessage])
            return error as Error
        }
    }
}
