//
//  JSONManager+Tags.swift
//  PwgAPIKit
//
//  Created by Eddy Lelièvre-Berna on 25/12/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import PwgKit

public extension JSONManager {
    /**
     Fetches the tag feed from the remote Piwigo server, and imports it into Core Data.
     The API method for admin pwg.tags.getAdminList does not return the number of tagged photos,
     so we must call pwg.tags.getList to present tagged photos when the user has admin rights.
    */
    @concurrent
    func fetchTags(asAdmin: Bool) async throws(PwgKitError) -> [TagGetInfo] {
        // Prepare parameters
        let paramsDict: [String : Any] = [ : ]
        
        // Fetch tag data
        if asAdmin {
            let pwgData = try await postRequest(withMethod: pwgTagsGetAdminList, paramDict: paramsDict,
                                                jsonObjectClientExpectsToReceive: TagJSON.self,
                                                countOfBytesClientExpectsToReceive: NSURLSessionTransferSizeUnknown)
            return pwgData.data
        }
        else {
            let pwgData = try await postRequest(withMethod: pwgTagsGetList, paramDict: paramsDict,
                                                jsonObjectClientExpectsToReceive: TagJSON.self,
                                                countOfBytesClientExpectsToReceive: NSURLSessionTransferSizeUnknown)
            return pwgData.data
        }
    }
    
    @concurrent
    func addTag(with name: String) async throws(PwgKitError) -> TagGetInfo {
        // Prepare parameters
        let paramsDict: [String : Any] = ["name" : name]
        
        // Add tag on server
        let pwgData = try await postRequest(withMethod: pwgTagsAdd, paramDict: paramsDict,
                                            jsonObjectClientExpectsToReceive: TagAddJSON.self,
                                            countOfBytesClientExpectsToReceive: 3000)
        
        if let tagId = pwgData.data.id {
            let newTag = TagGetInfo(id: StringOrInt.integer(Int(tagId)),
                                    name: name.utf8mb4Encoded)
            return newTag
        }
        throw .missingTagData
    }
}
