//
//  pwg.images.uploadAsync.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 29/08/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

public let pwgImagesUploadAsync = "pwg.images.uploadAsync"

// MARK: Piwigo JSON Structures
public struct ImagesUploadAsyncJSON: Decodable {

    public var status: String?
    public var chunks: ImagesUploadAsync!
    public var data: ImagesGetInfo!
    
    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case result = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }

    public init(from decoder: Decoder) throws
    {
        // Root container keyed by RootCodingKeys
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
//        dump(rootContainer)

        // Status returned by Piwigo
        status = try rootContainer.decodeIfPresent(String.self, forKey: .status)
        if status == "ok"
        {
            // Decodes response from the data and store them in the array
            data = try? rootContainer.decode(ImagesGetInfo.self, forKey: .result)
            
            // Did the server returned the image parameters?
            guard let _ = data, let _ = data.id else {
                // The server returned the list of uploaded chunks
                chunks = try rootContainer.decode(ImagesUploadAsync.self, forKey: .result)
//                debugPrint("    > \(chunks.message ?? "Done - No message!")")
                return
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

/// Returns a message until all chunks have been uploaded
public struct ImagesUploadAsync: Decodable
{
    public let message: String?         // "chunks uploaded = 2,5"
}
