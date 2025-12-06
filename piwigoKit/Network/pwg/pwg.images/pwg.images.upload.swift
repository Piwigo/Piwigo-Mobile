//
//  pwg.images.upload.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 28/06/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

public let pwgImagesUpload = "pwg.images.upload"

// MARK: Piwigo JSON Structures
public struct ImagesUploadJSON: Decodable {

    public var status: String?
    public var data = ImagesUpload(image_id: Int64.min, square_src: "", src: "")
    
    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case data = "result"
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
            data = try rootContainer.decodeIfPresent(ImagesUpload.self, forKey: .data) ?? ImagesUpload(image_id: Int64.min, square_src: "", src: "")
//            dump(data)
        }
        else if status == "fail"
        {
            // Retrieve Piwigo server error
            do {
                // Retrieve Piwigo server error
                let errorCode = try rootContainer.decode(Int.self, forKey: .errorCode)
                let errorMessage = try rootContainer.decode(String.self, forKey: .errorMessage)
                throw PwgKitError.pwgError(code: errorCode, msg: errorMessage)
            }
            catch {
                // Error container keyed by ErrorCodingKeys ("format=json" forgotten in call)
                let errorContainer = try rootContainer.nestedContainer(keyedBy: ErrorCodingKeys.self, forKey: .errorCode)
                let errorCode = Int(try errorContainer.decode(String.self, forKey: .code)) ?? NSNotFound
                let errorMessage = try errorContainer.decode(String.self, forKey: .message)
                throw PwgKitError.pwgError(code: errorCode, msg: errorMessage)
            }
        }
        else {
            // Unexpected Piwigo server error
            throw PwgKitError.unexpectedError
        }
    }
}

public struct ImagesUpload: Decodable
{
    public let image_id: Int64?             // 1042
    public let square_src: String?          // "https://…-sq.jpg"
    public let src: String?                 // "https://…-th.jpg"

    // The following data is not used yet
//    public let name: String?                // "Delft - 01"
//    public let category: ImageCategory?     // See below
}

//public struct ImageCategory: Decodable {
//    public let catId: Int?                  // 140
//    public let catName: String?             // "Essai"
//    public let nbPhotos: StringOrInt?       // 7 or "7"
//
//    public enum CodingKeys: String, CodingKey {
//        case catId = "id"
//        case catName = "label"
//        case nbPhotos = "nb_photos"
//    }
//}
