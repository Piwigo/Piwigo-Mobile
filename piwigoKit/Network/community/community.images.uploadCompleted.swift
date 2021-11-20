//
//  community.images.uploadCompleted.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 03/07/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - community.images.uploadCompleted
public let kCommunityImagesUploadCompleted = "format=json&method=community.images.uploadCompleted"

public struct CommunityImagesUploadCompletedJSON: Decodable {
    
    public var status: String?
    public var data = [ComImageProperties]()
    public var errorCode = 0
    public var errorMessage = ""

    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case data = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }

    private enum ResultCodingKeys: String, CodingKey {
        case pending
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
            
            // Decodes pending properties from the data and store them in the array
            do {
                // Use ComImageProperties struct
                try data = resultContainer.decode([ComImageProperties].self, forKey: .pending)
            }
            catch {
                // Returns an empty array => No pending images
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
 A struct for decoding JSON returned by kCommunityImagesUploadCompleted:
 All members are optional in case they are missing from the data.
*/
public struct ComImageProperties: Decodable
{
    public let id: String?                  // 1
    public let state: String?               // "moderation_pending" or "validated"

    // The following data is not stored in cache
    public let level: String?               // "16"
    public let added_by: String?            // "4"
    public let notified_on: String?         // ??
}
