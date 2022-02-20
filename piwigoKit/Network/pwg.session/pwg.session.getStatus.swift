//
//  pwg.session.getStatus.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 20/02/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - pwg.session.getStatus
public let kPiwigoSessionGetStatus = "format=json&method=pwg.session.getStatus"

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

// MARK: - Status Info
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
