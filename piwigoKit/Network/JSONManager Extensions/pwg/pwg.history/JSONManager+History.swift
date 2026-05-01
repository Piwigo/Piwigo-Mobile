//
//  JSONManager+History.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 26/11/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import os
import Foundation

public extension JSONManager {
    
    @concurrent
    func logVisitOfImage(withID imageID: Int64, asDownload: Bool) async throws(PwgKitError) {
        // Launch request
        let paramDict: [String : Any] = ["image_id": imageID,
                                         "is_download": asDownload]
        
        _ = try await postRequest(withMethod: pwgHistoryLog, paramDict: paramDict,
                                  jsonObjectClientExpectsToReceive: HistoryLogJSON.self,
                                  countOfBytesClientExpectsToReceive: pwgHistoryLogBytes)
    }
}
