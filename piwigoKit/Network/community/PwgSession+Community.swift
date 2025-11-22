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
                            failure: @escaping (PwgKitError) -> Void) {
        PwgSession.logger.notice("Session: getting Community status…")
        // Launch request
        postRequest(withMethod: kCommunitySessionGetStatus, paramDict: [:],
                    jsonObjectClientExpectsToReceive: CommunitySessionGetStatusJSON.self,
                    countOfBytesClientExpectsToReceive: kCommunitySessionGetStatusBytes) { result in
            switch result {
            case .success(let pwgData):
                // Piwigo error?
                if pwgData.errorCode != 0 {
                    failure(PwgKitError.pwgError(code: pwgData.errorCode, msg: pwgData.errorMessage))
                    return
                }
                
                // Update user's status
                guard pwgData.realUser.isEmpty == false,
                      let userStatus = pwgUserStatus(rawValue: pwgData.realUser)
                else {
                    failure(PwgKitError.unknownUserStatus)
                    return
                }
                NetworkVars.shared.userStatus = userStatus
                completion()

            case .failure(let error):
                /// - Network communication errors
                /// - Returned JSON data is empty
                /// - Cannot decode data returned by Piwigo server
                failure(error)
            }
        }
    }
}
