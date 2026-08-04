//
//  JSONManager+Users.swift
//  PwgAPIKit
//
//  Created by Eddy Lelièvre-Berna on 26/03/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import PwgKit

public extension JSONManager {
    
    enum pwgUserInfo: String, CaseIterable {
        case all, basics, none,
             username, email, status, level, groups,
             language, theme, nb_image_page, recent_period, expand, show_nb_comments, show_nb_hits,
             enabled_high, registration_date, registration_date_string,
             registration_date_since, last_visit, last_visit_string, last_visit_since
    }
    
    @concurrent
    func getUserInfo(_ info: pwgUserInfo, forUserName username: String) async throws(PwgKitError) -> UserGetInfo {
        
        // Prepare parameters
        let paramsDict: [String : Any] = ["username" : username,
                                          "display"  : info.rawValue]
        // Collect stats from server
        let pwgData = try await postRequest(withMethod: pwgUsersGetList, paramDict: paramsDict,
                                            jsonObjectClientExpectsToReceive: UsersGetListJSON.self,
                                            countOfBytesClientExpectsToReceive: 10800)
        
        // Return user data
        if let userData = pwgData.users.first {
            return userData
        }
        throw PwgKitError.emptyJSONobject
    }
    
    @concurrent
    func setRecentPeriod(_ recentPeriod: Int) async throws(PwgKitError) {
        
        // Prepare parameters
        let paramsDict: [String : Any] = ["recent_period" : recentPeriod,
                                          "pwg_token"     : ServerVars.shared.pwgToken]
        
        // Collect stats from server
        _ = try await postRequest(withMethod: pwgUsersSetMyInfo, paramDict: paramsDict,
                                  jsonObjectClientExpectsToReceive: MyInfoJSON.self,
                                  countOfBytesClientExpectsToReceive: 1272)
    }
    
    @concurrent
    func addToFavorites(imageWithID imageID: Int64) async throws(PwgKitError) {
        // Prepare parameters
        let paramsDict: [String : Any] = ["image_id"  : imageID]
        
        // Add image to favorites
        _ = try await postRequest(withMethod: pwgUsersFavoritesAdd, paramDict: paramsDict,
                                  jsonObjectClientExpectsToReceive: FavoritesAddRemoveJSON.self,
                                  countOfBytesClientExpectsToReceive: 1000)
    }
    
    @concurrent
    func removeFromFavorites(imageWithID imageID: Int64) async throws(PwgKitError) {
        // Prepare parameters
        let paramsDict: [String : Any] = ["image_id"  : imageID]
        
        // Remove image from favorites
        _ = try await postRequest(withMethod: pwgUsersFavoritesRemove, paramDict: paramsDict,
                                  jsonObjectClientExpectsToReceive: FavoritesAddRemoveJSON.self,
                                  countOfBytesClientExpectsToReceive: 1000)
    }
}
