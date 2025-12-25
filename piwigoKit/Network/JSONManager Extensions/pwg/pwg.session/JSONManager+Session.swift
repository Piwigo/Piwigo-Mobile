//
//  JSONManager+Session.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 27/06/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import os
import Foundation

public extension JSONManager {
    
    @concurrent
    func sessionLogin(withUsername username:String, password:String) async throws(PwgKitError) {
#if DEBUG
        JSONManager.logger.notice("Session: logging in with username: \(username, privacy: .public)…")
#else
        JSONManager.logger.notice("Session: logging in with username: \(username, privacy: .private(mask: .hash))…")
#endif
        // Prepare parameters for retrieving image/video infos
        let paramsDict: [String : Any] = ["username" : username,
                                          "password" : password]
        // Launch request
        let pwgData = try await postRequest(withMethod: pwgSessionLogin, paramDict: paramsDict,
                                            jsonObjectClientExpectsToReceive: SessionLoginJSON.self,
                                            countOfBytesClientExpectsToReceive: pwgSessionLoginBytes)
        if !pwgData.success {
            throw .invalidCredentials
        }
    }
    
    @concurrent
    func sessionGetStatus() async throws(PwgKitError) -> String {
        JSONManager.logger.notice("Session: getting status…")
        // Launch request
        let pwgData = try await postRequest(withMethod: pwgSessionGetStatus, paramDict: [:],
                                            jsonObjectClientExpectsToReceive: SessionGetStatusJSON.self,
                                            countOfBytesClientExpectsToReceive: pwgSessionGetStatusBytes)
        // No status returned?
        guard let data = pwgData.data
        else { throw .unknownUserStatus }

        // Update Piwigo token
        if let pwgToken = data.pwgToken {
            NetworkVars.shared.pwgToken = pwgToken
        }
        
        // Default language
        NetworkVars.shared.language = data.language ?? ""
        
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
        NetworkVars.shared.pwgVersion = versionStr

        // Community users cannot upload with uploadAsync with Piwigo 11.x
        if NetworkVars.shared.usesCommunityPluginV29,
           NetworkVars.shared.userStatus == pwgUserStatus.normal,
           "11.0.0".compare(versionStr, options: .numeric) != .orderedDescending,
           "12.0.0".compare(versionStr, options: .numeric) != .orderedAscending {
            NetworkVars.shared.usesUploadAsync = false
        }

        // API Keys conflict with HTTP Basic authentication in Piwigo 16.0
        if "16.0.0".compare(versionStr, options: .numeric) == .orderedSame {
            NetworkVars.shared.usesAPIkeys = false
        }
        
        // Retrieve charset used by the Piwigo server
        let charset = (data.charset ?? "UTF-8").uppercased()
        switch charset {
        case "UNICODE":
            NetworkVars.shared.stringEncoding = String.Encoding.unicode.rawValue
        case "UNICODEFFFE":
            NetworkVars.shared.stringEncoding = String.Encoding.utf16BigEndian.rawValue
        case "UTF-8":
            NetworkVars.shared.stringEncoding = String.Encoding.utf8.rawValue
        case "UTF-16":
            NetworkVars.shared.stringEncoding = String.Encoding.utf16.rawValue
        case "UTF-32":
            NetworkVars.shared.stringEncoding = String.Encoding.utf32.rawValue
        case "ISO-2022-JP":
            NetworkVars.shared.stringEncoding = String.Encoding.iso2022JP.rawValue
        case "ISO-8859-1":
            NetworkVars.shared.stringEncoding = String.Encoding.windowsCP1252.rawValue
        case "ISO-8859-3":
            NetworkVars.shared.stringEncoding = String.Encoding.isoLatin1.rawValue
        case "CP870":
            NetworkVars.shared.stringEncoding = String.Encoding.isoLatin2.rawValue
        case "MACINTOSH":
            NetworkVars.shared.stringEncoding = String.Encoding.macOSRoman.rawValue
        case "SHIFT-JIS":
            NetworkVars.shared.stringEncoding = String.Encoding.shiftJIS.rawValue
        case "WINDOWS-1250":
            NetworkVars.shared.stringEncoding = String.Encoding.windowsCP1250.rawValue
        case "WINDOWS-1251":
            NetworkVars.shared.stringEncoding = String.Encoding.windowsCP1251.rawValue
        case "WINDOWS-1252":
            NetworkVars.shared.stringEncoding = String.Encoding.windowsCP1252.rawValue
        case "WINDOWS-1253":
            NetworkVars.shared.stringEncoding = String.Encoding.windowsCP1253.rawValue
        case "WINDOWS-1254":
            NetworkVars.shared.stringEncoding = String.Encoding.windowsCP1254.rawValue
        case "X-EUC":
            NetworkVars.shared.stringEncoding = String.Encoding.japaneseEUC.rawValue
        case "US-ASCII":
            NetworkVars.shared.stringEncoding = String.Encoding.ascii.rawValue
        default:
            NetworkVars.shared.stringEncoding = String.Encoding.utf8.rawValue
        }

        // Upload chunk size is null if not provided by server
        if let uploadChunkSize = data.uploadChunkSize, uploadChunkSize != 0 {
            UploadVars.shared.uploadChunkSize = uploadChunkSize
        } else {
            UploadVars.shared.uploadChunkSize = 500    // i.e. 500 ko
        }

        // Images and videos can be uploaded if their file types are found.
        // The iPhone creates mov files that will be uploaded in mp4 format.
        NetworkVars.shared.serverFileTypes = data.uploadFileTypes ?? "jpg,jpeg,png,gif"
        
        // User rights are determined by Community extension (if installed)
        if let status = data.userStatus, status.isEmpty == false,
           let userStatus = pwgUserStatus(rawValue: status) {
            if NetworkVars.shared.usesCommunityPluginV29 == false {
                NetworkVars.shared.userStatus = userStatus
            }
        } else {
            throw .unknownUserStatus
        }

        // Retrieve the list of available sizes
        NetworkVars.shared.hasSquareSizeImages  = data.imageSizes?.contains("square") ?? false
        NetworkVars.shared.hasThumbSizeImages   = data.imageSizes?.contains("thumb") ?? false
        NetworkVars.shared.hasXXSmallSizeImages = data.imageSizes?.contains("2small") ?? false
        NetworkVars.shared.hasXSmallSizeImages  = data.imageSizes?.contains("xsmall") ?? false
        NetworkVars.shared.hasSmallSizeImages   = data.imageSizes?.contains("small") ?? false
        NetworkVars.shared.hasMediumSizeImages  = data.imageSizes?.contains("medium") ?? false
        NetworkVars.shared.hasLargeSizeImages   = data.imageSizes?.contains("large") ?? false
        NetworkVars.shared.hasXLargeSizeImages  = data.imageSizes?.contains("xlarge") ?? false
        NetworkVars.shared.hasXXLargeSizeImages = data.imageSizes?.contains("xxlarge") ?? false
        NetworkVars.shared.hasXXXLargeSizeImages = data.imageSizes?.contains("3xlarge") ?? false
        NetworkVars.shared.hasXXXXLargeSizeImages = data.imageSizes?.contains("4xlarge") ?? false

        // Should the app log visits and downloads? (since Piwigo 14)
        NetworkVars.shared.saveVisits = data.saveVisits ?? false

        return data.userName ?? ""
    }

    @concurrent
    func sessionLogout() async throws(PwgKitError) {
        JSONManager.logger.notice("Session: closing…")
        // Launch request
        let pwgData = try await postRequest(withMethod: pwgSessionLogout, paramDict: [:],
                                            jsonObjectClientExpectsToReceive: SessionLogoutJSON.self,
                                            countOfBytesClientExpectsToReceive: pwgSessionLogoutBytes)
        if !pwgData.success {
            throw .invalidCredentials
        }
    }
}
