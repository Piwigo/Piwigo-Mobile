//
//  community.session.getStatus.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 19/02/2022.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - community.images.uploadCompleted
public let kCommunitySessionGetStatus = "format=json&method=community.session.getStatus"

public struct CommunitySessionGetStatusJSON: Decodable {
    
    public var status: String?
    public var realUser = ""        // "webmaster"
    public var uploadMethod = ""    // "pwg.categories.getAdminList"
    public var errorCode = 0
    public var errorMessage = ""

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
            do {
                // Use ComImageProperties struct
                try realUser = resultContainer.decode(String.self, forKey: .realUser)
                try uploadMethod = resultContainer.decode(String.self, forKey: .uploadMethod)
            }
            catch {
                errorCode = -1
                errorMessage = NSLocalizedString("serverUnknownError_message", comment: "Unexpected error encountered while calling server method with provided parameters.")
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
