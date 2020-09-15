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

    var status: String?
    var data = TagPropertiesAdd.init(id: 0, info: "")
    var errorCode = 0
    var errorMessage = ""

    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case data = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }

    private enum ResultCodingKeys: String, CodingKey {
        case tags
    }

    init(from decoder: Decoder) throws
    {
        // Root container keyed by RootCodingKeys
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
        
        // Status returned by Piwigo
        status = try rootContainer.decodeIfPresent(String.self, forKey: .status)
        if (status == "ok")
        {
            // Decodes tags from the data and store them in the array
            try data = rootContainer.decode(TagPropertiesAdd.self, forKey: .data)
        }
        else if (status == "fail")
        {
            // Retrieve Piwigo server error
            errorCode = try rootContainer.decode(Int.self, forKey: .errorCode)
            errorMessage = try rootContainer.decode(String.self, forKey: .errorMessage)
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
struct TagPropertiesAdd: Decodable
{
    let id: Int32?                  // 1
    
    // The following data is not stored in cache
    let info: String?               // "Birthday"
}
