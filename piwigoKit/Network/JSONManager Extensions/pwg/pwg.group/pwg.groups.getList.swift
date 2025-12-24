//
//  pwg.groups.getList.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 14/06/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation

public let pwgGroupsGetList = "pwg.groups.getList"

// MARK: Piwigo JSON Structures
public struct GroupsGetListJSON: Decodable {

    public var status: String?
    public var paging: PageData?
    public var groups = [GroupsGetInfo]()
    public var totalCount: Int?
    
    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case data = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }

    private enum ResultCodingKeys: String, CodingKey {
        case paging, groups
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
            groups = try resultContainer.decode([GroupsGetInfo].self, forKey: .groups)
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

public struct GroupsGetInfo: Decodable
{
    public let id: StringOrInt?                     // 1
    public let name: String?                        // "Group"
    public let isDefault: StringOrBool?             // "false"
    public let lastModified: String?                // "2025-02-16 17:39:07"
    public let nbUsers: StringOrInt?                // "2"

    public enum CodingKeys: String, CodingKey {
        case id = "id"
        case name = "name"
        case isDefault = "is_default"
        case lastModified = "lastmodified"
        case nbUsers = "nb_users"
    }
}
