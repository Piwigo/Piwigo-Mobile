//
//  pwg.categories.add
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 03/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

public let pwgCategoriesAdd = "pwg.categories.add"

// MARK: Piwigo JSON Structures
public struct CategoriesAddJSON: Decodable {

    public var status: String?
    public var data = CategoriesAdd(id: Int32.min, info: "")

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
        // Root container keyed by RootCodingKeys
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
//            dump(rootContainer)

        // Status returned by Piwigo
        status = try rootContainer.decodeIfPresent(String.self, forKey: .status)
        if status == "ok"
        {
            // Decodes response from the data and store them in the array
            data = try rootContainer.decodeIfPresent(CategoriesAdd.self, forKey: .data) ?? CategoriesAdd(id: Int32.min, info: "")
//                dump(data)
        }
        else if status == "fail"
        {
            // Retrieve Piwigo server error
            do {
                // Retrieve Piwigo server error
                let errorCode = try rootContainer.decode(Int.self, forKey: .errorCode)
                let errorMessage = try rootContainer.decode(String.self, forKey: .errorMessage)
                throw PwgKitError.pwgError(code: errorCode, msg: errorMessage)
            }
            catch {
                // Error container keyed by ErrorCodingKeys ("format=json" forgotten in call)
                let errorContainer = try rootContainer.nestedContainer(keyedBy: ErrorCodingKeys.self, forKey: .errorCode)
                let errorCode = Int(try errorContainer.decode(String.self, forKey: .code)) ?? NSNotFound
                let errorMessage = try errorContainer.decode(String.self, forKey: .message)
                throw PwgKitError.pwgError(code: errorCode, msg: errorMessage)
            }
        }
        else {
            // Unexpected Piwigo server error
            throw PwgKitError.unexpectedError
        }
    }
}

public struct CategoriesAdd: Decodable
{
    public let id: Int32?            // 1042
    public let info: String?         // "Album added"
}
