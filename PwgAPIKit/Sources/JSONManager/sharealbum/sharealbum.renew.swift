//
//  sharealbum.renew.swift
//  PwgAPIKit
//
//  Created by Eddy Lelièvre-Berna on 17/08/2026.
//

import Foundation
import PwgKit

public let kShareAlbumRenew = "sharealbum.renew"

// MARK: Piwigo JSON Structures
public struct ShareAlbumRenewJSON: Decodable {

    public var status: String?
    public var isShared = false
    public var data: ShareAlbumCreate?
    
    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case data = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }
    
    public init(from decoder: any Decoder) throws
    {
        // Root container keyed by RootCodingKeys
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
        
        // Status returned by Piwigo
        status = try rootContainer.decodeIfPresent(String.self, forKey: .status)
        if (status == "ok")
        {
            // Decodes shared album infos from the data and store them in the array
            do {
                // Use ShareAlbumCreate struct
                data = try rootContainer.decodeIfPresent(ShareAlbumCreate.self, forKey: .data)
                isShared = true
            }
            catch {
                // Returns a nil object
            }
        }
        else if (status == "fail")
        {
            // Retrieve Piwigo server error code
            let errorCode = try rootContainer.decode(Int.self, forKey: .errorCode)
            
            // An album which is not shared is a valid state, not an error
            /// (see kShareAlbumNotSharedError)
            /// The share code could not be renewed because there is no share to renew:
            /// returns an object whose isShared property is false and data property is nil.
            if errorCode == kShareAlbumNotSharedError { return }
            
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
