//
//  PwgSession+Users.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 26/03/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import os
import Foundation

public extension PwgSession {
    
    static func getUsersInfo(forUserName username: String,
                             completion: @escaping (UsersGetInfo) -> Void,
                             failure: @escaping () -> Void) {
        
        // Prepare parameters for retrieving user infos
        let paramsDict: [String : Any] = ["username" : username,
                                          "display"  : "all"]
        // Collect stats from server
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgUsersGetList, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: UsersGetListJSON.self,
                                countOfBytesClientExpectsToReceive: 10800) { result in
            switch result {
            case .success(let jsonData):
                // Decode the JSON object and check if the login was successful
                do {
                    // Decode the JSON into codable type UsersGetListJSON.
                    let decoder = JSONDecoder()
                    let pwgData = try decoder.decode(UsersGetListJSON.self, from: jsonData)
                    
                    // Piwigo error?
                    if pwgData.errorCode != 0 {
#if DEBUG
                        let error = PwgSession.shared.error(for: pwgData.errorCode, errorMessage: pwgData.errorMessage)
                        debugPrint(error)
#endif
                        return
                    }
                    
                    // Update current recentPeriodIndex
                    if let usersData = pwgData.users.first {
                       completion(usersData)
                    }
                    failure()
                }
                catch {
                    // Data cannot be digested
#if DEBUG
                    debugPrint(error.localizedDescription)
#endif
                }

            case .failure:
                /// - Network communication errors
                /// - Returned JSON data is empty
                /// - Cannot decode data returned by Piwigo server
                /// -> nothing presented in the footer
                failure()
            }
        }
    }
    
    static func setRecentPeriod(_ recentPeriod: Int, forUserWithID pwgID: Int16,
                                completion: @escaping (Bool) -> Void,
                                failure: @escaping (Error) -> Void) {
        
        // Prepare parameters for retrieving image/video infos
        let paramsDict: [String : Any] = ["user_id"       : pwgID,
                                          "recent_period" : recentPeriod,
                                          "pwg_token"     : NetworkVars.shared.pwgToken]

        // Collect stats from server
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgUsersSetInfo, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: UsersGetListJSON.self,
                                countOfBytesClientExpectsToReceive: 10800) { result in
            switch result {
            case .success(let jsonData):
                // Decode the JSON object and check if the login was successful
                do {
                    // Decode the JSON into codable type UsersGetListJSON.
                    let decoder = JSONDecoder()
                    let pwgData = try decoder.decode(UsersGetListJSON.self, from: jsonData)
                    
                    // Piwigo error?
                    if pwgData.errorCode != 0 {
                        let error = PwgSession.shared.error(for: pwgData.errorCode, errorMessage: pwgData.errorMessage)
                        failure(error)
                        return
                    }
                    
                    // Update current recentPeriodIndex
                    completion(true)
                }
                catch {
                    // Data cannot be digested
                    failure(error)
                }

            case .failure(let error):
                /// - Network communication errors
                /// - Returned JSON data is empty
                /// - Cannot decode data returned by Piwigo server
                failure(error)
            }
        }
    }
}
