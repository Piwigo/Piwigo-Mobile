//
//  pwg.categories.add
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 03/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - pwg.images.upload
public let pwgCategoriesAdd = "format=json&method=pwg.categories.add"

public struct CategoriesAddJSON: Decodable {

    public var status: String?
    public var data = CategoriesAdd(id: Int32.min, info: "")
    public var errorCode = 0
    public var errorMessage = ""

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
        do {
            // Root container keyed by RootCodingKeys
            guard let rootContainer = try? decoder.container(keyedBy: RootCodingKeys.self) else {
                return
            }
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
        } catch let error {
            print(error.localizedDescription)
        }
    }
}

// MARK: - Result
public struct CategoriesAdd: Decodable
{
    public let id: Int32?            // 1042
    public let info: String?         // "Album added"
}
