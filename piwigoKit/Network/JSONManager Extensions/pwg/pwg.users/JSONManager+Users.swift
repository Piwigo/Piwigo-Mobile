//
//  JSONManager+Users.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 26/03/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import os
import Foundation

public extension JSONManager {
    
    @concurrent
    func getUsersInfo(forUserName username: String) async throws -> UsersGetInfo {
        
        // Prepare parameters
        let paramsDict: [String : Any] = ["username" : username,
                                          "display"  : "all"]
        // Collect stats from server
        let pwgData = try await postRequest(withMethod: pwgUsersGetList, paramDict: paramsDict,
                                            jsonObjectClientExpectsToReceive: UsersGetListJSON.self,
                                            countOfBytesClientExpectsToReceive: 10800)
        
        // Update current recentPeriodIndex
        if let usersData = pwgData.users.first {
            return usersData
        }
        throw PwgKitError.emptyJSONobject
    }
    
    @concurrent
    func setRecentPeriod(_ recentPeriod: Int, forUserWithID pwgID: Int16) async throws(PwgKitError) {
        
        // Prepare parameters
        let paramsDict: [String : Any] = ["user_id"       : pwgID,
                                          "recent_period" : recentPeriod,
                                          "pwg_token"     : NetworkVars.shared.pwgToken]
        
        // Collect stats from server
        _ = try await postRequest(withMethod: pwgUsersSetInfo, paramDict: paramsDict,
                                  jsonObjectClientExpectsToReceive: UsersGetListJSON.self,
                                  countOfBytesClientExpectsToReceive: 10800)
    }
    
    @concurrent
    func addToFavorites(_ imageData: Image) async throws(PwgKitError) {
        // Prepare parameters
        let paramsDict: [String : Any] = ["image_id"  : imageData.pwgID]
        
        // Add image to favorites
        _ = try await postRequest(withMethod: pwgUsersFavoritesAdd, paramDict: paramsDict,
                                  jsonObjectClientExpectsToReceive: FavoritesAddRemoveJSON.self,
                                  countOfBytesClientExpectsToReceive: 1000)
    }
    
    @concurrent
    func removeFromFavorites(_ imageData: Image) async throws(PwgKitError) {
        // Prepare parameters
        let paramsDict: [String : Any] = ["image_id"  : imageData.pwgID]
        
        // Remove image from favorites
        _ = try await postRequest(withMethod: pwgUsersFavoritesRemove, paramDict: paramsDict,
                                  jsonObjectClientExpectsToReceive: FavoritesAddRemoveJSON.self,
                                  countOfBytesClientExpectsToReceive: 1000)
    }
}
