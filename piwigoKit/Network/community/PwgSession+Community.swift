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
                            failure: @escaping (NSError) -> Void) {
        if #available(iOSApplicationExtension 14.0, *) {
            NetworkUtilities.logger.notice("Get community status")
        }
        // Launch request
        postRequest(withMethod: kCommunitySessionGetStatus, paramDict: [:],
                    jsonObjectClientExpectsToReceive: CommunitySessionGetStatusJSON.self,
                    countOfBytesClientExpectsToReceive: kCommunitySessionGetStatusBytes) { jsonData in
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
