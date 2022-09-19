//
//  LoginUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 14/02/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

enum pwgLoginContext {
    case nonTrustedCertificate
    case nonSecuredAccess
    case incorrectURL
}

class LoginUtilities: NSObject {
    
    // MARK: - Piwigo Server Methods
    static func getMethods(completion: @escaping () -> Void,
                           failure: @escaping (NSError) -> Void) {
        print("••> Get methods…")
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
        print("••> Session login…")
        // Prepare parameters for retrieving image/video infos
        let paramsDict: [String : Any] = ["username" : username,
                                          "password" : password]
        // Launch request
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgSessionLogin, paramDict: paramsDict,
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
        print("••> Get community status…")
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

                // Update user's status
                NetworkVars.userStatus = statusJSON.realUser
                completion()
            }
            catch {
                // Data cannot be digested
                NetworkVars.userStatus = pwgUserStatus.guest.rawValue
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
        print("••> Get session status…")
        // Launch request
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgSessionGetStatus, paramDict: [:],
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
                if NetworkVars.usesCommunityPluginV29,
                   NetworkVars.userStatus == pwgUserStatus.normal.rawValue,
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
                UploadVars.serverFileTypes = data.uploadFileTypes ?? "jpg,jpeg,png,gif"
                
                // User rights are determined by Community extension (if installed)
                let userStatus = data.userStatus ?? pwgUserStatus.guest.rawValue
                guard !NetworkVars.usesCommunityPluginV29,
                      let status = pwgUserStatus(rawValue: userStatus),
                      pwgUserStatus.allValues.contains(status) else {
                    failure(UserError.unknownUserStatus as NSError)
                    return
                }
                NetworkVars.userStatus = userStatus

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
        print("••> Session logout…")
        // Launch request
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgSessionLogout, paramDict: [:],
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


    // MARK: - Login business
    static func requestServerMethods(completion: @escaping () -> Void,
                                     didRejectCertificate: @escaping (NSError) -> Void,
                                     didFailHTTPauthentication: @escaping (NSError) -> Void,
                                     didFailSecureConnection: @escaping (NSError) -> Void,
                                     failure: @escaping (NSError?) -> Void) {
        // Collect list of methods supplied by Piwigo server
        // => Determine if Community extension 2.9a or later is installed and active
        LoginUtilities.getMethods {
            // Known methods, pursue logging in…
            DispatchQueue.main.async {
                completion()
            }
        } failure: { error in
            DispatchQueue.main.async {
                // If Piwigo uses a non-trusted certificate, ask permission
                if NetworkVars.didRejectCertificate {
                    // The SSL certificate is not trusted
                    didRejectCertificate(error)
                    return
                }

                // HTTP Basic authentication required?
                if (error as NSError).code == 401 || (error as NSError).code == 403 || NetworkVars.didFailHTTPauthentication {
                    // Without prior knowledge, the app already tried Piwigo credentials
                    // but unsuccessfully, so we request HTTP credentials
                    didFailHTTPauthentication(error)
                    return
                }

                switch (error as NSError).code {
                case NSURLErrorUserAuthenticationRequired:
                    // Without prior knowledge, the app already tried Piwigo credentials
                    // but unsuccessfully, so must now request HTTP credentials
                    didFailHTTPauthentication(error)
                    return
                case NSURLErrorUserCancelledAuthentication:
                    failure(nil)
                    return
                case NSURLErrorBadServerResponse, NSURLErrorBadURL, NSURLErrorCallIsActive, NSURLErrorCannotDecodeContentData, NSURLErrorCannotDecodeRawData, NSURLErrorCannotFindHost, NSURLErrorCannotParseResponse, NSURLErrorClientCertificateRequired, NSURLErrorDataLengthExceedsMaximum, NSURLErrorDataNotAllowed, NSURLErrorDNSLookupFailed, NSURLErrorHTTPTooManyRedirects, NSURLErrorInternationalRoamingOff, NSURLErrorNetworkConnectionLost, NSURLErrorNotConnectedToInternet, NSURLErrorRedirectToNonExistentLocation, NSURLErrorRequestBodyStreamExhausted, NSURLErrorTimedOut, NSURLErrorUnknown, NSURLErrorUnsupportedURL, NSURLErrorZeroByteResource:
                    failure(NetworkVars.userCancelledCommunication ? nil : error)
                    return
                case NSURLErrorCannotConnectToHost,    // Happens when the server does not reply to the request (HTTP or HTTPS)
                    NSURLErrorSecureConnectionFailed:
                    // HTTPS request failed ?
                    if (NetworkVars.serverProtocol == "https://") && !NetworkVars.userCancelledCommunication {
                        // Suggest HTTP connection if HTTPS attempt failed
                        didFailSecureConnection(error)
                        return
                    }
                    return
                case NSURLErrorClientCertificateRejected, NSURLErrorServerCertificateHasBadDate, NSURLErrorServerCertificateHasUnknownRoot, NSURLErrorServerCertificateNotYetValid, NSURLErrorServerCertificateUntrusted:
                    // The SSL certificate is not trusted
                    didRejectCertificate(error)
                    return
                default:
                    break
                }

                // Display error message
                failure(NetworkVars.userCancelledCommunication ? nil : error)
            }
        }
    }
        
    static func getHttpCredentialsAlert(textFieldDelegate: UITextFieldDelegate?,
                                        username: String, password: String,
                                        cancelAction: @escaping ((UIAlertAction) -> Void),
                                        loginAction: @escaping ((UIAlertAction) -> Void)) -> UIAlertController {
        let alert = UIAlertController(
            title: NSLocalizedString("loginHTTP_title", comment: "HTTP Credentials"),
            message: NSLocalizedString("loginHTTP_message", comment: "HTTP basic authentification is required by the Piwigo server:"),
            preferredStyle: .alert)
        
        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = NSLocalizedString("loginHTTPuser_placeholder", comment: "username")
            textField.text = (username.count > 0) ? username : ""
            textField.clearButtonMode = .always
            textField.keyboardType = .default
            textField.keyboardAppearance = AppVars.shared.isDarkPaletteActive ? .dark : .default
            textField.returnKeyType = .continue
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.delegate = textFieldDelegate
        })
        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = NSLocalizedString("loginHTTPpwd_placeholder", comment: "password")
            textField.text = (password.count > 0) ? password : ""
            textField.clearButtonMode = .always
            textField.keyboardType = .default
            textField.isSecureTextEntry = true
            textField.keyboardAppearance = AppVars.shared.isDarkPaletteActive ? .dark : .default
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.returnKeyType = .continue
            textField.delegate = textFieldDelegate
        })

        let cancelAction = UIAlertAction(
            title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
            style: .cancel, handler: cancelAction)
        alert.addAction(cancelAction)

        let loginAction = UIAlertAction(
            title: NSLocalizedString("alertOkButton", comment: "OK"),
            style: .default, handler: loginAction)
        alert.addAction(loginAction)

        alert.view.tintColor = UIColor.piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        }
        return alert
    }
    
    // Used for retrying failing operations
    static func reloginAndRetry(completion: @escaping () -> Void,
                                failure: @escaping (NSError?) -> Void) {
        let server = NetworkVars.serverPath
        let user = NetworkVars.username
        if server.isEmpty == false, user.isEmpty == false {
            // Re-login before retrying
            performRelogin() {
                completion()
            } failure: { error in
                failure(error)
            }
        } else if server.isEmpty == false {
            // Only retry
            completion()
        } else {
            // Return to login view (all scenes in foreground)
            ClearCache.closeSessionAndClearCache() { }
        }
    }
    
    static func performRelogin(completion: @escaping () -> Void,
                               failure: @escaping (NSError?) -> Void) {
        print("••> perform re-login before retrying…")

        // Collect list of methods supplied by Piwigo server
        // => Determine if Community extension 2.9a or later is installed and active
        requestServerMethods { [self] in
            // Known methods, perform re-login
            let username = NetworkVars.username
            if username.isEmpty {
                // Check Piwigo version, get token, available sizes, etc.
                if NetworkVars.usesCommunityPluginV29 {
                    communityGetStatus {
                        sessionGetStatus {
                            completion()
                        } failure: { error in
                            failure(error)
                        }
                    } failure: { error in
                        failure(error)
                    }
                } else {
                    sessionGetStatus {
                        completion()
                    } failure: { error in
                        failure(error)
                    }
                }
            } else {
                // Perform login
                let password = KeychainUtilities.password(forService: NetworkVars.serverPath, account: username)
                sessionLogin(withUsername: username, password: password) {
                    // Session now opened
                    if NetworkVars.usesCommunityPluginV29 {
                        communityGetStatus {
                            sessionGetStatus {
                                completion()
                            } failure: { error in
                                failure(error)
                            }
                        } failure: { error in
                            failure(error)
                        }
                    } else {
                        sessionGetStatus {
                            completion()
                        } failure: { error in
                            failure(error)
                        }
                    }
                } failure: { error in
                    failure(error)
                }
            }
        } didRejectCertificate: { error in
            failure(error)
        } didFailHTTPauthentication: { error in
            failure(error)
        } didFailSecureConnection: { error in
            failure(error)
        } failure: { error in
            failure(error)
        }
    }
}
