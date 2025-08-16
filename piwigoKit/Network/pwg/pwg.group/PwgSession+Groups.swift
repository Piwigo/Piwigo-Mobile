//
//  PwgSession+Groups.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 14/06/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation

public extension PwgSession {
    
    static func getGroupsInfo(completion: @escaping ([GroupsGetInfo]) -> Void,
                              failure: @escaping () -> Void) {
        
        // Collect data from server
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgGroupsGetList, paramDict: [:],
                                jsonObjectClientExpectsToReceive: GroupsGetListJSON.self,
                                countOfBytesClientExpectsToReceive: 10800) { result in
            switch result {
            case .success(let jsonData):
                // Decode the JSON object and check if the login was successful
                do {
                    // Decode the JSON into codable type GroupsGetListJSON.
                    let decoder = JSONDecoder()
                    let pwgData = try decoder.decode(GroupsGetListJSON.self, from: jsonData)
                    
                    // Piwigo error?
                    if pwgData.errorCode != 0 {
#if DEBUG
                        let error = PwgSession.shared.error(for: pwgData.errorCode, errorMessage: pwgData.errorMessage)
                        debugPrint(error)
#endif
                        return
                    }
                    
                    // Update current recentPeriodIndex
                    completion(pwgData.groups)
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
}
