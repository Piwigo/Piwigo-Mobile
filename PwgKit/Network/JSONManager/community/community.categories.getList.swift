//
//  community.categories.getList.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 05/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

public let kCommunityCategoriesGetList = "community.categories.getList"

// MARK: Piwigo JSON Structures
public struct CommunityCategoriesGetListJSON: Decodable {

    public var status: String?
    public var data = [CategoryData]()
    
    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case data = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }

    private enum ResultCodingKeys: String, CodingKey {
        case categories
    }

    private enum ErrorCodingKeys: String, CodingKey {
        case code = "code"
        case message = "msg"
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
                // Use CategoryData struct
                try data = resultContainer.decode([CategoryData].self, forKey: .categories)
            }
            catch {
                // Returns an empty array => No category
            }
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
