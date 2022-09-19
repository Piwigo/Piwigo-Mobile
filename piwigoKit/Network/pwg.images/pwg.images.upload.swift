//
//  pwg.images.upload.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 28/06/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - pwg.images.upload
public let pwgImagesUpload = "format=json&method=pwg.images.upload"

public struct ImagesUploadJSON: Decodable {

    public var status: String?
    public var data = ImagesUpload(image_id: NSNotFound, square_src: "", src: "")
    public var errorCode = 0
    public var errorMessage = ""

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
        do {
            // Root container keyed by RootCodingKeys
            guard let rootContainer = try? decoder.container(keyedBy: RootCodingKeys.self) else {
                return
            }
//            dump(rootContainer)

            // Status returned by Piwigo
            status = try rootContainer.decodeIfPresent(String.self, forKey: .status)
            if status == "ok"
            {
                // Decodes response from the data and store them in the array
                data = try rootContainer.decodeIfPresent(ImagesUpload.self, forKey: .data) ?? ImagesUpload(image_id: NSNotFound, square_src: "", src: "")
//                dump(data)
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
        } catch let error {
            print(error.localizedDescription)
        }
    }
}

// MARK: - Result
public struct ImagesUpload: Decodable
{
    public let image_id: Int?               // 1042
    public let square_src: String?          // "https://…-sq.jpg"
    public let src: String?                 // "https://…-th.jpg"

    // The following data is not used yet
//    public let name: String?                // "Delft - 01"
//    public let category: ImageCategory?     // See below
}

// MARK: - Category
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
