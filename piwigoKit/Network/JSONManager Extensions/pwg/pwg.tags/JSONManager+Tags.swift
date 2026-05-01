//
//  JSONManager+Tags.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 25/12/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import os
import Foundation

public extension JSONManager {
    
    @concurrent
    func fetchTags() async throws(PwgKitError) -> [TagProperties] {
        // Prepare parameters
        let paramsDict: [String : Any] = [ : ]
        
        // Fetch tags
        let pwgData = try await postRequest(withMethod: pwgTagsGetList, paramDict: paramsDict,
                                            jsonObjectClientExpectsToReceive: TagJSON.self,
                                            countOfBytesClientExpectsToReceive: NSURLSessionTransferSizeUnknown)
        return pwgData.data
    }
    
    @concurrent
    func fetchTagsAsAdmin() async throws(PwgKitError) -> [TagProperties] {
        // Prepare parameters
        let paramsDict: [String : Any] = [ : ]
        
        // Fetch tags
        let pwgData = try await postRequest(withMethod: pwgTagsGetAdminList, paramDict: paramsDict,
                                            jsonObjectClientExpectsToReceive: TagJSON.self,
                                            countOfBytesClientExpectsToReceive: NSURLSessionTransferSizeUnknown)
        return pwgData.data
    }
    
    @concurrent
    func addTag(with name: String) async throws(PwgKitError) -> TagProperties {
        // Prepare parameters
        let paramsDict: [String : Any] = ["name" : name]
        
        // Add tag on server
        let pwgData = try await postRequest(withMethod: pwgTagsAdd, paramDict: paramsDict,
                                            jsonObjectClientExpectsToReceive: TagAddJSON.self,
                                            countOfBytesClientExpectsToReceive: 3000)
        
        if let tagId = pwgData.data.id {
            let newTag = TagProperties(id: StringOrInt.integer(Int(tagId)),
                                       name: name.utf8mb4Encoded,
                                       lastmodified: "", counter: 0, url_name: "", url: "")
            return newTag
        }
        throw .missingTagData
    }
}
