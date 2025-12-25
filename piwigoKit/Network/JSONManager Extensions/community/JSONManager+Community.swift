//
//  JSONManager+Community.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 27/06/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import os
import Foundation

public extension JSONManager {
    
    @concurrent
    func communityGetStatus() async throws(PwgKitError) {
        JSONManager.logger.notice("Session: getting Community status…")
        // Launch request
        let pwgData = try await postRequest(withMethod: kCommunitySessionGetStatus, paramDict: [:],
                                            jsonObjectClientExpectsToReceive: CommunitySessionGetStatusJSON.self,
                                            countOfBytesClientExpectsToReceive: kCommunitySessionGetStatusBytes)
        // Update user's status
        guard pwgData.realUser.isEmpty == false,
              let userStatus = pwgUserStatus(rawValue: pwgData.realUser)
        else {
            throw .unknownUserStatus
        }
        NetworkVars.shared.userStatus = userStatus
    }
    
    /**
     When the Community plugin is installed (v2.9+) on the server,
     one must inform the moderator that a number of images have been uploaded.
     This informs the moderator that uploaded images are waiting for a validation.
     */
    @concurrent
    func moderateImages(withIds imageIds: String, inCategory categoryId: Int32) async throws(PwgKitError) -> [Int64] {
        // Prepare parameters
        let paramDict: [String : Any] = ["image_id": imageIds,
                                         "pwg_token": NetworkVars.shared.pwgToken,
                                         "category_id": "\(NSNumber(value: categoryId))"]
        
        // Moderate uploaded images
        let pwgData = try await postRequest(withMethod: kCommunityImagesUploadCompleted, paramDict: paramDict,
                                            jsonObjectClientExpectsToReceive: CommunityImagesUploadCompletedJSON.self,
                                            countOfBytesClientExpectsToReceive: 1000)
        
        // Return validated image IDs
        var validatedIDs = [Int64]()
        pwgData.data.forEach { (pendingData) in
            if let imageIDstr = pendingData.id, let imageID = Int64(imageIDstr),
               let pendingState = pendingData.state, pendingState == "validated" {
                validatedIDs.append(imageID)
            }
        }
        return validatedIDs
    }
}
