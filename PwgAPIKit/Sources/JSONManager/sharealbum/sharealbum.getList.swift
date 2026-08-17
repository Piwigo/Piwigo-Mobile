//
//  sharealbum.getList.swift
//  PwgAPIKit
//
//  Created by Eddy Lelièvre-Berna on 15/08/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import Foundation
import PwgKit

public let kShareAlbumGetList = "sharealbum.getList"

// MARK: Piwigo JSON Structures
public struct ShareAlbumGetListJSON: Decodable {

    public var status: String?
    public var data = [ShareAlbumGetInfo]()
    
    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case data = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }

    private enum ResultCodingKeys: String, CodingKey {
        case shared_albums
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
            
            // Decodes shared albums from the data and store them in the array
            do {
                // Use TagGetInfo struct
                try data = resultContainer.decode([ShareAlbumGetInfo].self, forKey: .shared_albums)
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


public struct ShareAlbumGetInfo: Decodable, Sendable
{
    // The following data is returned by sharealbum.getList
    public var pwgID: StringOrInt?          // "2"
    public var catID: StringOrInt?          // "43"
    public let name: String?                // "People"
    public let upperCats: String?           // "43"
    
    public let creationDate: String?        // "2026-08-15 17:41:44"
    public let visits: StringOrInt?         // "2"
    public let lastVisit: String?           // "2026-08-15 17:20:11"
    public let createdBy: StringOrInt?      // "1"
    public let createdByName: String?       // "Eddy"
    
    public let shareUrl: String?            // "https://piwigo.lelievre-berna.net/16.x/?xauth=ywurvkpypsce"
    public let path: String?                // "People"
    
    public enum CodingKeys: String, CodingKey, Sendable {
        case pwgID = "id"
        case catID = "category_id"
        case name = "album_name"
        case upperCats = "uppercats"
        
        case creationDate = "creation_date"
        case visits = "visits"
        case lastVisit = "last_visit"
        case createdBy = "created_by"
        case createdByName = "created_by_username"
        
        case shareUrl = "share_url"
        case path = "album_path"
    }
}
