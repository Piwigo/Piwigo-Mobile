//
//  pwg.images.setCategory.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 17/02/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation

public let pwgImagesSetCategory = "pwg.images.setCategory"
public let pwgImagesSetCategoryBytes: Int64 = 610

public enum pwgImagesSetCategoryAction: String {
    case associate
    case dissociate
    case move
}

// MARK: Piwigo JSON Structures
public struct ImagesSetCategoryJSON: Decodable {

    public var status: String?
    public var success = false
    
    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
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
