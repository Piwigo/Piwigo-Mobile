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
            if pwgData.data.contains(kCommunitySessionGetStatus) {
                NetworkVars.shared.usesCommunityPluginV29 = true
                JSONManager.logger.notice("\(kReflectionGetMethodList) ➜ Community plugin installed")
            } else {
                NetworkVars.shared.usesCommunityPluginV29 = false
            }
            
            // Check if the pwg.images.uploadAsync method is available (since Piwigo 11)
            if pwgData.data.contains(pwgImagesUploadAsync) {
                NetworkVars.shared.usesUploadAsync = true
                JSONManager.logger.notice("\(kReflectionGetMethodList) ➜ uploadAsync method available")
            } else {
                NetworkVars.shared.usesUploadAsync = false
            }
            
            // Check if the pwg.categories.calculateOrphans method is available (since Piwigo 12)
            if pwgData.data.contains(pwgCategoriesCalcOrphans) {
                NetworkVars.shared.usesCalcOrphans = true
                JSONManager.logger.notice("\(kReflectionGetMethodList) ➜ calculateOrphans method available")
            } else {
                NetworkVars.shared.usesCalcOrphans = false
            }
            
            // Check if the pwg.images.setCategory method is available (since Piwigo 14)
            if pwgData.data.contains(pwgImagesSetCategory) {
                NetworkVars.shared.usesSetCategory = true
                JSONManager.logger.notice("\(kReflectionGetMethodList) ➜ setCategory method available: \(NetworkVars.shared.usesSetCategory, privacy: .public)")
            } else {
                NetworkVars.shared.usesSetCategory = false
            }
            
            // Check if the pwg.users.api_key.revoke method is available (since Piwigo 16.0)
            if pwgData.data.contains("pwg.users.api_key.revoke") {
                NetworkVars.shared.usesAPIkeys = true
                JSONManager.logger.notice("\(kReflectionGetMethodList) ➜ API keys management available: \(NetworkVars.shared.usesAPIkeys, privacy: .public)")
            } else {
                NetworkVars.shared.usesAPIkeys = false
            }
        }
        catch let error {
            throw error
        }
    }
}
