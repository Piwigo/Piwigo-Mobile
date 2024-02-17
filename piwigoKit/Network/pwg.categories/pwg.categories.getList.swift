//
//  pwg.categories.getList.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 05/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

public let pwgCategoriesGetList = "format=json&method=pwg.categories.getList"

// MARK: Piwigo JSON Structures
public struct CategoriesGetListJSON: Decodable {

    public var status: String?
    public var data = [CategoryData]()
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
            
            // Decodes categories from the data and store them in the array
            do {
                // Use TagProperties struct
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

public struct CategoryData: Decodable
{
    // The following data is returned by pwg.categories.getList
    public var id: Int32?                   // 32
    public let name: String?                // "Insects & Spiders"
    public let comment: String?             // "…" i.e. text potentially containing HTML encoded characters
//    public let status: String?              // "public"
    public let globalRank: String?          // "11.2.1" i.e. 11th album in root, 2nd sub-album, 1st sub-sub-album

    public let upperCat: String?            // "41"
    public let upperCats: String?           // "32"

    public let nbImages: Int64?             // 6
    public let totalNbImages: Int64?        // 6
    public let nbCategories: Int32?         // 0

//    public let permalink: String?           // "insects-spiders"
//    public let pageUrl: String?             // "https:…"
    public let thumbnailId: String?         // "236"
    public let thumbnailUrl: String?        // "https:…"

    public let dateLast: String?            // "yyyy-MM-dd HH:mm:ss"
//    public let maxDateLast: String?         // "yyyy-MM-dd HH:mm:ss"

    // The following data is returned by community.categories.getList
//    public let id: Int?                     // 32
//    public let name: String?                // "Insects & Spiders"
//    public let comment: String?             // "…"
//    public let globalRank: String?          // "1"

//    public let uppercats: String?           // "32"

//    public let nbImages: Int?               // 6
//    public let totalNbImages: Int?          // 6
//    public let nbCategories: Int?           // 0

//    public let permalink: String?           // null

//    public let dateLast: String?            // "yyyy-MM-dd HH:mm:ss"
//    public let maxDateLast: String?         // "yyyy-MM-dd HH:mm:ss"

    // Used to identify album with upload rights
    public var hasUploadRights = false

    public enum CodingKeys: String, CodingKey {
        case id, name, comment //, status
        case globalRank = "global_rank"
        
        case upperCat = "id_uppercat"
        case upperCats = "uppercats"
        
        case nbImages = "nb_images"
        case totalNbImages = "total_nb_images"
        case nbCategories = "nb_categories"

//        case permalink
//        case pageUrl = "url"
        case thumbnailId = "representative_picture_id"
        case thumbnailUrl = "tn_url"

        case dateLast = "date_last"
//        case maxDateLast = "max_date_last"
    }
    
    public init(withId albumId: Int32,
                albumName: String = NSLocalizedString("tabBar_albums", comment: "Albums"),
                albumComment: String = "", albumRank: String = "",
                parentId: String = "\(Int32.min)", parentIds: String = "",
                nberImages: Int64 = Int64.zero, totalNberImages: Int64 = Int64.min) {
        id = albumId
        name = pwgSmartAlbum(rawValue: albumId)?.name ?? albumName
        comment = albumComment
        globalRank = albumId <= 0 ? "0" : (parentId == "0" ? "0" : albumRank + ".0")
        upperCat = parentId
        upperCats = parentIds
        nbImages = nberImages
        totalNbImages = totalNberImages
        nbCategories = Int32.zero
        thumbnailId = ""
        thumbnailUrl = ""
        dateLast = ""
    }
}
