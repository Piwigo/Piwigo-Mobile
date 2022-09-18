//
//  pwg.tags.getList.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 20/07/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - pwg.tags.getList & pwg.tags.getAdminList
public let kPiwigoTagsGetList = "format=json&method=pwg.tags.getList"
public let kPiwigoTagsGetAdminList = "format=json&method=pwg.tags.getAdminList"

public struct TagJSON: Decodable {

    public var status: String?
    public var data = [TagProperties]()
    public var errorCode = 0
    public var errorMessage = ""

    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case data = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }

    private enum ResultCodingKeys: String, CodingKey {
        case tags
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
                try data = resultContainer.decode([TagProperties].self, forKey: .tags)
            }
            catch {
                // Use a different struct because id is a String instead of an Int
                let tagPropertiesArray4Admin = try resultContainer.decode([TagProperties4Admin].self, forKey: .tags)
                
                // Inject data into TagProperties after converting id
                for tagProperty4Admin in tagPropertiesArray4Admin {
                    let id:Int32? = Int32(tagProperty4Admin.id ?? "")!
                    let tagProperty = TagProperties(id: id, name: tagProperty4Admin.name, lastmodified: tagProperty4Admin.lastmodified, counter: Int64.max, url_name: tagProperty4Admin.url_name, url: "")
                    data.append(tagProperty)
                }
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

/**
 A struct for decoding JSON returned by kPiwigoTagsGetList.
 All members are optional in case they are missing from the data.
*/
public struct TagProperties: Decodable
{
    public let id: Int32?                  // 1
    public let name: String?               // "Birthday"
    public let lastmodified: String?       // "2018-08-23 15:30:43"
    public let counter: Int64?             // 8

    // The following data is not stored in cache
    public let url_name: String?           // "birthday"
    public let url: String?                // "https:…"
}

/**
 A struct for decoding JSON returned by kPiwigoTagsGetAdminList:
 All members are optional in case they are missing from the data.
*/
private struct TagProperties4Admin: Decodable
{
    public let id: String?                 // 1 (String instead of Int)
    public let name: String?               // "Birthday"
    public let lastmodified: String?       // "2018-08-23 15:30:43"

    // The following data is not stored in cache
    public let url_name: String?           // "birthday"
}
