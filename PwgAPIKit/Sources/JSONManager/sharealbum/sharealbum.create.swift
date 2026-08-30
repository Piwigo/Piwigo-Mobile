//
//  sharealbum.create.swift
//  PwgAPIKit
//
//  Created by Eddy Lelièvre-Berna on 17/08/2026.
//

import Foundation
import PwgKit

public let kShareAlbumCreate = "sharealbum.create"

// MARK: Piwigo JSON Structures
public struct ShareAlbumCreateJSON: Decodable {

    public var status: String?
    public var isAlreadyShared = false
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
            }
            catch {
                // Returns a nil object
            }
        }
        else if (status == "fail")
        {
            // Retrieve Piwigo server error code
            let errorCode = try rootContainer.decode(Int.self, forKey: .errorCode)
            
            // An album which is already shared is a valid state, not an error
            /// (see kShareAlbumAlreadySharedError)
            /// The existing share is not returned by this method: returns an object whose
            /// isAlreadyShared property is true and data property is nil, so that the caller
            /// retrieves the share URL with sharealbum.getInfo.
            if errorCode == kShareAlbumAlreadySharedError {
                isAlreadyShared = true
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

public struct ShareAlbumCreate: Decodable, Sendable
{
    // The following data is returned by sharealbum.getList
    public var catID: StringOrInt?          // "43"
    public let shareUrl: String?            // "https://piwigo.lelievre-berna.net/16.x/?xauth=ywurvkpypsce"
    public let shareCode: String?           // "hvtEixyxCmqF"
    
    public enum CodingKeys: String, CodingKey, Sendable {
        case catID = "category_id"
        case shareUrl = "share_url"
        case shareCode = "share_code"
    }
}
