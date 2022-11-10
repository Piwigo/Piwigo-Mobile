//
//  pwg.images.uploadAsync.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 29/08/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - pwg.images.uploadAsync
public let pwgImagesUploadAsync = "format=json&method=pwg.images.uploadAsync"

public struct ImagesUploadAsyncJSON: Decodable {

    public var status: String?
    public var chunks: ImagesUploadAsync!
    public var data: ImagesGetInfo!
    public var errorCode = 0
    public var errorMessage = ""

    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case result = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }

    private enum ErrorCodingKeys: String, CodingKey {
        case code = "code"
        case message = "msg"
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
//                print("    > \(chunks.message ?? "Done - No message!")")
                return
            }
        }
        else if status == "fail"
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
            errorMessage = "Unexpected error encountered while calling server method with provided parameters."
        }
    }
}


// MARK: - Result contains a message until all chunks have been uploaded
public struct ImagesUploadAsync: Decodable
{
    public let message: String?         // "chunks uploaded = 2,5"
}
