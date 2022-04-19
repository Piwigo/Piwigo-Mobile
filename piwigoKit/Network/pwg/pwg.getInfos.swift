//
//  pwg.getInfos.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 23/08/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - pwg.getInfos
public let kPiwigoGetInfos = "format=json&method=pwg.getInfos"

public struct GetInfosJSON: Decodable {
    
    public var status: String?
    public var data = [InfoKeyValue]()
    public var errorCode = 0
    public var errorMessage = ""

    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case data = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }
    
    private enum ResultCodingKeys: String, CodingKey {
        case infos
    }

    private enum ErrorCodingKeys: String, CodingKey {
        case code = "code"
        case message = "msg"
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
            do {
                // Use TagProperties struct
                try data = resultContainer.decode([InfoKeyValue].self, forKey: .infos)
            }
            catch {
                // Could not decode JSON data
            }
        }
        else if (status == "fail")
        {
            // Retrieve Piwigo server error
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

/**
 A struct for decoding JSON returned by kPiwigoGetinfos.
 All members are optional in case they are missing from the data.
*/
public struct InfoKeyValue: Decodable
{
    public let name: String?        // "version"
    public let value: StringOrInt?  // "11.5.0"
}

public enum StringOrInt: Codable {
    case integer(Int)
    case string(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(Int.self) {
            self = .integer(x)
            return
        }
        if let x = try? container.decode(String.self) {
            self = .string(x)
            return
        }
        throw DecodingError.typeMismatch(StringOrInt.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for Value"))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .integer(let x):
            try container.encode(x)
        case .string(let x):
            try container.encode(x)
        }
    }
    
    public var stringValue: String {
        switch self {
        case .integer(let x):
            return String(x)
        case .string(let x):
            return x
        }
    }

    public var intValue: Int {
        switch self {
        case .integer(let x):
            return x
        case .string(let x):
            return Int(x) ?? NSNotFound
        }
    }
}
