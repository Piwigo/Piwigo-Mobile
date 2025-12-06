//
//  PwgSession+History.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 26/11/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import os
import Foundation

public extension PwgSession {
    
    func logVisitOfImage(withID imageID: Int64, asDownload: Bool,
                         completion: @escaping () -> Void,
                         failure: @escaping (PwgKitError) -> Void) {
        // Launch request
        let paramDict: [String : Any] = ["image_id": imageID,
                                         "is_download": asDownload]
        postRequest(withMethod: pwgHistoryLog, paramDict: paramDict,
                    jsonObjectClientExpectsToReceive: HistoryLogJSON.self,
                    countOfBytesClientExpectsToReceive: pwgHistoryLogBytes) { result in
            switch result {
            case .success:
                completion()
                
            case .failure(let error):
                /// - Network communication errors
                /// - Returned JSON data is empty
                /// - Cannot decode data returned by Piwigo server
                failure(error)
            }
        }
    }
}
