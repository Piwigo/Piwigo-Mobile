//
//  PwgSession+Reflection.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 27/06/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import os
import Foundation

public extension PwgSession {
    
    func getMethods(completion: @escaping () -> Void,
                    failure: @escaping (PwgKitError) -> Void) {
        // Launch request
        postRequest(withMethod: kReflectionGetMethodList, paramDict: [:],
                    jsonObjectClientExpectsToReceive: ReflectionGetMethodListJSON.self,
                    countOfBytesClientExpectsToReceive: kReflectionGetMethodListBytes) { result in
            switch result {
            case .success(let pwgData):
                // Piwigo error?
                if pwgData.errorCode != 0 {
                    failure(PwgKitError.pwgError(code: pwgData.errorCode, msg: pwgData.errorMessage))
                    return
                }
                
                // Check if the Community extension is installed and active (since Piwigo 2.9a)
                NetworkVars.shared.usesCommunityPluginV29 = pwgData.data.contains("community.session.getStatus")
                
                // Check if the pwg.images.uploadAsync method is available (since Piwigo 11)
                NetworkVars.shared.usesUploadAsync = pwgData.data.contains("pwg.images.uploadAsync")
                
                // Check if the pwg.categories.calculateOrphans method is available (since Piwigo 12)
                NetworkVars.shared.usesCalcOrphans = pwgData.data.contains("pwg.categories.calculateOrphans")
                
                // Check if the pwg.images.setCategory method is available (since Piwigo 14)
                NetworkVars.shared.usesSetCategory = pwgData.data.contains("pwg.images.setCategory")
                
                // Check if the pwg.users.api_key.revoke method is available (since Piwigo 16.0)
                NetworkVars.shared.usesAPIkeys = pwgData.data.contains("pwg.users.api_key.revoke")
                
                PwgSession.logger.notice("""
                        Community plugin installed: \(NetworkVars.shared.usesCommunityPluginV29, privacy: .public)
                        uploadAsync method available: \(NetworkVars.shared.usesUploadAsync, privacy: .public)
                        calculateOrphans method available: \(NetworkVars.shared.usesCalcOrphans, privacy: .public)
                        setCategory method available: \(NetworkVars.shared.usesSetCategory, privacy: .public)
                        API keys management available: \(NetworkVars.shared.usesAPIkeys, privacy: .public)
                    """)
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
