//
//  pwg.images.setInfo.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 03/07/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - pwg.images.setInfo
let kPiwigoImagesSetInfo = "format=json&method=pwg.images.setInfo"

struct ImagesSetInfoJSON: Decodable {

    var status: String?
    var success = false
    var errorCode = 0
    var errorMessage = ""

    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case result
        case errorCode = "err"
        case errorMessage = "message"
    }
    
    init(from decoder: Decoder) throws
    {
        // Root container keyed by RootCodingKeys
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
        
        // Status returned by Piwigo
        status = try rootContainer.decodeIfPresent(String.self, forKey: .status)
        if (status == "ok")
        {
            success = true
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
