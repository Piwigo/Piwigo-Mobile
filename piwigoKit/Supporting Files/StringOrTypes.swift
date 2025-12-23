//
//  StringOrTypes.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 26/03/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation

public enum StringOrBool: Codable {
    case boolean(Bool)
    case string(String)
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(Bool.self) {
            self = .boolean(x)
            return
        }
        if let x = try? container.decode(String.self) {
            self = .string(x)
            return
        }
        throw DecodingError.typeMismatch(StringOrBool.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for Value"))
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .boolean(let x):
            try container.encode(x)
        case .string(let x):
            try container.encode(x)
        }
    }
    
    public var stringValue: String {
        switch self {
        case .boolean(let x):
            return x ? "true" : "false"
        case .string(let x):
            return x
        }
    }

    public var boolValue: Bool {
        switch self {
        case .boolean(let x):
            return x
        case .string(let x):
            return (x.lowercased() == "true" ? true : false)
        }
    }
}

public enum StringOrInt: Codable {
    case integer(Int)
    case string(String)

    public init(from decoder: any Decoder) throws {
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

    public func encode(to encoder: any Encoder) throws {
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
    
    public var int32Value: Int32? {
        switch self {
        case .integer(let x):
            return Int32(x)
        case .string(let x):
            return Int32(x)
        }
    }
    
    public var int64Value: Int64? {
        switch self {
        case .integer(let x):
            return Int64(x)
        case .string(let x):
            return Int64(x)
        }
    }
}

public enum StringOrDouble: Codable {
    case double(Double)
    case string(String)

    public init() {
        self = .double(0)
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(Double.self) {
            self = .double(x)
            return
        }
        if let x = try? container.decode(String.self) {
            self = .string(x)
            return
        }
        throw DecodingError.typeMismatch(StringOrInt.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for Value"))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .double(let x):
            try container.encode(x)
        case .string(let x):
            try container.encode(x)
        }
    }
    
    public var stringValue: String {
        switch self {
        case .double(let x):
            return String(x)
        case .string(let x):
            return x
        }
    }

    public var doubleValue: Double {
        switch self {
        case .double(let x):
            return x
        case .string(let x):
            return Double(x) ?? Double.nan
        }
    }
}
