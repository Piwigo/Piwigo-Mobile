//
//  community.session.getStatus.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 19/02/2022.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

public let kCommunitySessionGetStatus = "community.session.getStatus"
public let kCommunitySessionGetStatusBytes: Int64 = 2100

// MARK: Piwigo JSON Structures
public struct CommunitySessionGetStatusJSON: Decodable
{    
    public var status: String?
    public var realUser = ""        // "webmaster"
    public var uploadMethod = ""    // "pwg.categories.getAdminList"
    
    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case result = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }

    private enum ResultCodingKeys: String, CodingKey {
        case realUser = "real_user_status"
        case uploadMethod = "upload_categories_getList_method"
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
            let resultContainer = try rootContainer.nestedContainer(keyedBy: ResultCodingKeys.self, forKey: .result)
//            dump(resultContainer)
            
            // Decodes pending properties from the data and store them in the array
            try realUser = resultContainer.decode(String.self, forKey: .realUser)
            try uploadMethod = resultContainer.decode(String.self, forKey: .uploadMethod)
        }
        else if (status == "fail")
        {
            // Retrieve Piwigo server error
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
