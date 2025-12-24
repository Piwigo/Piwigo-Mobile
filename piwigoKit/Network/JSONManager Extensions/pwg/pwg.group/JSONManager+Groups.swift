//
//  JSONManager+Groups.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 14/06/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation

public extension JSONManager {
    
    func getGroupsInfo(completion: @escaping ([GroupsGetInfo]) -> Void,
                       failure: @escaping (PwgKitError) -> Void) {
        
        // Collect data from server
        postRequest(withMethod: pwgGroupsGetList, paramDict: [:],
                    jsonObjectClientExpectsToReceive: GroupsGetListJSON.self,
                    countOfBytesClientExpectsToReceive: 10800) { result in
            switch result {
            case .success(let pwgData):
                // Update current recentPeriodIndex
                completion(pwgData.groups)

            case .failure(let error):
                /// - Network communication errors
                /// - Returned JSON data is empty
                /// - Cannot decode data returned by Piwigo server
                /// -> nothing presented in the footer
                failure(error)
            }
        }
    }
}
