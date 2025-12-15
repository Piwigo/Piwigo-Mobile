//
//  pwg.tags.getList.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 20/07/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

public let pwgTagsGetList = "pwg.tags.getList"
public let pwgTagsGetAdminList = "pwg.tags.getAdminList"

// MARK: Piwigo JSON Structures
public struct TagJSON: Decodable {

    public var status: String?
    public var data = [TagProperties]()
    
    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case data = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }

    private enum ResultCodingKeys: String, CodingKey {
        case tags
    }

    public init(from decoder: Decoder) throws
    {
        // Root container keyed by RootCodingKeys
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
        
        // Status returned by Piwigo
        status = try rootContainer.decodeIfPresent(String.self, forKey: .status)
        if (status == "ok")
        {
            // Result container keyed by ResultCodingKeys
            let resultContainer = try rootContainer.nestedContainer(keyedBy: ResultCodingKeys.self, forKey: .data)
//            dump(resultContainer)
            
            // Decodes tags from the data and store them in the array
            try data = resultContainer.decode([TagProperties].self, forKey: .tags)
        }
        else if (status == "fail")
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

/**
 A struct for decoding JSON returned by pwgTagsGetList or pwgTagsGetAdminList.
 All members are optional in case they are missing from the data.
*/
public struct TagProperties: Decodable
{
    public let id: StringOrInt?             // 2 or "2"
    public let name: String?                // "Birthday"
    public let lastmodified: String?        // "2018-08-23 15:30:43"
    public let counter: Int64?              // 8

    // The following data is not stored in cache
    public let url_name: String?            // "birthday"
    public let url: String?                 // "https:…"
}
