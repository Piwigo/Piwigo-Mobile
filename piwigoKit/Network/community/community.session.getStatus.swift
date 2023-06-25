//
//  community.session.getStatus.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 19/02/2022.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

public let kCommunitySessionGetStatus = "format=json&method=community.session.getStatus"

// MARK: Piwigo JSON Structure
public struct CommunitySessionGetStatusJSON: Decodable {
    
    public var status: String?
    public var realUser = ""        // "webmaster"
    public var uploadMethod = ""    // "pwg.categories.getAdminList"
    public var errorCode = 0
    public var errorMessage = ""

    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case result = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }

    private enum ResultCodingKeys: String, CodingKey {
        case realUser = "real_user_status"
        case uploadMethod = "upload_categories_getList_method"
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
            let resultContainer = try rootContainer.nestedContainer(keyedBy: ResultCodingKeys.self, forKey: .result)
//            dump(resultContainer)
            
            // Decodes pending properties from the data and store them in the array
            do {
                // Use ComImageProperties struct
                try realUser = resultContainer.decode(String.self, forKey: .realUser)
                try uploadMethod = resultContainer.decode(String.self, forKey: .uploadMethod)
            }
            catch {
                errorCode = -1
                errorMessage = NSLocalizedString("serverUnknownError_message", comment: "Unexpected error encountered while calling server method with provided parameters.")
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


// MARK: - Piwigo Method Caller
extension PwgSession {
    
    public func communityGetStatus(completion: @escaping () -> Void,
                                   failure: @escaping (NSError) -> Void) {
        if #available(iOSApplicationExtension 14.0, *) {
            NetworkUtilities.logger.notice("Get community status")
        }
        // Launch request
        postRequest(withMethod: kCommunitySessionGetStatus, paramDict: [:],
                    jsonObjectClientExpectsToReceive: CommunitySessionGetStatusJSON.self,
                    countOfBytesClientExpectsToReceive: 2100) { jsonData in
            // Decode the JSON object and retrieve the status
            do {
                // Decode the JSON into codable type CommunitySessionGetStatusJSON.
                let decoder = JSONDecoder()
                let statusJSON = try decoder.decode(CommunitySessionGetStatusJSON.self, from: jsonData)

                // Piwigo error?
                if statusJSON.errorCode != 0 {
                    let error = self.localizedError(for: statusJSON.errorCode,
                                                    errorMessage: statusJSON.errorMessage)
                    failure(error as NSError)
                    return
                }
                
                // Update user's status
                guard statusJSON.realUser.isEmpty == false,
                      let userStatus = pwgUserStatus(rawValue: statusJSON.realUser) else {
                    failure(UserError.unknownUserStatus as NSError)
                    return
                }
                NetworkVars.userStatus = userStatus
                completion()
            }
            catch {
                // Data cannot be digested
                let error = error as NSError
                failure(error)
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            failure(error)
        }
    }
}
