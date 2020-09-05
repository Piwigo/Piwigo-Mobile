//
//  pwg.images.uploadAsync.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 29/08/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - pwg.images.uploadAsync
let kPiwigoImagesUploadAsync = "format=json&method=pwg.images.uploadAsync"

struct ImagesUploadAsyncJSON: Decodable {

    var status: String?
    var data: ImagesUploadAsync!
    var errorCode = 0
    var errorMessage = ""

    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case data = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }

    init(from decoder: Decoder) throws
    {
        do {
            // Root container keyed by RootCodingKeys
            guard let rootContainer = try? decoder.container(keyedBy: RootCodingKeys.self) else {
                return
            }
    //        dump(rootContainer)

            // Status returned by Piwigo
            status = try rootContainer.decodeIfPresent(String.self, forKey: .status)
            if (status == "ok")
            {
                // Decodes response from the data and store them in the array
//                dump(rootContainer)
                data = try rootContainer.decode(ImagesUploadAsync.self, forKey: .data)
                print("    > \(data.message ?? "No message - DONE")")
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
                errorMessage = "Unexpected error encountered while calling server method with provided parameters."
            }
        } catch let error {
            print(error.localizedDescription)
        }
    }
}

// MARK: - Result
struct ImagesUploadAsync: Codable
{
    let message: String?            // "chunks uploaded = 3,4,7"
    let imageId: Int?               // 1042
    let imageTitle: String?         // "Title"
    let comment: String?            // "No comment"
    let visits: Int?                // 0
    let fileName: String?           // Image.jpg
    let datePosted: String?         // "yyyy-MM-dd HH:mm:ss"
    let dateCreated: String?        // "yyyy-MM-dd HH:mm:ss"

    let fullResWidth: Int?          // 4092
    let fullResHeight: Int?         // 2048
    let fullResPath: String?        // "https://…image.jpg"
    let derivatives: Derivatives?   //  URLs and sizes of images
    
    let author: String?             // "Eddy"
    let privacyLevel: String?       // "0"
    let tags: [TagProperties]?      // See TagProperties
    let ratingScore: Float?         // 0.0
    let fileSize: Int?              // 3025
    let md5checksum: String?        // 2141e377254a429be151900e4bedb520

    enum CodingKeys: String, CodingKey {
        case message = "message"
        case imageId = "id"
        case imageTitle = "name"
        case comment = "comment"
        case visits = "hit"
        case fileName = "file"
        case datePosted = "date_available"
        case dateCreated = "date_creation"

        case fullResWidth = "width"
        case fullResHeight = "height"
        case fullResPath = "element_url"
        case derivatives = "derivatives"
        
        case author = "author"
        case privacyLevel = "level"
        case tags = "tags"
        case ratingScore = "rating_score"
        case fileSize = "filesize"
        case md5checksum = "md5sum"
    }
}

// MARK: - Derivatives
struct Derivatives: Codable {
    let squareImage: Derivative?
    let thumbImage: Derivative?
    let mediumImage: Derivative?

    let smallImage: Derivative?
    let xSmallImage: Derivative?
    let xxSmallImage: Derivative?

    let largeImage: Derivative?
    let xLargeImage: Derivative?
    let xxLargeImage: Derivative?

    enum CodingKeys: String, CodingKey {
        case squareImage = "square"
        case thumbImage = "thumb"
        case mediumImage = "medium"
        
        case smallImage = "small"
        case xSmallImage = "xsmall"
        case xxSmallImage = "2small"

        case largeImage = "large"
        case xLargeImage = "xlarge"
        case xxLargeImage = "xxlarge"
    }
}

struct Derivative: Codable {
    let url: String?
    let width: Int?
    let height: Int?
}
