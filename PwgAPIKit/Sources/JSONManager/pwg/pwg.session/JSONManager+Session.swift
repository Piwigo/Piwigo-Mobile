//
//  JSONManager+Session.swift
//  PwgAPIKit
//
//  Created by Eddy Lelièvre-Berna on 27/06/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import os
import Foundation
import PwgKit

public extension JSONManager {
    
    @concurrent
    func sessionLogin(withUsername username:String, password:String) async throws(PwgKitError) {
#if DEBUG
        JSONManager.logger.notice("Session: logging in with username: \(username)…")
#else
        // Don't log the username in release builds (logs are now also stored in files)
        JSONManager.logger.notice("Session: logging in…")
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
        // Launch request
        let pwgData = try await postRequest(withMethod: pwgSessionGetStatus, paramDict: [:],
                                            jsonObjectClientExpectsToReceive: SessionGetStatusJSON.self,
                                            countOfBytesClientExpectsToReceive: pwgSessionGetStatusBytes)
        // No status returned?
        guard let data = pwgData.data
        else { throw .unknownUserStatus }

        // Update Piwigo token
        if let pwgToken = data.pwgToken {
            ServerVars.shared.pwgToken = pwgToken
        }
        
        // Default language
        ServerVars.shared.language = data.language ?? ""
        
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
        ServerVars.shared.pwgVersion = versionStr

        // API Keys conflict with HTTP Basic authentication in Piwigo 16.0
        if "16.0.0".compare(versionStr, options: .numeric) == .orderedSame {
            NetworkVars.shared.usesAPIkeys = false
        }
        
        // Retrieve charset used by the Piwigo server
        let charset = (data.charset ?? "UTF-8").uppercased()
        switch charset {
        case "UNICODE":
            ServerVars.shared.stringEncoding = String.Encoding.unicode.rawValue
        case "UNICODEFFFE":
            ServerVars.shared.stringEncoding = String.Encoding.utf16BigEndian.rawValue
        case "UTF-8":
            ServerVars.shared.stringEncoding = String.Encoding.utf8.rawValue
        case "UTF-16":
            ServerVars.shared.stringEncoding = String.Encoding.utf16.rawValue
        case "UTF-32":
            ServerVars.shared.stringEncoding = String.Encoding.utf32.rawValue
        case "ISO-2022-JP":
            ServerVars.shared.stringEncoding = String.Encoding.iso2022JP.rawValue
        case "ISO-8859-1":
            ServerVars.shared.stringEncoding = String.Encoding.windowsCP1252.rawValue
        case "ISO-8859-3":
            ServerVars.shared.stringEncoding = String.Encoding.isoLatin1.rawValue
        case "CP870":
            ServerVars.shared.stringEncoding = String.Encoding.isoLatin2.rawValue
        case "MACINTOSH":
            ServerVars.shared.stringEncoding = String.Encoding.macOSRoman.rawValue
        case "SHIFT-JIS":
            ServerVars.shared.stringEncoding = String.Encoding.shiftJIS.rawValue
        case "WINDOWS-1250":
            ServerVars.shared.stringEncoding = String.Encoding.windowsCP1250.rawValue
        case "WINDOWS-1251":
            ServerVars.shared.stringEncoding = String.Encoding.windowsCP1251.rawValue
        case "WINDOWS-1252":
            ServerVars.shared.stringEncoding = String.Encoding.windowsCP1252.rawValue
        case "WINDOWS-1253":
            ServerVars.shared.stringEncoding = String.Encoding.windowsCP1253.rawValue
        case "WINDOWS-1254":
            ServerVars.shared.stringEncoding = String.Encoding.windowsCP1254.rawValue
        case "X-EUC":
            ServerVars.shared.stringEncoding = String.Encoding.japaneseEUC.rawValue
        case "US-ASCII":
            ServerVars.shared.stringEncoding = String.Encoding.ascii.rawValue
        default:
            ServerVars.shared.stringEncoding = String.Encoding.utf8.rawValue
        }

        // Upload chunk size is null if not provided by server
        if var uploadChunkSize = data.uploadChunkSize, uploadChunkSize != 0 {
            uploadChunkSize = max(ServerVars.shared.minChunkSize, uploadChunkSize)
            uploadChunkSize = min(ServerVars.shared.maxChunkSize, uploadChunkSize)
            ServerVars.shared.uploadChunkSize = uploadChunkSize
        } else {
            ServerVars.shared.uploadChunkSize = 500    // i.e. 500 kB
        }
        
        // Initialise customUploadChunkSize if null
        if ServerVars.shared.customUploadChunkSize == 0 {
            ServerVars.shared.customUploadChunkSize = ServerVars.shared.uploadChunkSize
        }
        
        // Images and videos can be uploaded if their file types are found.
        // The iPhone creates mov files that will be uploaded in mp4 format.
        ServerVars.shared.serverFileTypes = data.uploadFileTypes ?? "jpg,jpeg,png,gif"
        
        // User rights are determined by Community extension (if installed)
        if let status = data.userStatus, status.isEmpty == false,
           let userStatus = pwgUserStatus(rawValue: status) {
            if ServerVars.shared.usesCommunityPluginV29 == false {
                ServerVars.shared.userStatus = userStatus
            }
        } else {
            throw .unknownUserStatus
        }

        // Retrieve the list of available sizes
        ServerVars.shared.hasSquareSizeImages  = data.imageSizes?.contains("square") ?? false
        ServerVars.shared.hasThumbSizeImages   = data.imageSizes?.contains("thumb") ?? false
        ServerVars.shared.hasXXSmallSizeImages = data.imageSizes?.contains("2small") ?? false
        ServerVars.shared.hasXSmallSizeImages  = data.imageSizes?.contains("xsmall") ?? false
        ServerVars.shared.hasSmallSizeImages   = data.imageSizes?.contains("small") ?? false
        ServerVars.shared.hasMediumSizeImages  = data.imageSizes?.contains("medium") ?? false
        ServerVars.shared.hasLargeSizeImages   = data.imageSizes?.contains("large") ?? false
        ServerVars.shared.hasXLargeSizeImages  = data.imageSizes?.contains("xlarge") ?? false
        ServerVars.shared.hasXXLargeSizeImages = data.imageSizes?.contains("xxlarge") ?? false
        ServerVars.shared.hasXXXLargeSizeImages = data.imageSizes?.contains("3xlarge") ?? false
        ServerVars.shared.hasXXXXLargeSizeImages = data.imageSizes?.contains("4xlarge") ?? false

        // Should the app log visits and downloads? (since Piwigo 14)
        ServerVars.shared.saveVisits = data.saveVisits ?? false

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
