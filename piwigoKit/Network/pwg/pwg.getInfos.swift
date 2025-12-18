//
//  pwg.getInfos.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 23/08/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

public let pwgGetInfos = "pwg.getInfos"

// MARK: Piwigo JSON Structures
public struct GetInfosJSON: Decodable {
    
    public var status: String?
    public var data = [InfoKeyValue]()
    
    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case data = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }
    
    private enum ResultCodingKeys: String, CodingKey {
        case infos
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
            
            // Decodes infos from the data and store them in the array
            try data = resultContainer.decode([InfoKeyValue].self, forKey: .infos)
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
 A struct for decoding JSON returned by pwgGetInfos.
 All members are optional in case they are missing from the data.
*/
public struct InfoKeyValue: Decodable
{
    public let name: String?        // "version"
    public let value: StringOrInt?  // "11.5.0" or 23
}
