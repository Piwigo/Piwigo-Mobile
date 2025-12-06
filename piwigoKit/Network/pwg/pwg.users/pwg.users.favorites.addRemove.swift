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
    public var result = false
    
    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case result
        case errorCode = "err"
        case errorMessage = "message"
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
        if status == "ok"
        {
            success = true
            result = try rootContainer.decode(Bool.self, forKey: .result)
        }
        else if status == "fail"
        {
            do {
                // Retrieve Piwigo server error
                let errorCode = try rootContainer.decode(Int.self, forKey: .errorCode)
                let errorMessage = try rootContainer.decode(String.self, forKey: .errorMessage)
                throw PwgKitError.pwgError(code: errorCode, msg: errorMessage)
            }
            catch {
                // Error container keyed by ErrorCodingKeys ("format=json" forgotten in call)
                let errorContainer = try rootContainer.nestedContainer(keyedBy: ErrorCodingKeys.self, forKey: .errorCode)
                let errorCode = Int(try errorContainer.decode(String.self, forKey: .code)) ?? NSNotFound
                let errorMessage = try errorContainer.decode(String.self, forKey: .message)
                throw PwgKitError.pwgError(code: errorCode, msg: errorMessage)
            }
        }
        else {
            // Unexpected Piwigo server error
            throw PwgKitError.unexpectedError
        }
    }
}
