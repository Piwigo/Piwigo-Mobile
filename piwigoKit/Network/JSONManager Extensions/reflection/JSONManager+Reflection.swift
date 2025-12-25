//
//  JSONManager+Reflection.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 27/06/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import os
import Foundation

public extension JSONManager {
    
    @concurrent
    func getMethods() async throws(PwgKitError) {
        // Launch request
        do {
            let pwgData = try await postRequest(withMethod: kReflectionGetMethodList, paramDict: [:],
                                                jsonObjectClientExpectsToReceive: ReflectionGetMethodListJSON.self,
                                                countOfBytesClientExpectsToReceive: kReflectionGetMethodListBytes)
            
            // Check if the Community extension is installed and active (since Piwigo 2.9a)
            NetworkVars.shared.usesCommunityPluginV29 = pwgData.data.contains(kCommunitySessionGetStatus)
            JSONManager.logger.notice("\(kReflectionGetMethodList) ➜ Community plugin installed: \(NetworkVars.shared.usesCommunityPluginV29, privacy: .public)")
            
            // Check if the pwg.images.uploadAsync method is available (since Piwigo 11)
            NetworkVars.shared.usesUploadAsync = pwgData.data.contains(pwgImagesUploadAsync)
            JSONManager.logger.notice("\(kReflectionGetMethodList) ➜ uploadAsync method available: \(NetworkVars.shared.usesUploadAsync, privacy: .public)")
            
            // Check if the pwg.categories.calculateOrphans method is available (since Piwigo 12)
            NetworkVars.shared.usesCalcOrphans = pwgData.data.contains(pwgCategoriesCalcOrphans)
            JSONManager.logger.notice("\(kReflectionGetMethodList) ➜ calculateOrphans method available: \(NetworkVars.shared.usesCalcOrphans, privacy: .public)")
            
            // Check if the pwg.images.setCategory method is available (since Piwigo 14)
            NetworkVars.shared.usesSetCategory = pwgData.data.contains(pwgImagesSetCategory)
            JSONManager.logger.notice("\(kReflectionGetMethodList) ➜ setCategory method available: \(NetworkVars.shared.usesSetCategory, privacy: .public)")
            
            // Check if the pwg.users.api_key.revoke method is available (since Piwigo 16.0)
            NetworkVars.shared.usesAPIkeys = pwgData.data.contains("pwg.users.api_key.revoke")
            JSONManager.logger.notice("\(kReflectionGetMethodList) ➜ API keys management available: \(NetworkVars.shared.usesAPIkeys, privacy: .public)")
        }
        catch let error {
            throw error
        }
    }
}
