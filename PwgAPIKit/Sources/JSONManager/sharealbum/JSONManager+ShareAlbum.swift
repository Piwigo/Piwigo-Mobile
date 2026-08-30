//
//  JSONManager+ShareAlbum.swift
//  PwgAPIKit
//
//  Created by Eddy Lelièvre-Berna on 21/08/2026.
//

import Foundation
import PwgKit

public extension JSONManager {
    // MARK: - Shared Albums
    /**
     Returns the list of albums shared with users having no Piwigo account.
     
     The ShareAlbum plugin returns every share of the server, whoever created it and
     whichever albums the user may access, so the returned list may contain shares of
     albums which are not in the cache of the current user.
     
     The plugin rejects users who are neither administrators nor members of the
     "sharealbum_powerusers" group with a 403 error (see kShareAlbumForbiddenError).
     There is no method telling whether the user is allowed, so this call is the probe.
     */
    @concurrent
    func getSharedAlbums() async throws(PwgKitError) -> [ShareAlbumGetInfo] {
        #if DEBUG
        debugPrint("••> Fetch shared albums")
        #endif
        // Launch the HTTP(S) request
        let pwgData = try await postRequest(withMethod: kShareAlbumGetList, paramDict: [:],
                                            jsonObjectClientExpectsToReceive: ShareAlbumGetListJSON.self,
                                            countOfBytesClientExpectsToReceive: NSURLSessionTransferSizeUnknown)
        return pwgData.data
    }

    /**
     Returns the share of an album, or nil when this album is not shared.
     
     Also used after creating or renewing a share: sharealbum.create and sharealbum.renew
     return the share URL but neither the creator nor the creation date, so the whole share
     is retrieved to store in cache the same data as sharealbum.getList.
     */
    @concurrent
    func getShare(ofAlbumWithID catID: Int32) async throws(PwgKitError) -> ShareAlbumGetInfo? {
        // Prepare parameters
        let paramsDict: [String : Any] = ["category_id" : catID]
        
        // Launch the HTTP(S) request
        let pwgData = try await postRequest(withMethod: kShareAlbumgetInfo, paramDict: paramsDict,
                                            jsonObjectClientExpectsToReceive: ShareAlbumGetInfoJSON.self,
                                            countOfBytesClientExpectsToReceive: 1000)
        return pwgData.isShared ? pwgData.data : nil
    }
    
    /**
     Shares an album with users having no Piwigo account and returns the created share.
     
     Only private albums can be shared. An album which is already shared — a share can be
     created from the web UI at any time — is not an error: its existing share is returned.
     */
    @concurrent
    func createShare(ofAlbumWithID catID: Int32) async throws(PwgKitError) -> ShareAlbumGetInfo? {
        // Prepare parameters
        let paramsDict: [String : Any] = ["category_id" : catID]
        
        // Launch the HTTP(S) request
        _ = try await postRequest(withMethod: kShareAlbumCreate, paramDict: paramsDict,
                                  jsonObjectClientExpectsToReceive: ShareAlbumCreateJSON.self,
                                  countOfBytesClientExpectsToReceive: 1000)
        
        // Retrieve the whole share (see getShare)
        return try await getShare(ofAlbumWithID: catID)
    }
    
    /**
     Renews the code of the share of an album and returns the renewed share.
     The former URL does not give access to the album anymore.
     Returns nil when the album is not shared, i.e. when there was nothing to renew.
     */
    @concurrent
    func renewShare(ofAlbumWithID catID: Int32) async throws(PwgKitError) -> ShareAlbumGetInfo? {
        // Prepare parameters
        let paramsDict: [String : Any] = ["category_id" : catID]
        
        // Launch the HTTP(S) request
        let pwgData = try await postRequest(withMethod: kShareAlbumRenew, paramDict: paramsDict,
                                            jsonObjectClientExpectsToReceive: ShareAlbumRenewJSON.self,
                                            countOfBytesClientExpectsToReceive: 1000)
        guard pwgData.isShared else { return nil }
        
        // Retrieve the whole share (see getShare)
        return try await getShare(ofAlbumWithID: catID)
    }
    
    /**
     Cancels the share of an album. The share URL does not give access to the album anymore.
     An album which is not shared anymore is not an error: the expected result is achieved.
     */
    @concurrent
    func cancelShare(ofAlbumWithID catID: Int32) async throws(PwgKitError) {
        // Prepare parameters
        let paramsDict: [String : Any] = ["category_id" : catID]
        
        // Launch the HTTP(S) request
        _ = try await postRequest(withMethod: kShareAlbumCancel, paramDict: paramsDict,
                                  jsonObjectClientExpectsToReceive: ShareAlbumCancelJSON.self,
                                  countOfBytesClientExpectsToReceive: 1000)
    }
}
