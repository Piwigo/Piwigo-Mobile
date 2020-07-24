//
//  pwg.images.upload.swift
//  piwigoWebAPI
//
//  Created by Eddy Lelièvre-Berna on 28/06/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - pwg.images.upload
let kPiwigoImagesUpload = "format=json&method=pwg.images.upload"

struct ImagesUploadJSON: Decodable {

    var status: String?
    var data = ImagesUpload.init(image_id: NSNotFound, category: nil, name: "", square_src: "", src: "")
    var errorCode = 0
    var errorMessage = ""

    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case data = "result"
        case err = "err"
        case message = "message"
    }

    init(from decoder: Decoder) throws
    {
        do {
            // Root container keyed by RootCodingKeys
            guard let rootContainer = try? decoder.container(keyedBy: RootCodingKeys.self) else {
                return
            }
    //        dump(rootContainer)

            // Status returned by Piwigo
            status = try rootContainer.decodeIfPresent(String.self, forKey: .status)
            if (status == "ok")
            {
                // Decodes response from the data and store them in the array
                data = try rootContainer.decode(ImagesUpload.self, forKey: .data)
    //            dump(imagesUpload)
            }
            else if (status == "fail")
            {
                // Retrieve Piwigo server error
                errorCode = try rootContainer.decode(Int.self, forKey: .err)
                errorMessage = try rootContainer.decode(String.self, forKey: .message)
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
struct ImagesUpload: Codable
{
    let image_id: Int?              // 1042

    // The following data are not used yet
    let category: Category?         // {"id":140,"nb_photos":"7","label":"Essai"}
    let name: String?               // "Delft - 01"
    let square_src: String?         // "https://…-sq.jpg"
    let src: String?                // "https://…-th.jpg"
}

// MARK: - Category
struct Category: Codable {
    let catId: Int?
    let catName: String?
    let nbPhotos: String?

    enum CodingKeys: String, CodingKey {
        case catId = "id"
        case catName = "label"
        case nbPhotos = "nb_photos"
    }
}
