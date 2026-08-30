//
//  ShareAlbumGetInfo.swift
//  PwgKit
//
//  Created by Eddy Lelièvre-Berna on 21/08/2026.
//


/**
 A struct for decoding JSON returned by kShareAlbumGetList or kShareAlbumgetInfo.
 All members are optional in case they are missing from the data.
*/
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
