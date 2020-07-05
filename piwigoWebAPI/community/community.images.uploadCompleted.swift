//
//  community.images.uploadCompleted.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 03/07/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - community.images.uploadCompleted
let kCommunityImagesUploadCompleted = "format=json&method=community.images.uploadCompleted"

struct CommunityImagesUploadCompletedJSON: Decodable {
    
    private enum RootCodingKeys: String, CodingKey {
        case stat
        case result
        case err
        case message
    }

    // Constants
    var stat: String?
    var errorCode = 0
    var errorMessage = ""
    
    // A boolean reporting if the method was successful
    var isSubmittedToModerator = false

    init(from decoder: Decoder) throws
    {
        // Root container keyed by RootCodingKeys
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
        
        // Status returned by Piwigo
        stat = try rootContainer.decodeIfPresent(String.self, forKey: .stat)
        if (stat == "ok")
        {
            isSubmittedToModerator = true
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
