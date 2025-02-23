//
//  PwgSessionError.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 13/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

public enum PwgSessionError: Error {
    // App errors
    case authenticationFailed
    case emptyJSONobject
    case failedToPrepareDownload
    case incompatiblePwgVersion
    case invalidCredentials
    case invalidJSONobject
    case invalidMethod
    case invalidParameter
    case invalidURL
    case missingParameter
    case networkUnavailable
    case unexpectedError
    case wrongJSONobject

    // Piwigo server errors
    case otherError(code: Int, msg: String)
}

extension PwgSessionError: Equatable {
    static public func ==(lhs: PwgSessionError, rhs: PwgSessionError) -> Bool {
        switch (lhs, rhs) {
        case (.authenticationFailed, .authenticationFailed),
             (.emptyJSONobject, .emptyJSONobject),
             (.failedToPrepareDownload, .failedToPrepareDownload),
             (.incompatiblePwgVersion, .incompatiblePwgVersion),
             (.invalidCredentials, .invalidCredentials),
             (.invalidJSONobject, .invalidJSONobject),
             (.invalidMethod, .invalidMethod),
             (.invalidParameter, .invalidParameter),
             (.invalidURL, .invalidURL),
             (.missingParameter, .missingParameter),
             (.networkUnavailable, .networkUnavailable),
             (.unexpectedError, .unexpectedError),
             (.wrongJSONobject, .wrongJSONobject):
            return true
        case (let .otherError(lhsCode, _), let .otherError(rhsCode, _)):
            return lhsCode == rhsCode
        default:
            return false
        }
    }
}

extension PwgSessionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return NSLocalizedString("sessionStatusError_message",
                                     comment: "Failed to authenticate with server.\nTry logging in again.")
        case .emptyJSONobject:
            return NSLocalizedString("PiwigoServer_emptyJSONobject",
                                     comment: "Piwigo server did return an empty JSON object.")
        case .failedToPrepareDownload:
            return NSLocalizedString("downloadImageFail_title",
                                     comment: "Download Fail")
        case .incompatiblePwgVersion:
            return NSLocalizedString("serverVersionNotCompatible_message",
                                     comment: "Your server version is %@. Piwigo Mobile only supports a version of at least %@. Please update your server to use Piwigo Mobile.")
        case .invalidCredentials:
            return NSLocalizedString("loginError_message",
                                     comment: "The username and password don't match on the given server")
        case .invalidJSONobject:
            return NSLocalizedString("PiwigoServer_invalidJSONobject",
                                     comment: "Piwigo server did not return a valid JSON object.")
        case .invalidMethod:
            return NSLocalizedString("serverInvalidMethodError_message",
                                     comment: "Failed to call server method.")
        case .invalidParameter:
            return NSLocalizedString("serverUnknownError_message",
                                     comment: "Unexpected error encountered while calling server method with provided parameters.")
        case .invalidURL:
            return NSLocalizedString("serverURLerror_message",
                                     comment: "Please correct the Piwigo web server address.")
        case .missingParameter:
            return NSLocalizedString("serverMissingParamError_message",
                                     comment: "Failed to execute server method with missing parameter.")
        case .wrongJSONobject:
            return NSLocalizedString("PiwigoServer_wrongJSONobject",
                                     comment: "Could not digest JSON object returned by Piwigo server.")
        case .networkUnavailable:
            return NSLocalizedString("internetErrorGeneral_broken",
                                     comment: "Sorry, the communication was broken.\nTry logging in again.")
        case .otherError(code: let code, msg: let msg):
            return String(format: "Error %d: ", code) + msg
        
        case .unexpectedError:
            fallthrough
        default:
            return NSLocalizedString("serverUnknownError_message",
                                     comment: "Unexpected error encountered while calling server method with provided parameters.")
        }
    }
}

extension PwgSession {
    // Always return an error message, localized or not.
    /// Updated on 23 February 2025 — Piwigo 15.3.0 using BBEdit multi-file search "PwgError"
    public func localizedError(for errorCode: Int, errorMessage: String = "") -> Error {
        switch errorCode {
        case 400:
            // Messages not translated in Piwigo:
            /// - Unknown request format
            if errorMessage.isEmpty {
                return PwgSessionError.invalidMethod
            }
        case 401:
            // Messages not translated in Piwigo:
            /// - Access denied
            /// - formats are disabled
            /// - not permitted
            /// - Piwigo extensions install/update system is disabled
            /// - Piwigo extensions install/update/delete system is disabled
            /// - unexpected format extension of file … (authorized extensions: …)
            // Messages translated in Piwigo:
            /// - Webmaster status is required.
            if errorMessage.isEmpty {
                return PwgSessionError.invalidMethod
            }
        case 403:
            // Messages not translated in Piwigo:
            /// - Category … does not exist
            /// - Category … is not a virtual category, you cannot move it
            /// - Comments are disabled
            /// - Forbidden or rate not in …
            /// - Invalid category_id input parameter, no category to move
            /// - invalid extension type
            /// - Invalid parameters
            /// - Invalid security token
            /// - No image found
            /// - Only webmasters can change password of other "webmaster/admin" users
            /// - Only webmasters can grant "webmaster/admin" status
            /// - This user cannot become a main user because he is not a webmaster.
            /// - Unknown comment action…
            /// - Unknown parent category id
            /// - User must be logged in.
            /// - You cannot perform this action
            /// - implode('; ', $page['errors']) i.e. could not move categories
            // Messages translated in Piwigo:
            /// - Your comment has NOT been registered because it did not pass the validation rules
            /// - Webmaster status is required.
            if errorMessage.isEmpty {
                return PwgSessionError.invalidParameter
            }
        case 404:
            // Messages not translated in Piwigo:
            /// - cat_id { … } not found
            /// - category_id not found
            /// - image_id not found
            /// - Invalid image_id or access denied
            /// - No format found for the id(s) given
            /// - This image is not associated to this category
            if errorMessage.isEmpty {
                return PwgSessionError.invalidParameter
            }
        case 405:
            // Messages not translated in Piwigo:
            /// - The image (file) is missing
            /// - This method requires HTTP POST
            if errorMessage.isEmpty {
                return PwgSessionError.invalidMethod
            }
        case 500:
            // Messages not translated in Piwigo:
            /// - an error has occured while writting chunk … for …
            /// - create_virtual_category error
            /// - error during buffer directory creation
            /// - error while creating merged …
            /// - error while locking merged …
            /// - error while merging chunk …
            /// - file already exists
            /// - invalid parameter photo_deletion_mode
            /// - MD5 checksum chunk file mismatched
            /// - [merge_chunks] error while trying to remove existing…
            /// - [merge_chunks] error while writting chunks for…
            /// - [one of the errors returned after failing an upload]
            /// - [ws_images_setInfo] invalid parameter multiple_value_mode …, possible values are {replace, append}.
            /// - [ws_images_setInfo] invalid parameter single_value_mode … , possible values are {fill_if_empty, replace}.
            /// - [ws_images_setInfo] updating "file" is forbidden on photos added by synchronization
            /// - … the following categories are unknown:…
            /// - $errors (in pwg.extensions.php)
            if errorMessage.isEmpty {
                return PwgSessionError.unexpectedError
            }
        case 501:   // i.e. WS_ERR_INVALID_METHOD
            // Messages not translated in Piwigo:
            /// - Method name is not valid
            /// - Missing "method" name
            if errorMessage.isEmpty {
                return PwgSessionError.invalidMethod
            }
        case 999:
            // Messages not translated in Piwigo:
            /// - Invalid username/password
            if errorMessage.contains("Invalid username/password") {
                return PwgSessionError.invalidCredentials
            }
        case 1002:  // i.e. WS_ERR_MISSING_PARAM
            // Messages not translated in Piwigo:
            /// - Missing parameters: …
            if errorMessage.isEmpty {
                return PwgSessionError.invalidParameter
            }
        case 1003:  // i.e. WS_ERR_INVALID_PARAM
            // Messages not translated in Piwigo:
            /// - All groups does not exist.
            /// - All tags does not exist.
            /// - Cannot use both recursive and limit parameters at the same time
            /// - date_created_custom, invalid option …
            /// - date_created_custom is missing
            /// - date_created_custom provided date_created_preset is not custom
            /// - date_posted_custom, invalid option …
            /// - date_posted_custom is missing
            /// - date_posted_custom provided date_posted_preset is not custom
            /// - Do not use tag_list and tag_ids at the same time.
            /// - invalid user_id
            /// - Invalid image_id …
            /// - Invalid input parameter min_register
            /// - Invalid input parameter max_register
            /// - Invalid input parameter order
            /// - Invalid language
            /// - Invalid level
            /// - Invalid original_sum
            /// - Invalid param 'visible' or 'commentable'
            /// - Invalid parameter added_by
            /// - Invalid param name #…
            /// - Invalid parameter allwords_fields
            /// - Invalid parameter allwords_mode
            /// - Invalid parameter categories
            /// - Invalid parameter date_created_preset
            /// - Invalid parameter date_posted_preset
            /// - Invalid parameter filetypes
            /// - Invalid parameter ratios
            /// - Invalid parameter tags
            /// - Invalid parameter tags_mode
            /// - Invalid search_id input parameter.
            /// - Invalid status, only public/private
            /// - Invalid thumbnail_size
            /// - Invalid status
            /// - Invalid theme
            /// - Invalid types
            /// - Name field must not be empty
            /// - Parameter must be a boolean or only contain booleans
            /// - Parameter must be a … integer or only contain … integers
            /// - Parameter must be a … float or only contain … floats
            /// - Parameter must be scalar
            /// - Password reset is not allowed for this user
            /// - rank is missing
            /// - Requested method does not exist
            /// - This group does not exist.
            /// - This name is already token
            /// - This name is already taken.
            /// - This name is already used by another group.
            /// - This search does not exist.
            /// - This tag does not exist.
            /// - This user does not exist.
            /// - Too many parameters, provide cat_id OR user_id OR group_id
            /// - you need to provide all sub-category ids for a given category
            /// - $creation_output['error'] (in pwg.tags.php)
            /// - $error (in pwg.users.php)
            /// - $errors[0] (in pwg.users.php)
            // Messages translated in Piwigo:
            /// - html tags are not allowed in login
            /// - The passwords do not match
            /// - this login is already used
            if errorMessage.isEmpty {
                return PwgSessionError.invalidParameter
            }
        default:
            break
        }
        return PwgSessionError.otherError(code: errorCode, msg: errorMessage)
    }
}
