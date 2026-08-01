//
//  pwg.categories.getList.swift
//  PwgAPIKit
//
//  Created by Eddy Lelièvre-Berna on 05/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import PwgKit

public let pwgCategoriesGetList = "pwg.categories.getList"

// MARK: Piwigo JSON Structures
public struct CategoriesGetListJSON: Decodable {

    public var status: String?
    public var data = [CategoryGetInfo]()
    
    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case data = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }

    private enum ResultCodingKeys: String, CodingKey {
        case categories
    }

    public init(from decoder: any Decoder) throws
    {
        // Root container keyed by RootCodingKeys
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
        
        // Status returned by Piwigo
        status = try rootContainer.decodeIfPresent(String.self, forKey: .status)
        if (status == "ok")
        {
            // Result container keyed by ResultCodingKeys
            let resultContainer = try rootContainer.nestedContainer(keyedBy: ResultCodingKeys.self, forKey: .data)
//            dump(resultContainer)
            
            // Decodes categories from the data and store them in the array
            do {
                // Use TagGetInfo struct
                try data = resultContainer.decode([CategoryGetInfo].self, forKey: .categories)
            }
            catch {
                // Returns an empty array => No category
            }
        }
        else if (status == "fail")
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
