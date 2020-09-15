//
//  pwg.images.getInfo.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 13/09/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - pwg.images.getInfo
let kPiwigoImagesGetInfo = "format=json&method=pwg.images.getInfo"

struct ImagesGetInfoJSON: Decodable {

    var status: String?
    var chunks: ImagesUploadAsync!
    var data: ImagesGetInfo!
    var derivatives: Derivatives!
    var errorCode = 0
    var errorMessage = ""

    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case result = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }
    
    private enum ResultCodingKeys: String, CodingKey {
        case derivatives
    }

    private enum DerivativesCodingKeys: String, CodingKey {
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

    init(from decoder: Decoder) throws
    {
        // Root container keyed by RootCodingKeys
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
//        dump(rootContainer)

        // Status returned by Piwigo
        status = try rootContainer.decodeIfPresent(String.self, forKey: .status)
        if (status == "ok")
        {
            // Image parameters
            data = try rootContainer.decode(ImagesGetInfo.self, forKey: .result)
            
            // Result container keyed by ResultCodingKeys
            let resultContainer = try rootContainer.nestedContainer(keyedBy: ResultCodingKeys.self, forKey: .result)
//                dump(resultContainer)

            // Decodes derivatives
            do {
                try derivatives = resultContainer.decode(Derivatives.self, forKey: .derivatives)
            }
            catch {
                // Sometimes, width and height are provided as String instead of Int!
                derivatives = Derivatives()
                let derivativesContainer = try resultContainer.nestedContainer(keyedBy: DerivativesCodingKeys.self, forKey: .derivatives)
//                    dump(derivativesContainer)
                
                // Square image
                do {
                    let square = try derivativesContainer.decode(Derivative.self, forKey: .squareImage)
                    derivatives?.squareImage = square
                }
                catch {
                    let square = try derivativesContainer.decode(DerivativeStr.self, forKey: .squareImage)
                    derivatives?.squareImage = Derivative.init(url: square.url,
                                                               width: Int(square.width ?? "1"),
                                                               height: Int(square.height ?? "1"))
                }

                // Thumbnail image
                do {
                    let square = try derivativesContainer.decode(Derivative.self, forKey: .thumbImage)
                    derivatives?.thumbImage = square
                }
                catch {
                    let square = try derivativesContainer.decode(DerivativeStr.self, forKey: .thumbImage)
                    derivatives?.thumbImage = Derivative.init(url: square.url,
                                                              width: Int(square.width ?? "1"),
                                                              height: Int(square.height ?? "1"))
                }

                // Medium image
                do {
                    let square = try derivativesContainer.decode(Derivative.self, forKey: .mediumImage)
                    derivatives?.mediumImage = square
                }
                catch {
                    let square = try derivativesContainer.decode(DerivativeStr.self, forKey: .mediumImage)
                    derivatives?.mediumImage = Derivative.init(url: square.url,
                                                               width: Int(square.width ?? "1"),
                                                               height: Int(square.height ?? "1"))
                }

                // Small image
                do {
                    let square = try derivativesContainer.decode(Derivative.self, forKey: .smallImage)
                    derivatives?.smallImage = square
                }
                catch {
                    let square = try derivativesContainer.decode(DerivativeStr.self, forKey: .smallImage)
                    derivatives?.smallImage = Derivative.init(url: square.url,
                                                              width: Int(square.width ?? "1"),
                                                              height: Int(square.height ?? "1"))
                }

                // XSmall image
                do {
                    let square = try derivativesContainer.decode(Derivative.self, forKey: .xSmallImage)
                    derivatives?.xSmallImage = square
                }
                catch {
                    let square = try derivativesContainer.decode(DerivativeStr.self, forKey: .xSmallImage)
                    derivatives?.xSmallImage = Derivative.init(url: square.url,
                                                               width: Int(square.width ?? "1"),
                                                               height: Int(square.height ?? "1"))
                }

                // XXSmall image
                do {
                    let square = try derivativesContainer.decode(Derivative.self, forKey: .xxSmallImage)
                    derivatives?.xxSmallImage = square
                }
                catch {
                    let square = try derivativesContainer.decode(DerivativeStr.self, forKey: .xxSmallImage)
                    derivatives?.xxSmallImage = Derivative.init(url: square.url,
                                                                width: Int(square.width ?? "1"),
                                                                height: Int(square.height ?? "1"))
                }

                // Large image
                do {
                    let square = try derivativesContainer.decode(Derivative.self, forKey: .largeImage)
                    derivatives?.largeImage = square
                }
                catch {
                    let square = try derivativesContainer.decode(DerivativeStr.self, forKey: .largeImage)
                    derivatives?.largeImage = Derivative.init(url: square.url,
                                                              width: Int(square.width ?? "1"),
                                                              height: Int(square.height ?? "1"))
                }

                // XLarge image
                do {
                    let square = try derivativesContainer.decode(Derivative.self, forKey: .xLargeImage)
                    derivatives?.xLargeImage = square
                }
                catch {
                    let square = try derivativesContainer.decode(DerivativeStr.self, forKey: .xLargeImage)
                    derivatives?.xLargeImage = Derivative.init(url: square.url,
                                                               width: Int(square.width ?? "1"),
                                                               height: Int(square.height ?? "1"))
                }

                // XXLarge image
                do {
                    let square = try derivativesContainer.decode(Derivative.self, forKey: .xxLargeImage)
                    derivatives?.xxLargeImage = square
                }
                catch {
                    let square = try derivativesContainer.decode(DerivativeStr.self, forKey: .xxLargeImage)
                    derivatives?.xxLargeImage = Derivative.init(url: square.url,
                                                                width: Int(square.width ?? "1"),
                                                                height: Int(square.height ?? "1"))
                }
            }
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
            errorMessage = NSLocalizedString("serverUnknownError_message", comment: "Unexpected error encountered while calling server method with provided parameters.")
        }
    }
}


// MARK: - Result
struct ImagesGetInfo: Decodable
{
    let imageId: Int?                   // 1042
    let imageTitle: String = ""         // "Title"
    let comment: String = ""            // "No description"
    let visits: Int = 0                 // 0
    let fileName: String?               // Image.jpg
    let datePosted: String?             // "yyyy-MM-dd HH:mm:ss"
    let dateCreated: String?            // "yyyy-MM-dd HH:mm:ss"

    let fullResWidth: Int?              // 4092
    let fullResHeight: Int?             // 2048
    let fullResPath: String?            // "https://…image.jpg"
    
    let author: String?                 // "Eddy"
    let privacyLevel: String?           // "0"
    let tags: [TagProperties]?          // See TagProperties
    let ratingScore: Float = 0.0        // 0.0
    let fileSize: Int?                  // 3025
    let md5checksum: String?            // 2141e377254a429be151900e4bedb520

    enum CodingKeys: String, CodingKey {
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
    }
}


// MARK: - Derivatives
struct Derivatives: Decodable {
    var squareImage: Derivative?
    var thumbImage: Derivative?
    var mediumImage: Derivative?

    var smallImage: Derivative?
    var xSmallImage: Derivative?
    var xxSmallImage: Derivative?

    var largeImage: Derivative?
    var xLargeImage: Derivative?
    var xxLargeImage: Derivative?

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

struct Derivative: Decodable {
    let url: String?
    let width: Int?
    let height: Int?
}

struct DerivativeStr: Decodable {
    let url: String?
    let width: String?
    let height: String?
}
