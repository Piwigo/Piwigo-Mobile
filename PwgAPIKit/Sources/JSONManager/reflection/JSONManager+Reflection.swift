//
//  JSONManager+Reflection.swift
//  PwgAPIKit
//
//  Created by Eddy Lelièvre-Berna on 27/06/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import os
import Foundation
import PwgKit

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
                ServerVars.shared.usesCommunityPluginV29 = true
                JSONManager.logger.notice("\(kReflectionGetMethodList): Community plugin installed")
            } else {
                ServerVars.shared.usesCommunityPluginV29 = false
            }
            
            // Check if the pwg.images.setCategory method is available (since Piwigo 14)
            if pwgData.data.contains(pwgImagesSetCategory) {
                ServerVars.shared.usesSetCategory = true
                JSONManager.logger.notice("\(kReflectionGetMethodList): setCategory method available: \(ServerVars.shared.usesSetCategory, privacy: .public)")
            } else {
                ServerVars.shared.usesSetCategory = false
            }
            
            // Check if the pwg.users.api_key.revoke method is available (since Piwigo 16.0)
            if pwgData.data.contains("pwg.users.api_key.revoke") {
                NetworkVars.shared.usesAPIkeys = true
                JSONManager.logger.notice("\(kReflectionGetMethodList): API keys management available: \(NetworkVars.shared.usesAPIkeys, privacy: .public)")
            } else {
                NetworkVars.shared.usesAPIkeys = false
            }
        }
        catch let error {
            throw error
        }
    }
}
