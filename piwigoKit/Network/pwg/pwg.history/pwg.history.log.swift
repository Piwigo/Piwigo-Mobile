//
//  pwg.history.log.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 26/11/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation

public let pwgHistoryLog = "pwg.history.log"
public let pwgHistoryLogBytes: Int64 = 560

// MARK: Piwigo JSON Structures
public struct HistoryLogJSON: Decodable {

    public var status: String?
    public var success = false
    
    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case errorCode = "err"
        case errorMessage = "message"
    }
    
    public init(from decoder: Decoder) throws
    {
        // Root container keyed by RootCodingKeys
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
        
        // Status returned by Piwigo
        status = try rootContainer.decodeIfPresent(String.self, forKey: .status)
        if status == "ok"
        {
            success = true
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
