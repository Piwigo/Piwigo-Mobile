//
//  pwg.session.getStatus.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 20/02/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

public let pwgSessionGetStatus = "pwg.session.getStatus"
public let pwgSessionGetStatusBytes: Int64 = 7430

// MARK: Piwigo JSON Structures
public struct SessionGetStatusJSON: Decodable {

    public var status: String?
    public var data: StatusInfo?
    
    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case result
        case errorCode = "err"
        case errorMessage = "message"
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
            
            // Check Piwigo server version
            if let version = data?.version,
               version.compare(pwgMinVersion, options: .numeric) == .orderedAscending
            {
                let pwgError = PwgKitError.incompatiblePwgVersion
                let context = DecodingError.Context(codingPath: [], debugDescription: reason, underlyingError: pwgError)
                throw DecodingError.dataCorrupted(context)
            }
        }
        else if status == "fail"
        {
            // Retrieve Piwigo server error
            let errorCode = try rootContainer.decode(Int.self, forKey: .errorCode)
            let errorMessage = try rootContainer.decode(String.self, forKey: .errorMessage)
            let pwgError = PwgKitError.pwgError(code: errorCode, msg: errorMessage)
            let context = DecodingError.Context(codingPath: [], debugDescription: reason, underlyingError: pwgError)
            throw DecodingError.dataCorrupted(context)
        }
        else {
            // Unexpected Piwigo server error
            let pwgError = PwgKitError.unexpectedError
            let context = DecodingError.Context(codingPath: [], debugDescription: reason, underlyingError: pwgError)
            throw DecodingError.dataCorrupted(context)
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
    public let saveVisits: Bool?            // false
    
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
        case saveVisits = "save_visits"
    }
}
