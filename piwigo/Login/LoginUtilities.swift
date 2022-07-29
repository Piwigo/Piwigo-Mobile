//
//  LoginUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 14/02/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

class LoginUtilities: NSObject {
    
    // MARK: - Piwigo Server Methods
    static func getMethods(completion: @escaping () -> Void,
                           failure: @escaping (NSError) -> Void) {
        // Launch request
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kReflectionGetMethodList, paramDict: [:],
                                jsonObjectClientExpectsToReceive: ReflectionGetMethodListJSON.self,
                                countOfBytesClientExpectsToReceive: 32500) { jsonData in
            // Decode the JSON object and set variables.
            do {
                // Decode the JSON into codable type ImagesGetInfoJSON.
                let decoder = JSONDecoder()
                let methodsJSON = try decoder.decode(ReflectionGetMethodListJSON.self, from: jsonData)

                // Piwigo error?
                if methodsJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: methodsJSON.errorCode,
                                                                    errorMessage: methodsJSON.errorMessage)
                    failure(error as NSError)
                    return
                }

                // Check if the Community extension is installed and active (> 2.9a)
                NetworkVars.usesCommunityPluginV29 = methodsJSON.data.contains("community.session.getStatus")
                
                // Check if the pwg.images.uploadAsync method is available
                NetworkVars.usesUploadAsync = methodsJSON.data.contains("pwg.images.uploadAsync")

                completion()
            }
            catch {
                // Data cannot be digested
                let error = error as NSError
                failure(error)
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            failure(error)
        }
    }

    static func sessionLogin(withUsername username:String, password:String,
                             completion: @escaping () -> Void,
                             failure: @escaping (NSError) -> Void) {
        // Prepare parameters for retrieving image/video infos
        let paramsDict: [String : Any] = ["username" : username,
                                          "password" : password]
        // Launch request
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kPiwigoSessionLogin, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: SessionLoginJSON.self,
                                countOfBytesClientExpectsToReceive: 620) { jsonData in
            // Decode the JSON object and check if the login was successful
            do {
                // Decode the JSON into codable type ImagesGetInfoJSON.
                let decoder = JSONDecoder()
                let loginJSON = try decoder.decode(SessionLoginJSON.self, from: jsonData)

                // Piwigo error?
                if loginJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: loginJSON.errorCode,
                                                                    errorMessage: loginJSON.errorMessage)
                    failure(error as NSError)
                    return
                }

                // Login successful
                NetworkVars.username = username
                NetworkVars.dateOfLastLogin = Date()
                completion()
            }
            catch {
                // Data cannot be digested
                let error = error as NSError
                failure(error)
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            failure(error)
        }
    }

    static func communityGetStatus(completion: @escaping () -> Void,
                                   failure: @escaping (NSError) -> Void) {
        // Launch request
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kCommunitySessionGetStatus, paramDict: [:],
                                jsonObjectClientExpectsToReceive: CommunitySessionGetStatusJSON.self,
                                countOfBytesClientExpectsToReceive: 2100) { jsonData in
            // Decode the JSON object and retrieve the status
            do {
                // Decode the JSON into codable type ImagesGetInfoJSON.
                let decoder = JSONDecoder()
                let statusJSON = try decoder.decode(CommunitySessionGetStatusJSON.self, from: jsonData)

                // Piwigo error?
                if statusJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: statusJSON.errorCode,
                                                                    errorMessage: statusJSON.errorMessage)
                    failure(error as NSError)
                    return
                }
                
                // No status returned?
                if statusJSON.realUser.isEmpty {
                    failure(JsonError.unknownStatus as NSError)
                    return
                }

                // Update session flags
                NetworkVars.hasAdminRights = ["admin", "webmaster"].contains(statusJSON.realUser)
                NetworkVars.hasNormalRights = (statusJSON.realUser == "normal")
                NetworkVars.hasGuestRights = (statusJSON.realUser == "guest")
                completion()
            }
            catch {
                // Data cannot be digested
                NetworkVars.hasAdminRights = false
                NetworkVars.hasNormalRights = false
                NetworkVars.usesUploadAsync = false
                let error = error as NSError
                failure(error)
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            failure(error)
        }
    }

    static func sessionGetStatus(completion: @escaping () -> Void,
                                 failure: @escaping (NSError) -> Void) {
        // Launch request
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kPiwigoSessionGetStatus, paramDict: [:],
                                jsonObjectClientExpectsToReceive: SessionGetStatusJSON.self,
                                countOfBytesClientExpectsToReceive: 7400) { jsonData in
            // Decode the JSON object and retrieve the status
            do {
                // Decode the JSON into codable type ImagesGetInfoJSON.
                let decoder = JSONDecoder()
                let statusJSON = try decoder.decode(SessionGetStatusJSON.self, from: jsonData)

                // Piwigo error?
                if statusJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: statusJSON.errorCode,
                                                                    errorMessage: statusJSON.errorMessage)
                    failure(error as NSError)
                    return
                }
                
                // No status returned?
                guard let data = statusJSON.data else {
                    failure(JsonError.authenticationFailed as NSError)
                    return
                }

                // Update Piwigo token
                if let pwgToken = data.pwgToken {
                    NetworkVars.pwgToken = pwgToken
                }
                
                // Default language
                NetworkVars.language = data.language ?? ""
                
                // Piwigo server version should be of format 1.2.3
                var versionStr = data.version ?? ""
                let components = versionStr.components(separatedBy: ".")
                switch components.count {
                    case 1:     // Version of type 1
                    versionStr.append(".0.0")
                    case 2:     // Version of type 1.2
                    versionStr.append(".0")
                    default:
                        break
                }
                NetworkVars.pwgVersion = versionStr

                // Community users cannot upload with uploadAsync with Piwigo 11.x
                if NetworkVars.usesCommunityPluginV29, NetworkVars.hasNormalRights,
                   "11.0.0".compare(versionStr, options: .numeric) != .orderedDescending,
                   "12.0.0".compare(versionStr, options: .numeric) != .orderedAscending {
                    NetworkVars.usesUploadAsync = false
                }

                // Retrieve charset used by the Piwigo server
                let charset = (data.charset ?? "UTF-8").uppercased()
                switch charset {
                case "UNICODE":
                    NetworkVars.stringEncoding = String.Encoding.unicode.rawValue
                case "UNICODEFFFE":
                    NetworkVars.stringEncoding = String.Encoding.utf16BigEndian.rawValue
                case "UTF-8":
                    NetworkVars.stringEncoding = String.Encoding.utf8.rawValue
                case "UTF-16":
                    NetworkVars.stringEncoding = String.Encoding.utf16.rawValue
                case "UTF-32":
                    NetworkVars.stringEncoding = String.Encoding.utf32.rawValue
                case "ISO-2022-JP":
                    NetworkVars.stringEncoding = String.Encoding.iso2022JP.rawValue
                case "ISO-8859-1":
                    NetworkVars.stringEncoding = String.Encoding.windowsCP1252.rawValue
                case "ISO-8859-3":
                    NetworkVars.stringEncoding = String.Encoding.isoLatin1.rawValue
                case "CP870":
                    NetworkVars.stringEncoding = String.Encoding.isoLatin2.rawValue
                case "MACINTOSH":
                    NetworkVars.stringEncoding = String.Encoding.macOSRoman.rawValue
                case "SHIFT-JIS":
                    NetworkVars.stringEncoding = String.Encoding.shiftJIS.rawValue
                case "WINDOWS-1250":
                    NetworkVars.stringEncoding = String.Encoding.windowsCP1250.rawValue
                case "WINDOWS-1251":
                    NetworkVars.stringEncoding = String.Encoding.windowsCP1251.rawValue
                case "WINDOWS-1252":
                    NetworkVars.stringEncoding = String.Encoding.windowsCP1252.rawValue
                case "WINDOWS-1253":
                    NetworkVars.stringEncoding = String.Encoding.windowsCP1253.rawValue
                case "WINDOWS-1254":
                    NetworkVars.stringEncoding = String.Encoding.windowsCP1254.rawValue
                case "X-EUC":
                    NetworkVars.stringEncoding = String.Encoding.japaneseEUC.rawValue
                case "US-ASCII":
                    NetworkVars.stringEncoding = String.Encoding.ascii.rawValue
                default:
                    NetworkVars.stringEncoding = String.Encoding.utf8.rawValue
                }
                print("   version: \(NetworkVars.pwgVersion), usesUploadAsync: \(NetworkVars.usesUploadAsync ? "\"true\"" : "\"false\""), charset: \(charset)")

                // Upload chunk size is null if not provided by server
                if let uploadChunkSize = data.uploadChunkSize, uploadChunkSize != 0 {
                    UploadVars.uploadChunkSize = uploadChunkSize
                } else {
                    UploadVars.uploadChunkSize = 500    // i.e. 500 ko
                }

                // Images and videos can be uploaded if their file types are found.
                // The iPhone creates mov files that will be uploaded in mp4 format.
                // This string is empty if the server does not provide it.
                UploadVars.serverFileTypes = data.uploadFileTypes ?? ""
                
                // User rights are determined by Community extension (if installed)
                if !NetworkVars.usesCommunityPluginV29,
                   let userStatus = data.userStatus, userStatus.isEmpty == false {
                    NetworkVars.hasAdminRights = ["admin", "webmaster"].contains(userStatus)
                    NetworkVars.hasNormalRights = (userStatus == "normal")
                    NetworkVars.hasGuestRights = (userStatus == "guest")
                }
                
                // Retrieve the list of available sizes
                AlbumVars.shared.hasSquareSizeImages  = data.imageSizes?.contains("square") ?? false
                AlbumVars.shared.hasThumbSizeImages   = data.imageSizes?.contains("thumb") ?? false
                AlbumVars.shared.hasXXSmallSizeImages = data.imageSizes?.contains("2small") ?? false
                AlbumVars.shared.hasXSmallSizeImages  = data.imageSizes?.contains("xsmall") ?? false
                AlbumVars.shared.hasSmallSizeImages   = data.imageSizes?.contains("small") ?? false
                AlbumVars.shared.hasMediumSizeImages  = data.imageSizes?.contains("medium") ?? false
                AlbumVars.shared.hasLargeSizeImages   = data.imageSizes?.contains("large") ?? false
                AlbumVars.shared.hasXLargeSizeImages  = data.imageSizes?.contains("xlarge") ?? false
                AlbumVars.shared.hasXXLargeSizeImages = data.imageSizes?.contains("xxlarge") ?? false
                
                // Check that the actual default album thumbnail size is available
                // and select the next available size in case of unavailability
                switch kPiwigoImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) {
                case kPiwigoImageSizeXXSmall:
                    if !AlbumVars.shared.hasXXSmallSizeImages {
                        // Look for next available larger size
                        if AlbumVars.shared.hasXSmallSizeImages {
                            AlbumVars.shared.defaultAlbumThumbnailSize = kPiwigoImageSizeXSmall.rawValue
                        } else if AlbumVars.shared.hasSmallSizeImages {
                            AlbumVars.shared.defaultAlbumThumbnailSize = kPiwigoImageSizeSmall.rawValue
                        } else {
                            AlbumVars.shared.defaultAlbumThumbnailSize = kPiwigoImageSizeMedium.rawValue
                        }
                    }
                case kPiwigoImageSizeXSmall:
                    if !AlbumVars.shared.hasXSmallSizeImages {
                        // Look for next available larger size
                        if AlbumVars.shared.hasSmallSizeImages {
                            AlbumVars.shared.defaultAlbumThumbnailSize = kPiwigoImageSizeSmall.rawValue
                        } else {
                            AlbumVars.shared.defaultAlbumThumbnailSize = kPiwigoImageSizeMedium.rawValue
                        }
                    }
                case kPiwigoImageSizeSmall:
                    if !AlbumVars.shared.hasSmallSizeImages {
                        // Select next available larger size
                        AlbumVars.shared.defaultAlbumThumbnailSize = kPiwigoImageSizeMedium.rawValue
                    }
                case kPiwigoImageSizeLarge:
                    if !AlbumVars.shared.hasLargeSizeImages {
                        AlbumVars.shared.defaultAlbumThumbnailSize = kPiwigoImageSizeMedium.rawValue
                    }
                case kPiwigoImageSizeXLarge:
                    if !AlbumVars.shared.hasXLargeSizeImages {
                        AlbumVars.shared.defaultAlbumThumbnailSize = kPiwigoImageSizeMedium.rawValue
                    }
                case kPiwigoImageSizeXXLarge:
                    if !AlbumVars.shared.hasXXLargeSizeImages {
                        AlbumVars.shared.defaultAlbumThumbnailSize = kPiwigoImageSizeMedium.rawValue
                    }
                case kPiwigoImageSizeSquare, kPiwigoImageSizeThumb,
                     kPiwigoImageSizeMedium, kPiwigoImageSizeFullRes:
                    // Should always be available
                    break
                default:
                    AlbumVars.shared.defaultAlbumThumbnailSize = kPiwigoImageSizeMedium.rawValue
                }
                
                // Check that the actual default image thumbnail size is available
                // and select the next available size in case of unavailability
                switch kPiwigoImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) {
                    case kPiwigoImageSizeXXSmall:
                        if !AlbumVars.shared.hasXXSmallSizeImages {
                            // Look for next available larger size
                            if AlbumVars.shared.hasXSmallSizeImages {
                                AlbumVars.shared.defaultThumbnailSize = kPiwigoImageSizeXSmall.rawValue
                            } else if AlbumVars.shared.hasSmallSizeImages {
                                AlbumVars.shared.defaultThumbnailSize = kPiwigoImageSizeSmall.rawValue
                            } else {
                                AlbumVars.shared.defaultThumbnailSize = kPiwigoImageSizeMedium.rawValue
                            }
                        }
                    case kPiwigoImageSizeXSmall:
                        if !AlbumVars.shared.hasXSmallSizeImages {
                            // Look for next available larger size
                            if AlbumVars.shared.hasSmallSizeImages {
                                AlbumVars.shared.defaultThumbnailSize = kPiwigoImageSizeSmall.rawValue
                            } else {
                                AlbumVars.shared.defaultThumbnailSize = kPiwigoImageSizeMedium.rawValue
                            }
                        }
                    case kPiwigoImageSizeSmall:
                        if !AlbumVars.shared.hasSmallSizeImages {
                            // Select next available larger size
                            AlbumVars.shared.defaultThumbnailSize = kPiwigoImageSizeMedium.rawValue
                        }
                    case kPiwigoImageSizeLarge:
                        if !AlbumVars.shared.hasLargeSizeImages {
                            AlbumVars.shared.defaultThumbnailSize = kPiwigoImageSizeMedium.rawValue
                        }
                    case kPiwigoImageSizeXLarge:
                        if !AlbumVars.shared.hasXLargeSizeImages {
                            AlbumVars.shared.defaultThumbnailSize = kPiwigoImageSizeMedium.rawValue
                        }
                    case kPiwigoImageSizeXXLarge:
                        if !AlbumVars.shared.hasXXLargeSizeImages {
                            AlbumVars.shared.defaultThumbnailSize = kPiwigoImageSizeMedium.rawValue
                        }
                case kPiwigoImageSizeSquare, kPiwigoImageSizeThumb,
                     kPiwigoImageSizeMedium, kPiwigoImageSizeFullRes:
                    // Should always be available
                    break
                default:
                    AlbumVars.shared.defaultThumbnailSize = kPiwigoImageSizeMedium.rawValue
                }

                // Calculate number of thumbnails per row for that selection
                let minNberOfImages = AlbumUtilities.imagesPerRowInPortrait(forView: nil, maxWidth: PiwigoImageData.width(forImageSizeType: kPiwigoImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize)))

                // Make sure that default number fits inside selected range
                AlbumVars.shared.thumbnailsPerRowInPortrait = max(AlbumVars.shared.thumbnailsPerRowInPortrait, minNberOfImages);
                AlbumVars.shared.thumbnailsPerRowInPortrait = min(AlbumVars.shared.thumbnailsPerRowInPortrait, 2*minNberOfImages);

                // Check that the actual default image preview size is still available
                // and select the next available size in case of unavailability
                switch kPiwigoImageSize(rawValue: ImageVars.shared.defaultImagePreviewSize) {
                case kPiwigoImageSizeXXSmall:
                    if !AlbumVars.shared.hasXXSmallSizeImages {
                        // Look for next available larger size
                        if AlbumVars.shared.hasXSmallSizeImages {
                            ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeXSmall.rawValue
                        } else if AlbumVars.shared.hasSmallSizeImages {
                            ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeSmall.rawValue
                        } else {
                            ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeMedium.rawValue
                        }
                    }
                case kPiwigoImageSizeXSmall:
                    if !AlbumVars.shared.hasXSmallSizeImages {
                        // Look for next available larger size
                        if AlbumVars.shared.hasSmallSizeImages {
                            ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeSmall.rawValue
                        } else {
                            ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeMedium.rawValue
                        }
                    }
                case kPiwigoImageSizeSmall:
                    if !AlbumVars.shared.hasSmallSizeImages {
                        // Select next available larger size
                        ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeMedium.rawValue
                    }
                case kPiwigoImageSizeLarge:
                    if !AlbumVars.shared.hasLargeSizeImages {
                        // Look for next available larger size
                        if AlbumVars.shared.hasXLargeSizeImages {
                            ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeXLarge.rawValue
                        } else if AlbumVars.shared.hasXXLargeSizeImages {
                            ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeXXLarge.rawValue
                        } else {
                            ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeFullRes.rawValue
                        }
                    }
                case kPiwigoImageSizeXLarge:
                    if !AlbumVars.shared.hasXLargeSizeImages {
                        // Look for next available larger size
                        if AlbumVars.shared.hasXXLargeSizeImages {
                            ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeXXLarge.rawValue
                        } else {
                            ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeFullRes.rawValue
                        }
                    }
                case kPiwigoImageSizeXXLarge:
                    if !AlbumVars.shared.hasXXLargeSizeImages {
                        ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeFullRes.rawValue
                    }
                case kPiwigoImageSizeSquare, kPiwigoImageSizeThumb,
                     kPiwigoImageSizeMedium, kPiwigoImageSizeFullRes:
                    // Should always be available
                    break
                default:
                    ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeFullRes.rawValue
                }
                completion()
            }
            catch {
                // Data cannot be digested
                let error = error as NSError
                failure(error)
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            failure(error)
        }
    }

    static func sessionLogout(completion: @escaping () -> Void,
                              failure: @escaping (NSError) -> Void) {
        // Launch request
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kPiwigoSessionLogout, paramDict: [:],
                                jsonObjectClientExpectsToReceive: SessionLogoutJSON.self,
                                countOfBytesClientExpectsToReceive: 620) { jsonData in
            // Decode the JSON object and check if the logout was successful
            do {
                // Decode the JSON into codable type ImagesGetInfoJSON.
                let decoder = JSONDecoder()
                let loginJSON = try decoder.decode(SessionLogoutJSON.self, from: jsonData)

                // Piwigo error?
                if loginJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: loginJSON.errorCode,
                                                                    errorMessage: loginJSON.errorMessage)
                    failure(error as NSError)
                    return
                }

                // Logout successful
                completion()
            }
            catch {
                // Data cannot be digested
                let error = error as NSError
                failure(error)
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            failure(error)
        }
    }
}
