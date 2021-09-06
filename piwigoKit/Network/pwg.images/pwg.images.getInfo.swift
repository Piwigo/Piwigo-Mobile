//
//  pwg.images.getInfo.swift
//  piwigo
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
    public var derivatives: Derivatives!
    public var errorCode = 0
    public var errorMessage = ""

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
                    derivatives?.squareImage = Derivative(url: square.url,
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
                    derivatives?.thumbImage = Derivative(url: square.url,
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
                    derivatives?.mediumImage = Derivative(url: square.url,
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
                    derivatives?.smallImage = Derivative(url: square.url,
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
                    derivatives?.xSmallImage = Derivative(url: square.url,
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
                    derivatives?.xxSmallImage = Derivative(url: square.url,
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
                    derivatives?.largeImage = Derivative(url: square.url,
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
                    derivatives?.xLargeImage = Derivative(url: square.url,
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
                    derivatives?.xxLargeImage = Derivative(url: square.url,
                                                           width: Int(square.width ?? "1"),
                                                           height: Int(square.height ?? "1"))
                }
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
            errorMessage = NSLocalizedString("serverUnknownError_message", comment: "Unexpected error encountered while calling server method with provided parameters.")
        }
    }
}


// MARK: - Result
public struct ImagesGetInfo: Decodable
{
    public let imageId: Int?                    // 1042
    public let imageTitle: String?              // "Title"
    public let comment: String?                 // "No description"
    public let visits: Int?                     // 0
    public let fileName: String?                // Image.jpg
    public let datePosted: String?              // "yyyy-MM-dd HH:mm:ss"
    public let dateCreated: String?             // "yyyy-MM-dd HH:mm:ss"
 
    public let fullResWidth: Int?               // 4092
    public let fullResHeight: Int?              // 2048
    public let fullResPath: String?             // "https://…image.jpg"
     
    public let author: String?                  // "Eddy"
    public let privacyLevel: String?            // "0"
    public let tags: [TagProperties]?           // See TagProperties
    public let ratingScore: String?             // "1.0"
    public let fileSize: Int?                   // 3025
    public let md5checksum: String?             // 2141e377254a429be151900e4bedb520
    public let categoryIds: [Album]?            // See Album below

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
    public let width: Int?
    public let height: Int?
}

public struct DerivativeStr: Decodable {
    public let url: String?
    public let width: String?
    public let height: String?
}


// MARK: - Category
public struct Album: Decodable
{
    public let id: Int?                     // 32

    // The following data is not stored in image cache
    public let name: String?                // "Insects & Spiders"
    public let permalink: String?           // null
    public let uppercats: String?           // "32"
    public let global_rank: String?         // "1"
    public let url: String?                 // "https:…"
    public let page_url: String?            // "https:…"
}
