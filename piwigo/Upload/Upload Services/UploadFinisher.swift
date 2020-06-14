//
//  UploadFinisher.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 01/06/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

class UploadFinisher {
    
    // MARK: - Piwigo API methods

    let kCommunityImagesUploadCompleted = "format=json&method=community.images.uploadCompleted"

    
    // MARK: - Community Moderation
    /**
     When the Community plugin is installed (v2.9+) on the server,
     one must inform the moderator that a number of images were uploaded.
     */
    func getUploadedImageStatus(byId imageId: String?, inCategory categoryId: Int,
                                      onCompletion completion: @escaping (_ task: URLSessionTask?, _ response: Any?) -> Void,
                                      onFailure fail: @escaping (_ task: URLSessionTask?, _ error: Error?) -> Void) -> URLSessionTask? {
        
        let request = NetworkHandler.post(kCommunityImagesUploadCompleted,
                                urlParameters: nil,
                                parameters: [
                                    "pwg_token": Model.sharedInstance().pwgToken!,
                                    "image_id": imageId ?? "",
                                    "category_id": NSNumber(value: categoryId)
                                    ],
                                progress: nil,
                                success: completion,
                                failure: fail)

        return request
    }
}


// MARK: - Codable, kPiwigoImageSetInfo
/**
 A struct for decoding JSON with the following structure returned by kPiwigoImageSetInfo:

 {"result": "<NULL>"
 "stat":"ok"}
 
*/
struct ImageSetInfoJSON: Decodable {

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
    
    // A boolean reporting if the method was successful
    var imageSetInfo = false

    init(from decoder: Decoder) throws
    {
        // Root container keyed by RootCodingKeys
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
        
        // Status returned by Piwigo
        stat = try rootContainer.decodeIfPresent(String.self, forKey: .stat)
        if (stat == "ok")
        {
            imageSetInfo = true
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
            errorMessage = NSLocalizedString("serverUnknownError_message", comment: "Unexpected error encountered while calling server method with provided parameters.")
        }
    }
}


// MARK: - Codable, kCommunityImagesUploadCompleted
/**
 A struct for decoding JSON with the following structure returned by kCommunityImagesUploadCompleted:

 {"stat":"ok",
  "result":{ "pending" = ( ) }
  }

*/
struct CommunityUploadCompletedJSON: Decodable {
    
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
    
    // A boolean reporting if the method was successful
    var isSubmittedToModerator = false

    init(from decoder: Decoder) throws
    {
        // Root container keyed by RootCodingKeys
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
        
        // Status returned by Piwigo
        stat = try rootContainer.decodeIfPresent(String.self, forKey: .stat)
        if (stat == "ok")
        {
            isSubmittedToModerator = true
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
            errorMessage = NSLocalizedString("serverUnknownError_message", comment: "Unexpected error encountered while calling server method with provided parameters.")
        }
    }
}
