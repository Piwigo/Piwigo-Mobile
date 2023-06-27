//
//  pwg.session.getStatus.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 20/02/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

public let pwgSessionGetStatus = "format=json&method=pwg.session.getStatus"
fileprivate let pwgSessionGetStatusBytes: Int64 = 7430

// MARK: Piwigo JSON Structures
public struct SessionGetStatusJSON: Decodable {

    public var status: String?
    public var data: StatusInfo?
    public var errorCode = 0
    public var errorMessage = ""

    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case result
        case errorCode = "err"
        case errorMessage = "message"
    }
    
    private enum ErrorCodingKeys: String, CodingKey {
        case code = "code"
        case message = "msg"
    }

    public init(from decoder: Decoder) throws
    {
        // Root container keyed by RootCodingKeys
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
//        dump(rootContainer)

        // Status returned by Piwigo
        status = try rootContainer.decodeIfPresent(String.self, forKey: .status)
        if status == "ok"
        {
            // Decodes response from the data and store them in the array
            data = try rootContainer.decodeIfPresent(StatusInfo.self, forKey: .result)
        }
        else if status == "fail"
        {
            do {
                // Retrieve Piwigo server error
                errorCode = try rootContainer.decode(Int.self, forKey: .errorCode)
                errorMessage = try rootContainer.decode(String.self, forKey: .errorMessage)
            }
            catch {
                // Error container keyed by ErrorCodingKeys ("format=json" forgotten in call)
                let errorContainer = try rootContainer.nestedContainer(keyedBy: ErrorCodingKeys.self, forKey: .errorCode)
                errorCode = Int(try errorContainer.decode(String.self, forKey: .code)) ?? NSNotFound
                errorMessage = try errorContainer.decode(String.self, forKey: .message)
            }
        }
        else {
            // Unexpected Piwigo server error
            errorCode = -1
            errorMessage = NSLocalizedString("serverUnknownError_message", comment: "Unexpected error encountered while calling server method with provided parameters.")
        }
    }
}

public struct StatusInfo: Decodable
{
    public let version: String?             // "12.2.0"
    public let charset: String?             // "utf-8"
    public let language: String?            // "fr_FR"
    public let pwgToken: String?            // "8814066d722b4ce75aaa5110e0019b9f"
    public let dateTime: String?            // "2022-02-19 23:04:17"
    public let userName: String?            // "Eddy"
    public let userStatus: String?          // "webmaster"
    public let theme: String?               // "bootstrap_darkroom"
    public let imageSizes: [String]?        // ["square", "thumb",…]
    public let uploadFileTypes: String?     // "jpg,jpeg,png,gif,tif,tiff,mp4,m4v,mpg,ogg,ogv,webm,webmv,strm"
    public let uploadChunkSize: Int?        // 1024
    
    public enum CodingKeys: String, CodingKey {
        case version
        case charset
        case language
        case pwgToken = "pwg_token"
        case dateTime = "current_datetime"
        case userName = "username"
        case userStatus = "status"
        case theme
        case imageSizes = "available_sizes"
        case uploadFileTypes = "upload_file_types"
        case uploadChunkSize = "upload_form_chunk_size"
    }
}


// MARK: - Piwigo Method Caller
extension PwgSession
{    
    public func sessionGetStatus(completion: @escaping (String) -> Void,
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
}
