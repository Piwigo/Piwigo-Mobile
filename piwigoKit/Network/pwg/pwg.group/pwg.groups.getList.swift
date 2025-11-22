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
    public var errorCode = 0
    public var errorMessage = ""

    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case data = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }

    private enum ResultCodingKeys: String, CodingKey {
        case paging, groups
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
            
            // Decodes paging and group data from the data and store them in the array
            do {
                // Paging data
                paging = try resultContainer.decode(PageData.self, forKey: .paging)
                
                // Images data
                groups = try resultContainer.decode([GroupsGetInfo].self, forKey: .groups)
            }
            catch {
                // Returns an empty array => No group
                errorCode = -1
                errorMessage = PwgKitError.wrongDataFormat.localizedDescription
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
            errorMessage = PwgKitError.invalidParameter.localizedDescription
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
