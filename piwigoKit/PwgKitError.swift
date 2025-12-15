//
//  PwgKitError.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 13/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import Photos

// Constant used to return a PwgKitError
public let reason = "Piwigo server error"

public enum PwgKitError: Error {
    // Error types
    case fileOperationFailed(innerError: CocoaError)
    case photosError(innerError: PHPhotosError)
    case invalidStatusCode(statusCode: Int)
    case requestFailed(innerError: URLError)
    case decodingFailed(innerError: DecodingError)
    case otherError(innerError: Error)
    
    // Piwigo errors
    case pwgError(code: Int, msg: String)
    
    // Server errors
    case serverCreationError
    case incompatiblePwgVersion
    case authenticationFailed
    case invalidResponse
    case emptyJSONobject
    case invalidCredentials
    case invalidJSONobject
    case operationFailed
    
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
    case unacceptedImageFormat
    case unacceptedAudioFormat
    case unacceptedVideoFormat
    case unacceptedDataFormat
    case missingUploadParameter
    case cannotStripPrivateMetadata
    case autoUploadSourceInvalid
    case autoUploadDestinationInvalid
    case emptyingLoungeFailed
    
    // Network errors
    case wrongServerURL
    case failedToPrepareDownload
    case invalidMethod
    case invalidParameter
    case invalidURL
    case missingParameter
    case networkUnavailable
    case wrongJSONobject
    case unexpectedData
    case logoutFailed

    // Unexplained error
    case unexpectedError
}

extension PwgKitError {
    // Errors that should lead to a logout
    public var requiresLogout: Bool {
        switch self {
        case .authenticationFailed,
             .incompatiblePwgVersion,
             .invalidCredentials,
             .invalidStatusCode(statusCode: 401),
             .invalidStatusCode(statusCode: 403),
             .invalidURL:
            return true
        default:
            return false
        }
    }
    
    public var failedAuthentication: Bool {
        switch self {
        case .authenticationFailed,
             .invalidCredentials,
             .invalidStatusCode(statusCode: 401),
             .invalidStatusCode(statusCode: 403):
            return true
        default:
            return false
        }
    }

    public var requestCancelled: Bool {
        switch self {
        case .requestFailed(innerError: URLError.cancelled):
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
    // When adopting iOS 16 as minimum target, migrate to LocalizedStringResource()
    public var errorDescription: String? {
        switch self {
        // File management errors
        case .fileOperationFailed(innerError: let error):
            return error.localizedDescription
        
        // Photo Library errors
        case .photosError(innerError: let error):
            return error.localizedDescription
        
        // HTTP errors
        case .invalidStatusCode(statusCode: let code):
            return "HTTP error \(code): " + HTTPURLResponse.localizedString(forStatusCode: code)
        
        // Request failed errors
        case .requestFailed(innerError: let error):
            return error.localizedDescription
        
        // Decoding failed errors
        case .decodingFailed(innerError: let error):
            return error.localizedDescription
        
        // Other errors
        case .otherError(innerError: let error):
            return error.localizedDescription
        
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

        // Server errors
        case .serverCreationError:
            return String(localized: "CoreData_ServerCreateFailed", bundle: piwigoKit,
                          comment: "Failed to create a new Server object.")
        case .incompatiblePwgVersion:
            return String(localized: "serverVersionNotCompatible_message", bundle: piwigoKit,
                          comment: "Your server version is %@. Piwigo Mobile only supports a version of at least %@. Please update your server to use Piwigo Mobile.")
        case .authenticationFailed:
            return String(localized: "sessionStatusError_message", bundle: piwigoKit,
                          comment: "Failed to authenticate with server.\nTry logging in again.")
        case .invalidResponse:
            return String(localized: "PiwigoServer_invalidResponse", bundle: piwigoKit,
                          comment: "Piwigo server did not return a valid response.")
        case .emptyJSONobject:
            return String(localized: "PiwigoServer_emptyJSONobject", bundle: piwigoKit,
                          comment: "Piwigo server did return an empty JSON object.")
        case .invalidCredentials:
            return String(localized: "loginError_message", bundle: piwigoKit,
                          comment: "The username and password don't match on the given server")
        case .invalidJSONobject:
            return String(localized: "PiwigoServer_invalidJSONobject", bundle: piwigoKit,
                          comment: "Piwigo server did not return a valid JSON object.")
        case .operationFailed:
            return String(localized: "PiwigoServer_operationFailed", bundle: piwigoKit,
                          comment: "The Piwigo server was unable to complete the requested operation.")

        // User errors
        case .emptyUsername:
            return String(localized: "CoreDataFetch_UserMissingData", bundle: piwigoKit,
                          comment: "Will discard a user account missing a valid username.")
        case .unknownUserStatus:
            return String(localized: "CoreDataFetch_UserUnknownStatus", bundle: piwigoKit,
                          comment: "Failed to get Community extension parameters.\nTry logging in again.")
        case .userCreationError:
            return String(localized: "CoreData_UserCreateFailed", bundle: piwigoKit,
                          comment: "Failed to create a new User object.")
        
        // Album errors
        case .fetchAlbumFailed:
            return String(localized: "CoreDataFetch_AlbumError", bundle: piwigoKit,
                          comment: "Fetch albums error!")
        case .missingAlbumData:
            return String(localized: "CoreDataFetch_AlbumMissingData", bundle: piwigoKit,
                          comment: "Found and will discard an album missing a valid ID or name.")
        case .albumCreationError:
            return String(localized: "CoreDataFetch_AlbumCreateFailed", bundle: piwigoKit,
                          comment: "Failed to create a new Album object.")
        case .albumNotFound:
            return String(localized: "CoreData_AlbumNotFound", bundle: piwigoKit,
                          comment: "Album not in persistent cache.")

        // Image errors
        case .fetchImageFailed:
            return String(localized: "CoreDataFetch_ImageError", bundle: piwigoKit,
                          comment: "Fetch photos/videos error!")
        case .missingImageData:
            return String(localized: "CoreDataFetch_ImageMissingData", bundle: piwigoKit,
                          comment: "Found and will discard a photo/video missing a valid ID or URL.")
        case .creationImageError:
            return String(localized: "CoreDataFetch_ImageCreateFailed", bundle: piwigoKit,
                          comment: "Failed to create a new Image object.")
        
        // Tag errors
        case .fetchTagFailed:
            return String(localized: "CoreDataFetch_TagError", bundle: piwigoKit,
                          comment: "Fetch tags error!")
        case .missingTagData:
            return String(localized: "CoreDataFetch_TagMissingData", bundle: piwigoKit,
                          comment: "Found and will discard a tag missing a valid code or name.")
        case .tagCreationError:
            return String(localized: "CoreDataFetch_TagCreateFailed", bundle: piwigoKit,
                          comment: "Failed to create a new Tag object.")
        
        // Location errors
        case .locationCreationError:
            return String(localized: "CoreDataFetch_LocationCreateFailed", bundle: piwigoKit,
                          comment: "Failed to create a new Location object.")
        case .missingLocationData:
            return String(localized: "CoreDataFetch_LocationMissingData", bundle: piwigoKit,
                          comment: "Found and will discard a location missing a valid identifier.")

        // Upload errors
        case .uploadCreationError:
            return String(localized: "CoreDataFetch_UploadCreateFailed", bundle: piwigoKit,
                          comment: "Failed to create a new Upload object.")
        case .uploadDeletionError:
            return String(localized: "CoreDataFetch_UploadDeleteFailed", bundle: piwigoKit,
                          comment: "Failed to delete an Upload object.")
        case .missingUploadData:
            return String(localized: "CoreDataFetch_UploadMissingData", bundle: piwigoKit,
                          comment: "Found and will discard an upload missing data.")
        case .missingAsset:
            return String(localized: "CoreDataFetch_UploadMissingAsset", bundle: piwigoKit,
                          comment: "Failed to retrieve photo")
        case .unacceptedImageFormat:
            return String(localized: "imageFormat_error", bundle: piwigoKit,
                          comment: "Photo file format not supported.")
        case .unacceptedAudioFormat:
            return String(localized: "audioFormat_error", bundle: piwigoKit,
                          comment: "Sorry, audio files are not supported by Piwigo Mobile yet.")
        case .unacceptedVideoFormat:
            return String(localized: "videoFormat_error", bundle: piwigoKit,
                          comment: "Video file format not supported.")
        case .unacceptedDataFormat:
            return String(localized: "otherFormat_error", bundle: piwigoKit,
                          comment: "File format not supported.")
        case .missingUploadParameter:
            return String(localized: "uploadParameterMissing_message", bundle: piwigoKit,
                          comment: "Missing upload paremeter")
        case .cannotStripPrivateMetadata:
            return String(localized: "shareMetadataError_message", bundle: piwigoKit,
                          comment: "Cannot strip private metadata")
        case .autoUploadSourceInvalid:
            return String(localized: "settings_autoUploadSourceInvalid", bundle: piwigoKit,
                          comment: "Invalid source album")
        case .autoUploadDestinationInvalid:
            return String(localized: "settings_autoUploadDestinationInvalid", bundle: piwigoKit,
                          comment: "Invalid destination album")
        case .emptyingLoungeFailed:
            return String(localized: "EmptyingLoungeFailed", bundle: piwigoKit,
                          comment: "Failed to empty the lounge.")
        
        // Network errors
        case .wrongServerURL:
            return String(localized: "serverURLerror_title", bundle: piwigoKit,
                          comment: "Incorrect URL")
        case .failedToPrepareDownload:
            return String(localized: "downloadImageFail_title", bundle: piwigoKit,
                          comment: "Download Fail")
        case .invalidMethod:
            return String(localized: "serverInvalidMethodError_message", bundle: piwigoKit,
                          comment: "Failed to call server method.")
        case .invalidParameter:
            return String(localized: "serverUnknownError_message", bundle: piwigoKit,
                          comment: "Unexpected error encountered while calling server method with provided parameters.")
        case .invalidURL:
            return String(localized: "serverURLerror_message", bundle: piwigoKit,
                          comment: "Please correct the Piwigo web server address.")
        case .missingParameter:
            return String(localized: "serverMissingParamError_message", bundle: piwigoKit,
                          comment: "Failed to execute server method with missing parameter.")
        case .networkUnavailable:
            return String(localized: "internetErrorGeneral_broken", bundle: piwigoKit,
                          comment: "Sorry, the communication was broken.\nTry logging in again.")
        case .wrongJSONobject:
            return String(localized: "PiwigoServer_wrongJSONobject", bundle: piwigoKit,
                          comment: "Could not digest JSON object returned by Piwigo server.")
        case .unexpectedData:
            return String(localized: "PiwigoServer_unexpectedData", bundle: piwigoKit,
                          comment: "Unable to extract the expected information from the data returned by the Piwigo server.")
        case .logoutFailed:
            return String(localized: "LogoutFailed", bundle: piwigoKit,
                          comment: "Failed to logout.")
        
        case .unexpectedError:
            fallthrough
        
        default:
            return String(localized: "serverUnknownError_message", bundle: piwigoKit,
                          comment: "Unexpected error encountered while calling server method with provided parameters.")
        }
    }
}
