//
//  TagGetInfo.swift
//  PwgKit
//
//  Created by Eddy Lelièvre-Berna on 17/05/2026.
//


/**
 A struct for decoding JSON returned by pwgTagsGetList or pwgTagsGetAdminList.
 All members are optional in case they are missing from the data.
*/
public struct TagGetInfo: Decodable, Sendable
{
    public let id: StringOrInt?             // 2 or "2"
    public let name: String?                // "Birthday"
    public let lastmodified: String?        // "2018-08-23 15:30:43"
    public let counter: Int64?              // 8

    // The following data is not stored in cache
    public let url_name: String?            // "birthday"
    public let url: String?                 // "https:…"
}

extension TagGetInfo {
    public init(id: StringOrInt, name: String,
                lastmodified: String = "", counter: Int64 = 0,
                url_name: String = "", url: String = "") {
        self.id = id
        self.name = name
        self.lastmodified = lastmodified
        self.counter = counter
        self.url_name = url_name
        self.url = url
    }
}
