//
//  pwg.images.uploadCompleted.swift
//  PwgAPIKit
//
//  Created by Eddy Lelièvre-Berna on 14/11/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import PwgKit

public let pwgImagesUploadCompleted = "pwg.images.uploadCompleted"

// MARK: Piwigo JSON Structures
public struct ImagesUploadCompletedJSON: Decodable {

    public var status: String?
    public var success = false
    
    /// Number of images which the server counts in the album once the lounge was emptied.
    /// Returned as a string, e.g. "204", which a future version may well return as a number,
    /// and absent from the replies of servers which do not provide it — in which case the
    /// count held in cache is left untouched.
    public var nbImages: StringOrInt?
    
    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case result
        case errorCode = "err"
        case errorMessage = "message"
    }
    
    private enum ResultCodingKeys: String, CodingKey {
        case category
    }
    
    private enum CategoryCodingKeys: String, CodingKey {
        case nbImages = "nb_photos"
    }
    
    public init(from decoder: any Decoder) throws
    {
        // Root container keyed by RootCodingKeys
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
        
        // Status returned by Piwigo
        status = try rootContainer.decodeIfPresent(String.self, forKey: .status)
        if status == "ok"
        {
            success = true
            
            // Number of images counted by the server in the album
            if let resultContainer = try? rootContainer.nestedContainer(keyedBy: ResultCodingKeys.self, forKey: .result),
               let categoryContainer = try? resultContainer.nestedContainer(keyedBy: CategoryCodingKeys.self, forKey: .category) {
                nbImages = try? categoryContainer.decode(StringOrInt.self, forKey: .nbImages)
            }
        }
        else if status == "fail"
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
