//
//  pwg.categories.getImages.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 18/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

public let pwgCategoriesGetImages = "pwg.categories.getImages"

// MARK: Piwigo JSON Structures
public struct CategoriesGetImagesJSON: Decodable {

    public var status: String?
    public var paging: PageData?
    public var data = [ImagesGetInfo]()
    
    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case data = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }

    private enum ResultCodingKeys: String, CodingKey {
        case paging, images
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
            
            // Paging data
            paging = try resultContainer.decode(PageData.self, forKey: .paging)
            
            // Images data
            data = try resultContainer.decode([ImagesGetInfo].self, forKey: .images)
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

public struct PageData: Decodable
{
    // The following data is returned by pwg.categories.getImages
    public let page: Int16                  // 0
    public let perPage: Int16               // 32
    public let count: Int64                 // 232
    public let totalCount: StringOrInt?     // 443 or "443"

    public enum CodingKeys: String, CodingKey {
        case page, perPage = "per_page"
        case count, totalCount = "total_count"
    }
}
