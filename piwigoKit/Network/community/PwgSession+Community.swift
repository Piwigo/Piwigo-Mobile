//
//  PwgSession+Community.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 27/06/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import os
import Foundation

public extension PwgSession {
    
    func communityGetStatus(completion: @escaping () -> Void,
                            failure: @escaping (Error) -> Void) {
        if #available(iOSApplicationExtension 14.0, *) {
            PwgSession.logger.notice("Retrieve community status.")
        }
        // Launch request
        postRequest(withMethod: kCommunitySessionGetStatus, paramDict: [:],
                    jsonObjectClientExpectsToReceive: CommunitySessionGetStatusJSON.self,
                    countOfBytesClientExpectsToReceive: kCommunitySessionGetStatusBytes) { jsonData in
            // Decode the JSON object and retrieve the status
            do {
                // Decode the JSON into codable type CommunitySessionGetStatusJSON.
                let decoder = JSONDecoder()
                let pwgData = try decoder.decode(CommunitySessionGetStatusJSON.self, from: jsonData)

                // Piwigo error?
                if pwgData.errorCode != 0 {
                    let error = PwgSession.shared.error(for: pwgData.errorCode, errorMessage: pwgData.errorMessage)
                    failure(error)
                    return
                }
                
                // Update user's status
                guard pwgData.realUser.isEmpty == false,
                      let userStatus = pwgUserStatus(rawValue: pwgData.realUser)
                else {
                    failure(UserError.unknownUserStatus)
                    return
                }
                NetworkVars.userStatus = userStatus
                completion()
            }
            catch {
                // Data cannot be digested
                let error = error
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
