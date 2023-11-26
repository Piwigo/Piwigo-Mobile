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
                         failure: @escaping (Error?) -> Void) {
        // Launch request
        let paramDict: [String : Any] = ["image_id": imageID,
                                         "is_download": asDownload]
        postRequest(withMethod: pwgHistoryLog, paramDict: paramDict,
                    jsonObjectClientExpectsToReceive: HistoryLogJSON.self,
                    countOfBytesClientExpectsToReceive: pwgHistoryLogBytes) { jsonData in
            do {
                // Decode the JSON into codable type HistoryLogJSON.
                let decoder = JSONDecoder()
                let historyJSON = try decoder.decode(HistoryLogJSON.self, from: jsonData)

                // Piwigo error?
                if historyJSON.errorCode != 0 {
                    // Will retry later
                    let error = self.localizedError(for: historyJSON.errorCode,
                                                    errorMessage: historyJSON.errorMessage)
                    failure(error)
                    return
                }

                completion()
            }
            catch {
                let error = error as NSError
                failure(error)
                return
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            failure(error)
        }
    }
}
