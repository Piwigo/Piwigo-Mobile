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
}
