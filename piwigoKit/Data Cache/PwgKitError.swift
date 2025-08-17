//
//  PwgKitError.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 13/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

public enum PwgKitError: Error {
    // Error types
    case decodingFailed(innerError: DecodingError)
    case invalidStatusCode(statusCode: Int)
    case requestFailed(innerError: URLError)
    case otherError(innerError: Error)

    // Piwigo errors
    case pwgError(code: Int, msg: String)

    // Server errors
    case wrongServerURL
    case serverCreationError

    // User errors
    case emptyUsername
    case unknownUserStatus
    case userCreationError
    
    // Album errors
    case fetchAlbumFailed
    case missingAlbumData
    case albumCreationError
    case albumNotFound

    // Image error
    case fetchImageFailed
    case missingImageData
    case creationImageError

    // Tag errors
    case fetchTagFailed
    case missingTagData
    case tagCreationError

    // Location errors
    case locationCreationError
    case missingLocationData

    // Upload errors
    case uploadCreationError
    case uploadDeletionError
    case missingUploadData
    case missingAsset
    case missingUploadFile

    // Network errors
    case authenticationFailed
    case invalidResponse
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
    case wrongDataFormat
    case wrongJSONobject
}

extension PwgKitError {
    // Errors that should lead to a logout
    public var requiresLogout: Bool {
        switch self {
        case .authenticationFailed,
             .incompatiblePwgVersion,
             .invalidCredentials,
             .invalidURL:
            return true
        default:
            return false
        }
    }
    
    public var failedAuthentication: Bool {
        switch self {
        case .authenticationFailed,
             .invalidCredentials:
            return true
        default:
            return false
        }
    }

    public var incompatibleVersion: Bool {
        switch self {
        case .incompatiblePwgVersion:
            return true
        default:
            return false
        }
    }
    
    public var pluginMissing: Bool {
        switch self {
        case (let .pwgError(code, _)):
            return code == 501 ? true : false
        default:
            return false
        }
    }
    
    public var hasMissingParameter: Bool {
        switch self {
        case .missingParameter:
            return true
        default:
            return false
        }
    }
}

extension PwgKitError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        // Server errors
        case .wrongServerURL:
            return NSLocalizedString("serverURLerror_title", comment: "Incorrect URL")
        case .serverCreationError:
            return NSLocalizedString("CoreData_ServerCreateFailed",
                                     comment: "Failed to create a new Server object.")

        // User errors
        case .emptyUsername:
            return NSLocalizedString("CoreDataFetch_UserMissingData",
                                     comment: "Will discard a user account missing a valid username.")
        case .unknownUserStatus:
            return NSLocalizedString("CoreDataFetch_UserUnknownStatus",
                                     comment: "Failed to get Community extension parameters.\nTry logging in again.")
        case .userCreationError:
            return NSLocalizedString("CoreData_UserCreateFailed",
                                     comment: "Failed to create a new User object.")
        
        // Album errors
        case .fetchAlbumFailed:
            return NSLocalizedString("CoreDataFetch_AlbumError",
                                     comment: "Fetch albums error!")
        case .missingAlbumData:
            return NSLocalizedString("CoreDataFetch_AlbumMissingData",
                                     comment: "Found and will discard an album missing a valid ID or name.")
        case .albumCreationError:
            return NSLocalizedString("CoreDataFetch_AlbumCreateFailed",
                                     comment: "Failed to create a new Album object.")
        case .albumNotFound:
            return NSLocalizedString("CoreData_AlbumNotFound",
                                     comment: "Album not in persistent cache.")

        // Image errors
        case .fetchImageFailed:
            return NSLocalizedString("CoreDataFetch_ImageError",
                                     comment: "Fetch photos/videos error!")
        case .missingImageData:
            return NSLocalizedString("CoreDataFetch_ImageMissingData",
                                     comment: "Found and will discard a photo/video missing a valid ID or URL.")
        case .creationImageError:
            return NSLocalizedString("CoreDataFetch_ImageCreateFailed",
                                     comment: "Failed to create a new Image object.")
        
        // Tag errors
        case .fetchTagFailed:
            return NSLocalizedString("CoreDataFetch_TagError",
                                     comment: "Fetch tags error!")
        case .missingTagData:
            return NSLocalizedString("CoreDataFetch_TagMissingData",
                                     comment: "Found and will discard a tag missing a valid code or name.")
        case .tagCreationError:
            return NSLocalizedString("CoreDataFetch_TagCreateFailed",
                                     comment: "Failed to create a new Tag object.")
        
        // Location errors
        case .missingLocationData:
            return NSLocalizedString("CoreDataFetch_LocationMissingData",
                                     comment: "Found and will discard a location missing a valid identifier.")
        case .locationCreationError:
            return NSLocalizedString("CoreDataFetch_LocationCreateFailed",
                                     comment: "Failed to create a new Location object.")

        // Upload errors
        case .uploadCreationError:
            return NSLocalizedString("CoreDataFetch_UploadCreateFailed",
                                     comment: "Failed to create a new Upload object.")
        case .uploadDeletionError:
            return NSLocalizedString("CoreDataFetch_UploadDeleteFailed",
                                     comment: "Failed to delete an Upload object.")
        case .missingUploadData:
            return NSLocalizedString("CoreDataFetch_UploadMissingData",
                                     comment: "Found and will discard an upload missing a valid identifier.")
        case .missingAsset:
            return NSLocalizedString("CoreDataFetch_UploadMissingAsset",
                                     comment: "Failed to retrieve photo")
        case .missingUploadFile:
            return ""
        
        // Network errors
        case .authenticationFailed:
            return NSLocalizedString("sessionStatusError_message",
                                     comment: "Failed to authenticate with server.\nTry logging in again.")
        case .invalidResponse:
            return NSLocalizedString("PiwigoServer_invalidResponse",
                                     comment: "Piwigo server did not return an invalid response.")
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
        case .wrongDataFormat:
            return NSLocalizedString("CoreDataFetch_DigestError",
                                     comment: "Could not digest the fetched data.")

        // Piwigo errors
        case .pwgError(code: let code, msg: let msg):
            switch code {
            case 400:
                // Messages not translated in Piwigo:
                /// - Unknown request format
                return msg.isEmpty
                ? PwgKitError.invalidMethod.localizedDescription
                : msg
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
                return msg.isEmpty
                ? PwgKitError.invalidMethod.localizedDescription
                : msg
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
                return msg.isEmpty
                ? PwgKitError.invalidMethod.localizedDescription
                : msg
            case 404:
                // Messages not translated in Piwigo:
                /// - cat_id { … } not found
                /// - category_id not found
                /// - image_id not found
                /// - Invalid image_id or access denied
                /// - No format found for the id(s) given
                /// - This image is not associated to this category
                return msg.isEmpty
                ? PwgKitError.invalidMethod.localizedDescription
                : msg
            case 405:
                // Messages not translated in Piwigo:
                /// - The image (file) is missing
                /// - This method requires HTTP POST
                return msg.isEmpty
                ? PwgKitError.invalidMethod.localizedDescription
                : msg
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
                return msg.isEmpty
                ? PwgKitError.unexpectedError.localizedDescription
                : msg
            case 501:   // i.e. WS_ERR_INVALID_METHOD
                // Messages not translated in Piwigo:
                /// - Method name is not valid
                /// - Missing "method" name
                return msg.isEmpty
                ? PwgKitError.invalidMethod.localizedDescription
                : msg
            case 999:
                // Messages not translated in Piwigo:
                /// - Invalid username/password
                return msg.contains("Invalid username/password")
                ? PwgKitError.invalidCredentials.localizedDescription
                : msg
            case 1002:  // i.e. WS_ERR_MISSING_PARAM
                // Messages not translated in Piwigo:
                /// - Missing parameters: …
                return msg.isEmpty
                ? PwgKitError.invalidParameter.localizedDescription
                : msg
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
                return msg.isEmpty
                ? PwgKitError.invalidParameter.localizedDescription
                : msg
            default:
                return msg
            }

        case .unexpectedError:
            fallthrough
        
        default:
            return NSLocalizedString("serverUnknownError_message",
                                     comment: "Unexpected error encountered while calling server method with provided parameters.")
        }
    }
}
