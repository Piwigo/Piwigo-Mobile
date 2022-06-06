//
//  pwg.categories.getList.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 05/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - pwg.categories.getList
public let kPiwigoCategoriesGetList = "format=json&method=pwg.categories.getList"

public struct CategoriesGetListJSON: Decodable {

    public var status: String?
    public var data = [Album]()
    public var errorCode = 0
    public var errorMessage = ""

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
            
            // Decodes tags from the data and store them in the array
            do {
                // Use TagProperties struct
                try data = resultContainer.decode([Album].self, forKey: .categories)
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

// MARK: - Category
public struct Album: Decodable
{
    public let id: Int?                     // 32

    // The following data is returned by pwg.images.getInfo
    public let name: String?                // "Insects & Spiders"
    public let uppercats: String?           // "32"
    public let globalRank: String?          // "1"
    public let url: String?                 // "https:…"
    public let pageUrl: String?             // "https:…"
    public let permalink: String?           // null

    // The following additional data is returned by community.categories.getList
    public let comment: String?             // "…"
    public let nbImages: Int?               // 6
    public let totalNbImages: Int?          // 6
    public let dateLast: String?            // "yyyy-MM-dd HH:mm:ss"
    public let maxDateLast: String?         // "yyyy-MM-dd HH:mm:ss"
    public let nbCategories: Int?           // 0

    // The following additional data is returned by pwg.categories.getList
    public let upperCat: String?            // "41"
    public let thumbnailId: String?         // "236"
    public let thumbnailUrl: String?        // "https:…"

    public enum CodingKeys: String, CodingKey {
        case id, name, permalink, uppercats
        case globalRank = "global_rank"
        case url
        case pageUrl = "page_url"
        case comment
        case nbImages = "nb_images"
        case totalNbImages = "total_nb_images"
        case dateLast = "date_last"
        case maxDateLast = "max_date_last"
        case nbCategories = "nb_categories"
        case upperCat = "id_uppercat"
        case thumbnailId = "representative_picture_id"
        case thumbnailUrl = "tn_url"
    }
}
