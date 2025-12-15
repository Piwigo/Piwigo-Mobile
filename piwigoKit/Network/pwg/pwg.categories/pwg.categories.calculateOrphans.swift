//
//  pwg.categories.calculateOrphans.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 10/11/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

public let pwgCategoriesCalcOrphans = "pwg.categories.calculateOrphans"

// MARK: Piwigo JSON Structures
public struct CategoriesCalcOrphansJSON: Decodable {

    public var status: String?
    public var data: [CategoriesCalcOrphans]?
    
    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case data = "result"
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
            data = try rootContainer.decodeIfPresent([CategoriesCalcOrphans].self, forKey: .data)
//              dump(data)
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

public struct CategoriesCalcOrphans: Decodable {
    public let nbImagesAssociatedOutside,
               nbImagesBecomingOrphan,
               nbImagesRecursive: Int64

    enum CodingKeys: String, CodingKey {
        case nbImagesAssociatedOutside = "nb_images_associated_outside"
        case nbImagesBecomingOrphan = "nb_images_becoming_orphan"
        case nbImagesRecursive = "nb_images_recursive"
    }
}
