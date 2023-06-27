//
//  pwg.categories.getImages.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 18/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - pwg.categories.getImages
public let pwgCategoriesGetImages = "format=json&method=pwg.categories.getImages"

public struct CategoriesGetImagesJSON: Decodable {

    public var status: String?
    public var paging: PageData?
    public var data = [ImagesGetInfo]()
    public var errorCode = 0
    public var errorMessage = ""

    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case data = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }

    private enum ResultCodingKeys: String, CodingKey {
        case paging, images
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
            let resultContainer = try rootContainer.nestedContainer(keyedBy: ResultCodingKeys.self, forKey: .data)
//            dump(resultContainer)
            
            // Decodes paging and image data from the data and store them in the array
            do {
                // Paging data
                paging = try resultContainer.decode(PageData.self, forKey: .paging)
                
                // Images data
                data = try resultContainer.decode([ImagesGetInfo].self, forKey: .images)
            }
            catch {
                // Returns an empty array => No category
                errorCode = -1
                errorMessage = ImageError.wrongDataFormat.localizedDescription
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

// MARK: - Page Data
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
