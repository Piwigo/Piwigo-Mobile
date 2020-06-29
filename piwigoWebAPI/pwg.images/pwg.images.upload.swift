//
//  pwg.images.upload.swift
//  piwigoWebAPI
//
//  Created by Eddy Lelièvre-Berna on 28/06/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

struct ImagesUploadJSON: Decodable {

    private enum RootCodingKeys: String, CodingKey {
        case stat
        case result
        case err
        case message
    }

    // Constants
    var stat: String?
    var errorCode = 0
    var errorMessage = ""
    
    // An UploadProperties array of decoded ImagesUpload data.
    var imagesUpload = ImagesUpload.init(image_id: NSNotFound, name: "", square_src: "", src: "")

    init(from decoder: Decoder) throws
    {
        // Root container keyed by RootCodingKeys
        guard let rootContainer = try? decoder.container(keyedBy: RootCodingKeys.self) else {
            return
        }
//        dump(rootContainer)

        // Status returned by Piwigo
        stat = try rootContainer.decodeIfPresent(String.self, forKey: .stat)
        if (stat == "ok")
        {
            // Decodes response from the data and store them in the array
            imagesUpload = try rootContainer.decode(ImagesUpload.self, forKey: .result)
//            dump(imagesUpload)
        }
        else if (stat == "fail")
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
    }
}

/**
 A struct for decoding JSON returned by kPiwigoImagesUpload.
 All members are optional in case they are missing from the data.
*/
struct ImagesUpload: Codable
{
    let image_id: Int?              // 1042

    // The following data are not used yet
//    let category: [String]          // {"id":140,"nb_photos":"7","label":"Essai"}
    let name: String?               // "Delft - 01"
    let square_src: String?         // "https://…-sq.jpg"
    let src: String?                // "https://…-th.jpg"
}
