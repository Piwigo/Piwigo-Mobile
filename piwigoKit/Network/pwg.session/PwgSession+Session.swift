//
//  PwgSession+Session.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 27/06/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import os
import Foundation

public extension PwgSession {
    
    func sessionLogin(withUsername username:String, password:String,
                      completion: @escaping () -> Void,
                      failure: @escaping (NSError) -> Void) {
        if #available(iOSApplicationExtension 14.0, *) {
            NetworkUtilities.logger.notice("Open session for \(username, privacy: .private(mask: .hash))")
        }
        // Prepare parameters for retrieving image/video infos
        let paramsDict: [String : Any] = ["username" : username,
                                          "password" : password]
        // Launch request
        postRequest(withMethod: pwgSessionLogin, paramDict: paramsDict,
                    jsonObjectClientExpectsToReceive: SessionLoginJSON.self,
                    countOfBytesClientExpectsToReceive: pwgSessionLoginBytes) { jsonData in
            // Decode the JSON object and check if the login was successful
            do {
                // Decode the JSON into codable type SessionLoginJSON.
                let decoder = JSONDecoder()
                let loginJSON = try decoder.decode(SessionLoginJSON.self, from: jsonData)
                
                // Piwigo error?
                if loginJSON.errorCode != 0 {
                    let error = self.localizedError(for: loginJSON.errorCode,
                                                    errorMessage: loginJSON.errorMessage)
                    failure(error as NSError)
                    return
                }
                
                // Login successful
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
    
    func sessionGetStatus(completion: @escaping (String) -> Void,
                                 failure: @escaping (NSError) -> Void) {
        if #available(iOSApplicationExtension 14.0, *) {
            NetworkUtilities.logger.notice("Get session status")
        }
        // Launch request
        postRequest(withMethod: pwgSessionGetStatus, paramDict: [:],
                    jsonObjectClientExpectsToReceive: SessionGetStatusJSON.self,
                    countOfBytesClientExpectsToReceive: pwgSessionGetStatusBytes) { jsonData in
            // Decode the JSON object and retrieve the status
            do {
                // Decode the JSON into codable type SessionGetStatusJSON.
                let decoder = JSONDecoder()
                let statusJSON = try decoder.decode(SessionGetStatusJSON.self, from: jsonData)

                // Piwigo error?
                if statusJSON.errorCode != 0 {
                    let error = self.localizedError(for: statusJSON.errorCode,
                                                    errorMessage: statusJSON.errorMessage)
                    failure(error as NSError)
                    return
                }
                
                // No status returned?
                guard let data = statusJSON.data else {
                    failure(PwgSessionErrors.authenticationFailed as NSError)
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
                   NetworkVars.userStatus == pwgUserStatus.normal,
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

                // Upload chunk size is null if not provided by server
                if let uploadChunkSize = data.uploadChunkSize, uploadChunkSize != 0 {
                    UploadVars.uploadChunkSize = uploadChunkSize
                } else {
                    UploadVars.uploadChunkSize = 500    // i.e. 500 ko
                }

                // Images and videos can be uploaded if their file types are found.
                // The iPhone creates mov files that will be uploaded in mp4 format.
                NetworkVars.serverFileTypes = data.uploadFileTypes ?? "jpg,jpeg,png,gif"
                
                // User rights are determined by Community extension (if installed)
                if let status = data.userStatus, status.isEmpty == false,
                   let userStatus = pwgUserStatus(rawValue: status) {
                    if NetworkVars.usesCommunityPluginV29 == false {
                        NetworkVars.userStatus = userStatus
                    }
                } else {
                    failure(UserError.unknownUserStatus as NSError)
                    return
                }

                // Retrieve the list of available sizes
                NetworkVars.hasSquareSizeImages  = data.imageSizes?.contains("square") ?? false
                NetworkVars.hasThumbSizeImages   = data.imageSizes?.contains("thumb") ?? false
                NetworkVars.hasXXSmallSizeImages = data.imageSizes?.contains("2small") ?? false
                NetworkVars.hasXSmallSizeImages  = data.imageSizes?.contains("xsmall") ?? false
                NetworkVars.hasSmallSizeImages   = data.imageSizes?.contains("small") ?? false
                NetworkVars.hasMediumSizeImages  = data.imageSizes?.contains("medium") ?? false
                NetworkVars.hasLargeSizeImages   = data.imageSizes?.contains("large") ?? false
                NetworkVars.hasXLargeSizeImages  = data.imageSizes?.contains("xlarge") ?? false
                NetworkVars.hasXXLargeSizeImages = data.imageSizes?.contains("xxlarge") ?? false
                
                // Should the app log visits and downloads? (since Piwigo 14)
                NetworkVars.saveVisits = data.saveVisits ?? false

                completion(data.userName ?? "")
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

    func sessionLogout(completion: @escaping () -> Void,
                              failure: @escaping (NSError) -> Void) {
        if #available(iOSApplicationExtension 14.0, *) {
            NetworkUtilities.logger.notice("Close session")
        }
        // Launch request
        postRequest(withMethod: pwgSessionLogout, paramDict: [:],
                    jsonObjectClientExpectsToReceive: SessionLogoutJSON.self,
                    countOfBytesClientExpectsToReceive: pwgSessionLogoutBytes) { jsonData in
            // Decode the JSON object and check if the logout was successful
            do {
                // Decode the JSON into codable type SessionLogoutJSON.
                let decoder = JSONDecoder()
                let loginJSON = try decoder.decode(SessionLogoutJSON.self, from: jsonData)

                // Piwigo error?
                if loginJSON.errorCode != 0 {
                    let error = self.localizedError(for: loginJSON.errorCode,
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
