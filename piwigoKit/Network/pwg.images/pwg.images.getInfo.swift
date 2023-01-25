//
//  pwg.images.getInfo.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 13/09/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - pwg.images.getInfo
public let pwgImagesGetInfo = "format=json&method=pwg.images.getInfo"

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
            data.fixingUnknowns()
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
    public let id: Int64?                       // 1042
    public var title: String?                   // "Title"
    public var comment: String?                 // "No description"
    public var visits: Int32?                   // 0
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
    public var fileSize: Int64?                 // 3025
    public var md5checksum: String?             // "2141e377254a429be151900e4bedb520"
    public var categories: [CategoryData]?      // Defined in pwg.category.getList
    public let derivatives: Derivatives         // See below

    public enum CodingKeys: String, CodingKey {
        case id = "id"
        case title = "name"
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
        case categories = "categories"
        case derivatives = "derivatives"
    }
}

extension ImagesGetInfo {
    public init(id: Int64, title: String, fileName: String,
                datePosted: Date, dateCreated: Date,
                author: String, privacyLevel: String,
                squareImage: Derivative, thumbImage: Derivative) {
        // Date posted is now (called after uploading in the foreground
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmssSSSS"
        let posted = dateFormatter.string(from: datePosted)
        let created = dateFormatter.string(from: dateCreated)
        let derivatives = Derivatives(squareImage: squareImage, thumbImage: thumbImage)
        
        self.init(id: id, title: title, comment: "", visits: 0,
                  fileName: fileName, datePosted: posted, dateCreated: created,
                  fullResWidth: 0, fullResHeight: 0, fullResPath: "",
                  author: author, privacyLevel: privacyLevel,
                  tags: nil, ratingScore: nil,
                  fileSize: nil, md5checksum: nil,
                  categories: nil, derivatives: derivatives)
        self.fixingUnknowns()
    }
    
    mutating func fixingUnknowns() {
        if self.title == nil { self.title = "" }
        if self.comment == nil { self.comment = "" }
        if self.visits == nil { self.visits = 0 }
        if self.fileName == nil { self.fileName = "" }
        if self.datePosted == nil {
            // Adopts now
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd-HHmmssSSSS"
            self.datePosted = dateFormatter.string(from: Date())
        }
        if self.dateCreated == nil {
            // Adopts the posted date when the creation date is unknown.
            self.dateCreated = self.datePosted
        }
        if self.privacyLevel == nil { self.privacyLevel = "0" }
        if self.tags == nil { self.tags = [TagProperties]() }
        if self.ratingScore == nil { self.ratingScore = "0.0" }
        if self.fileSize == nil { self.fileSize = Int64.zero }
        if self.md5checksum == nil { self.md5checksum = "" }
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

extension Derivatives {
    public init(squareImage: Derivative, thumbImage: Derivative) {
        self.init(squareImage: squareImage, thumbImage: thumbImage, mediumImage: Derivative(),
                  smallImage: Derivative(), xSmallImage: Derivative(), xxSmallImage: Derivative(),
                  largeImage: Derivative(), xLargeImage: Derivative(), xxLargeImage: Derivative())
    }
}

public struct Derivative: Decodable {
    public let url: String?
    public let width: StringOrInt?
    public let height: StringOrInt?
}

extension Derivative {
    public init() {
        self.init(url: nil, width: nil, height: nil)
    }
}
