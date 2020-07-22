//
//  pwg.tags.add.swift
//  piwigoWebAPI
//
//  Created by Eddy Lelièvre-Berna on 20/07/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - pwg.tags.add
let kPiwigoTagsAdd = "format=json&method=pwg.tags.add"

struct TagAddJSON: Decodable {

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
    var tagProperties = TagPropertiesAdd.init(id: 0, info: "")

    init(from decoder: Decoder) throws
    {
        // Root container keyed by RootCodingKeys
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
        
        // Status returned by Piwigo
        stat = try rootContainer.decodeIfPresent(String.self, forKey: .stat)
        if (stat == "ok")
        {
            // Decodes tags from the data and store them in the array
            try tagProperties = rootContainer.decode(TagPropertiesAdd.self, forKey: .result)
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
 A struct for decoding JSON returned by kPiwigoTagsAdd:
 All members are optional in case they are missing from the data.
*/
struct TagPropertiesAdd: Codable
{
    let id: Int32?                  // 1
    
    // The following data is not stored in cache
    let info: String?               // "Birthday"
}
