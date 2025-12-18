//
//  pwg.users.favorites.addRemove.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 05/09/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

public let pwgUsersFavoritesAdd = "pwg.users.favorites.add"
public let pwgUsersFavoritesRemove = "pwg.users.favorites.remove"

// MARK: Piwigo JSON Structures
public struct FavoritesAddRemoveJSON: Decodable {

    public var status: String?
    public var success = false
    
    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case result
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
            success = try rootContainer.decode(Bool.self, forKey: .result)
            if success == false {
                let pwgError = PwgKitError.operationFailed
                let context = DecodingError.Context(codingPath: [], debugDescription: reason, underlyingError: pwgError)
                throw DecodingError.dataCorrupted(context)
            }
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
