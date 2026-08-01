//
//  JSONManager+Groups.swift
//  PwgAPIKit
//
//  Created by Eddy Lelièvre-Berna on 14/06/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import PwgKit

public extension JSONManager {
    
    @concurrent
    func getGroupsInfo() async throws(PwgKitError) -> [GroupGetInfo] {
        
        // Collect data from server
        let pwgData = try await postRequest(withMethod: pwgGroupsGetList, paramDict: [:],
                                            jsonObjectClientExpectsToReceive: GroupsGetListJSON.self,
                                            countOfBytesClientExpectsToReceive: 10800)
        return pwgData.groups
    }
}
