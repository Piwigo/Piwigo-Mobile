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
            let images = try rootContainer.decode(ImageExist.List.self, forKey: .result)
            data = images.values
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

public struct ImageExist {
    let md5sum: String?
    let imageID: Int64?

    struct List: Decodable {
        public let values: [ImageExist]

        public init() {
            values = []
        }
        
        public init(from decoder: Decoder) throws {
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
