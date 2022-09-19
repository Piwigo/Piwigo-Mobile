//
//  pwg.images.getInfo.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 13/09/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - pwg.images.getInfo
public let kPiwigoImagesGetInfo = "format=json&method=pwg.images.getInfo"

public struct ImagesGetInfoJSON: Decodable {

    public var status: String?
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
            // Image parameters
            data = try rootContainer.decode(ImagesGetInfo.self, forKey: .result)
            
            // Adopt default values when data are not provided
            if data.imageTitle == nil { data.imageTitle = "" }
            if data.comment == nil { data.comment = "" }
            if data.visits == nil { data.visits = 0 }
            if data.fileName == nil { data.fileName = "" }
            if data.datePosted == nil {
                // Adopts now
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd-HHmmssSSSS"
                data.datePosted = dateFormatter.string(from: Date())
            }
            if data.dateCreated == nil {
                // Adopts the posted date when the creation date is unknown.
                data.dateCreated = data.datePosted
            }
            if data.privacyLevel == nil { data.privacyLevel = "0" }
            if data.tags == nil { data.tags = [TagProperties]() }
            if data.ratingScore == nil { data.ratingScore = "0.0" }
            if data.fileSize == nil { data.fileSize = NSNotFound }
            if data.md5checksum == nil { data.md5checksum = "" }
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
            errorMessage = NSLocalizedString("serverUnknownError_message", comment: "Unexpected error encountered while calling server method with provided parameters.")
        }
    }
}


// MARK: - Result
public struct ImagesGetInfo: Decodable
{
    public let imageId: Int?                    // 1042
    public var imageTitle: String?              // "Title"
    public var comment: String?                 // "No description"
    public var visits: Int?                     // 0
    public var fileName: String?                // "Image.jpg"
    public var datePosted: String?              // "yyyy-MM-dd HH:mm:ss"
    public var dateCreated: String?             // "yyyy-MM-dd HH:mm:ss"
 
    public let fullResWidth: Int?               // 4092
    public let fullResHeight: Int?              // 2048
    public let fullResPath: String?             // "https://…image.jpg"
     
    public var author: String?                  // "Eddy"
    public var privacyLevel: String?            // "0"
    public var tags: [TagProperties]?           // See TagProperties
    public var ratingScore: String?             // "1.0"
    public var fileSize: Int?                   // 3025
    public var md5checksum: String?             // "2141e377254a429be151900e4bedb520"
    public let categoryIds: [CategoryData]?     // Defined in pwg.category.getList
    public let derivatives: Derivatives         // See below

    public enum CodingKeys: String, CodingKey {
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
        
        case author = "author"
        case privacyLevel = "level"
        case tags = "tags"
        case ratingScore = "rating_score"
        case fileSize = "filesize"
        case md5checksum = "md5sum"
        case categoryIds = "categories"
        case derivatives = "derivatives"
    }
}


// MARK: - Derivatives
public struct Derivatives: Decodable {
    public var squareImage: Derivative?
    public var thumbImage: Derivative?
    public var mediumImage: Derivative?

    public var smallImage: Derivative?
    public var xSmallImage: Derivative?
    public var xxSmallImage: Derivative?

    public var largeImage: Derivative?
    public var xLargeImage: Derivative?
    public var xxLargeImage: Derivative?

    public enum CodingKeys: String, CodingKey {
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

public struct Derivative: Decodable {
    public let url: String?
    public let width: StringOrInt?
    public let height: StringOrInt?
}
