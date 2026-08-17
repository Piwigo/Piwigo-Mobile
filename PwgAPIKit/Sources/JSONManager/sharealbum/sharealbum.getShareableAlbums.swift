//
//  sharealbum.getShareableAlbums .swift
//  PwgAPIKit
//
//  Created by Eddy Lelièvre-Berna on 15/08/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import Foundation
import PwgKit

public let kShareAlbumGetShareable = "sharealbum.getShareableAlbums"

// MARK: Piwigo JSON Structures
public struct ShareAlbumGetShareableJSON: Decodable {

    public var status: String?
    public var data = [ShareAlbumGetShareable]()
    
    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case data = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }

    private enum ResultCodingKeys: String, CodingKey {
        case shareable_albums
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
            dump(resultContainer)
            
            // Decodes shared albums from the data and store them in the array
            do {
                // Use ShareAlbumGetShareable struct
                try data = resultContainer.decode([ShareAlbumGetShareable].self, forKey: .shareable_albums)
            }
            catch {
                // Returns an empty array => No shared album
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


public struct ShareAlbumGetShareable: Decodable, Sendable
{
    // The following data is returned by sharealbum.getList
    public let catID: StringOrInt?          // "5"
    public let name: String?                // "People"
//    public let comment: String?             // "Movies in different formats"
//    public let dir: ?
    public let status: String?              // "private"
//    public rank: StringOrInt?               // "1"
//    public globalRank: String?              // 22.1
//    public siteID: ?
    public let visible: Bool?               // true
//    public commentable
    
//    public let parentID: StringOrInt?       // "4"
//    public let upperCats: String?           // "43"
//    public let thumbnailId: String?         // "166"

//    public let imageSort: String?           // "date_creation ASC, file ASC, id ASC"
//    public let permalink: String?
//    public let lastModified: Strings?       // "2026-08-17 18:07:56"
//    public let communityUSer: ?
//    public let albumPath: String?

    public enum CodingKeys: String, CodingKey, Sendable {
        case catID = "id"
        case name = "name"
//        case comment
//        case dir
        case status
//        case rank
//        case globalRank = "global_rank"
//        case site_id
        case visible
//        case commentable

//        case parentID = "id_uppercat"
//        case upperCats = "uppercats"
//        case thumbnailId = "representative_picture_id"

//        case imageSort = "image_order"
//        case permalink
//        case lastModified = "lastmodified"
//        case communityUser = "community_user"
//        case albumPath = "album_path"
    }
}
