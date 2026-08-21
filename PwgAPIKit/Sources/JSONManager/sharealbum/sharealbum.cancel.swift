//
//  sharealbum.cancel.swift
//  PwgAPIKit
//
//  Created by Eddy Lelièvre-Berna on 17/08/2026.
//

import Foundation
import PwgKit

public let kShareAlbumCancel = "sharealbum.cancel"

// MARK: Piwigo JSON Structures
public struct ShareAlbumCancelJSON: Decodable {

    public var status: String?
    public var success = false
    
    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case errorCode = "err"
        case errorMessage = "message"
    }
    
    public init(from decoder: any Decoder) throws
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
            // Retrieve Piwigo server error code
            let errorCode = try rootContainer.decode(Int.self, forKey: .errorCode)
            
            // An album which is not shared is a valid state, not an error
            /// (see kShareAlbumNotSharedError)
            /// The album is not shared any more, i.e. the expected result is achieved.
            if errorCode == kShareAlbumNotSharedError {
                success = true
                return
            }
            
            // Retrieve Piwigo server error message
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
