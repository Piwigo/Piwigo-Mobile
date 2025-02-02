//
//  PwgSessionError.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 13/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

public enum PwgSessionError: Error {
    case networkUnavailable
    case emptyJSONobject
    case invalidJSONobject
    case wrongJSONobject
    case authenticationFailed
    case unexpectedError
    case incompatiblePwgVersion
    case failedToPrepareDownload

    // Piwigo server errors
    case invalidURL             // 404
    case invalidMethod          // 501
    case invalidCredentials     // 999
    case missingParameter       // 1002
    case invalidParameter       // 1003
}

extension PwgSessionError: LocalizedError {
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
            return NSLocalizedString("serverInvalidMethodError_message",
                                     comment: "Failed to call server method.")
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
        case .invalidURL:
            return NSLocalizedString("serverURLerror_message", comment: "Please correct the Piwigo web server address.")
        case .failedToPrepareDownload:
            return NSLocalizedString("downloadImageFail_title", comment: "Download Fail")
        }
    }
}

extension PwgSession {
    public func localizedError(for errorCode: Int, errorMessage: String = "") -> Error {
        if errorMessage.isEmpty {
            switch errorCode {
            case 401, 402, 403, 999:
                return PwgSessionError.invalidMethod
            case 400, 404, 405:
                return PwgSessionError.invalidParameter
            case 500:
                return PwgSessionError.unexpectedError
            case 501:
                return PwgSessionError.invalidMethod
            case 1002:
                return PwgSessionError.missingParameter
            case 1003:
                return PwgSessionError.invalidParameter
            default:
                let error = NSError(domain: "Piwigo", code: errorCode,
                                    userInfo: [NSLocalizedDescriptionKey : errorMessage])
                return error as Error
            }
        } else {
            let error = NSError(domain: "Piwigo", code: errorCode,
                                userInfo: [NSLocalizedDescriptionKey : errorMessage])
            return error as Error
        }
    }
}
