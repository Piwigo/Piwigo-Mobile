//
//  NetworkTypes.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 18/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

/**
 Sometimes, the Piwigo server returns strings intead of inegers.
 - pwg.tags.getList returns tag IDs as inntegers
 - pwg.tags.getAdminList returns tag IDs as a string
 */
//
public enum Int32OrString: Codable
{
    case integer(Int32)
    case string(String)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(Int32.self) {
            self = .integer(x)
            return
        }
        if let x = try? container.decode(String.self) {
            self = .string(x)
            return
        }
        throw DecodingError.typeMismatch(Int32OrString.self,
                DecodingError.Context(codingPath: decoder.codingPath,
                                      debugDescription: "Wrong type for IntOrString"))
    }
}

extension Int32OrString {
    public var value: Int32 {
        switch self {
        case .integer(let int32):
            return int32
        case .string(let string):
            return Int32(string) ?? Int32(1)
        }
    }
}
