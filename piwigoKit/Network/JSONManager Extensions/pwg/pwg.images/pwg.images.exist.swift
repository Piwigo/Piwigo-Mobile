//
//  pwg.images.exist.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 20/06/2023.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

public let pwgImagesExist = "pwg.images.exist"
public let pwgImagesExistBytes: Int64 = 1250

// MARK: - Piwigo JSON Structures
public struct ImagesExistJSON: Decodable {

    public var status: String?
    public var data = [ImageExist]()
    
    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case result = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }

    public init(from decoder: any Decoder) throws
    {
        // Root container keyed by RootCodingKeys
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
//        dump(rootContainer)

        // Status returned by Piwigo
        status = try rootContainer.decodeIfPresent(String.self, forKey: .status)
        if status == "ok"
        {
            // Decodes response from the data and store them in the array
            let images = try rootContainer.decode(ImageExist.List.self, forKey: .result)
            data = images.values
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

public struct ImageExist {
    let md5sum: String?
    let imageID: Int64?

    struct List: Decodable {
        public let values: [ImageExist]

        public init() {
            values = []
        }
        
        public init(from decoder: any Decoder) throws {
            do {
                let container = try decoder.singleValueContainer()
                let dictionary = try container.decode([String : StringOrInt].self)
                
                values = dictionary.map { key, value in
                    ImageExist(md5sum: key, imageID: value.int64Value)
                }
            }
            catch {
                values = []
            }
        }
    }
}
