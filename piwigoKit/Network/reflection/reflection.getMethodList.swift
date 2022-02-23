//
//  reflection.getMethodList.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 14/02/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - reflection.getMethodList
public let kReflectionGetMethodList = "format=json&method=reflection.getMethodList"

public struct ReflectionGetMethodListJSON: Decodable {
    
    public var status: String?
    public var data = [String]()
    public var errorCode = 0
    public var errorMessage = ""

    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case data = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }

    private enum ResultCodingKeys: String, CodingKey {
        case methods
    }
    
    private enum ErrorCodingKeys: String, CodingKey {
        case code = "code"
        case message = "msg"
    }

    public init(from decoder: Decoder) throws
    {
        // Root container keyed by RootCodingKeys
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
        
        // Status returned by Piwigo
        status = try rootContainer.decodeIfPresent(String.self, forKey: .status)
        if (status == "ok")
        {
            // Result container keyed by ResultCodingKeys
            let resultContainer = try rootContainer.nestedContainer(keyedBy: ResultCodingKeys.self, forKey: .data)
//            dump(resultContainer)
            
            // Decodes pending properties from the data and store them in the array
            do {
                // Use ComImageProperties struct
                try data = resultContainer.decode([String].self, forKey: .methods)
            }
            catch {
                // Returns an empty array => No method!
            }
        }
        else if (status == "fail")
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
