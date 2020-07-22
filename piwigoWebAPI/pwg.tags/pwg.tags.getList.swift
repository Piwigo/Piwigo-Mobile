//
//  pwg.tags.getList.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 20/07/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - pwg.tags.getList & pwg.tags.getAdminList
let kPiwigoTagsGetList = "format=json&method=pwg.tags.getList"
let kPiwigoTagsGetAdminList = "format=json&method=pwg.tags.getAdminList"

struct TagJSON: Decodable {

    private enum RootCodingKeys: String, CodingKey {
        case stat
        case result
        case err
        case message
    }

    private enum ResultCodingKeys: String, CodingKey {
        case tags
    }

    // Constants
    var stat: String?
    var errorCode = 0
    var errorMessage = ""
    
    // A TagProperties array of decoded Tag data.
    var tagPropertiesArray = [TagProperties]()

    init(from decoder: Decoder) throws
    {
        // Root container keyed by RootCodingKeys
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
        
        // Status returned by Piwigo
        stat = try rootContainer.decodeIfPresent(String.self, forKey: .stat)
        if (stat == "ok")
        {
            // Result container keyed by ResultCodingKeys
            let resultContainer = try rootContainer.nestedContainer(keyedBy: ResultCodingKeys.self, forKey: .result)
//            dump(resultContainer)
            
            // Decodes tags from the data and store them in the array
            do {
                // Use TagProperties struct
                try tagPropertiesArray = resultContainer.decode([TagProperties].self, forKey: .tags)
            }
            catch {
                // Use a different struct because id is a String instead of an Int
                let tagPropertiesArray4Admin = try resultContainer.decode([TagProperties4Admin].self, forKey: .tags)
                
                // Inject data into TagProperties after converting id
                for tagProperty4Admin in tagPropertiesArray4Admin {
                    let id:Int32? = Int32(tagProperty4Admin.id ?? "")!
                    let tagProperty = TagProperties(id: id, name: tagProperty4Admin.name, lastmodified: tagProperty4Admin.lastmodified, counter: Int64.max, url_name: tagProperty4Admin.url_name, url: "")
                    tagPropertiesArray.append(tagProperty)
                }
            }
        }
        else if (stat == "fail")
        {
            // Retrieve Piwigo server error
            errorCode = try rootContainer.decode(Int.self, forKey: .err)
            errorMessage = try rootContainer.decode(String.self, forKey: .message)
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
struct TagProperties: Codable
{
    let id: Int32?                  // 1
    let name: String?               // "Birthday"
    let lastmodified: String?       // "2018-08-23 15:30:43"
    let counter: Int64?             // 8

    // The following data is not stored in cache
    let url_name: String?           // "birthday"
    let url: String?                // "https:…"
}

/**
 A struct for decoding JSON returned by kPiwigoTagsGetAdminList:
 All members are optional in case they are missing from the data.
*/
struct TagProperties4Admin: Codable
{
    let id: String?                 // 1 (String instead of Int)
    let name: String?               // "Birthday"
    let lastmodified: String?       // "2018-08-23 15:30:43"

    // The following data is not stored in cache
    let url_name: String?           // "birthday"
}
