//
//  CategoryGetInfo.swift
//  PwgKit
//
//  Created by Eddy Lelièvre-Berna on 17/05/2026.
//

import Foundation

public struct CategoryGetInfo: Decodable, Sendable
{
    // The following data is returned by pwg.categories.getList
    public var id: Int32?                   // 32
    public let name: String?                // "Insects & Spiders"
    public let comment: String?             // "…" i.e. text potentially containing HTML encoded characters, selected language
    public let commentRaw: String?          // "…" i.e. text potentially containing HTML encoded characters, all languages
    //    public let status: String?              // "public"
    public let globalRank: String?          // "11.2.1" i.e. 11th album in root, 2nd sub-album, 1st sub-sub-album
    
    public let upperCat: String?            // "41"
    public let upperCats: String?           // "32"
    
    public let imageSort: String?           // "date_creation ASC, file ASC, id ASC"
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
    
    public enum CodingKeys: String, CodingKey, Sendable {
        case id
        case name
        case comment
        case commentRaw = "comment_raw"
        //        case status
        case globalRank = "global_rank"
        
        case upperCat = "id_uppercat"
        case upperCats = "uppercats"
        
        case imageSort = "image_order"
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
}

extension CategoryGetInfo {
    public init(withId albumId: Int32,
                albumName: String? = nil,
                albumComment: String = "", albumRank: String = "",
                parentId: String = "\(Int32.min)", parentIds: String = "",
                nberImages: Int64 = Int64.zero, totalNberImages: Int64 = Int64.min) {
        id = albumId
        name = pwgSmartAlbum(rawValue: albumId)?.name
            ?? albumName
            ?? String(localized: "tabBar_albums", bundle: .pwgKit, comment: "Albums")
        comment = albumComment
        commentRaw = albumComment
        globalRank = albumId <= 0 ? "0" : (parentId == "0" ? "0" : albumRank + ".0")
        upperCat = parentId
        upperCats = parentIds
        imageSort = ""
        nbImages = nberImages
        totalNbImages = totalNberImages
        nbCategories = Int32.zero
        thumbnailId = ""
        thumbnailUrl = ""
        dateLast = ""
    }
}
