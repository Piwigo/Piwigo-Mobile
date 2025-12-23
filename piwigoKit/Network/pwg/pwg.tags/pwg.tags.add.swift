//
//  pwg.tags.add.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 20/07/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

public let pwgTagsAdd = "pwg.tags.add"

// MARK: Piwigo JSON Structures
public struct TagAddJSON: Decodable {

    public var status: String?
    public var data = TagPropertiesAdd(id: 0, info: "")
    
    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case data = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }

    private enum ResultCodingKeys: String, CodingKey {
        case tags
    }
    
    public init(from decoder: any Decoder) throws
    {
        // Root container keyed by RootCodingKeys
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
        
        // Status returned by Piwigo
        status = try rootContainer.decodeIfPresent(String.self, forKey: .status)
        if (status == "ok")
        {
            // Decodes tags from the data and store them in the array
            try data = rootContainer.decode(TagPropertiesAdd.self, forKey: .data)
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
 A struct for decoding JSON returned by pwgTagsAdd:
 All members are optional in case they are missing from the data.
*/
public struct TagPropertiesAdd: Decodable
{
    public let id: Int32?                  // 1
    
    // The following data is not stored in cache
    public let info: String?               // "Birthday"
}
