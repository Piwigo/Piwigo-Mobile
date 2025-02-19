//
//  PwgSession+Reflection.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 27/06/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import os
import Foundation

public extension PwgSession {
    
    func getMethods(completion: @escaping () -> Void,
                    failure: @escaping (NSError) -> Void) {
        if #available(iOSApplicationExtension 14.0, *) {
            PwgSession.logger.notice("Retrieve methods.")
        }
        // Launch request
        postRequest(withMethod: kReflectionGetMethodList, paramDict: [:],
                    jsonObjectClientExpectsToReceive: ReflectionGetMethodListJSON.self,
                    countOfBytesClientExpectsToReceive: kReflectionGetMethodListBytes) { jsonData in
            // Decode the JSON object and set variables.
            do {
                // Decode the JSON into codable type ReflectionGetMethodListJSON.
                let decoder = JSONDecoder()
                let methodsJSON = try decoder.decode(ReflectionGetMethodListJSON.self, from: jsonData)
                
                // Piwigo error?
                if methodsJSON.errorCode != 0 {
                    let error = self.localizedError(for: methodsJSON.errorCode,
                                                    errorMessage: methodsJSON.errorMessage)
                    failure(error as NSError)
                    return
                }
                
                // Check if the Community extension is installed and active (since Piwigo 2.9a)
                NetworkVars.usesCommunityPluginV29 = methodsJSON.data.contains("community.session.getStatus")
                
                // Check if the pwg.images.uploadAsync method is available (since Piwigo 11)
                NetworkVars.usesUploadAsync = methodsJSON.data.contains("pwg.images.uploadAsync")
                
                // Check if the pwg.categories.calculateOrphans method is available (since Piwigo 12)
                NetworkVars.usesCalcOrphans = methodsJSON.data.contains("pwg.categories.calculateOrphans")
                
                // Check if the pwg.images.setCategory method is available (since Piwigo 14)
                NetworkVars.usesSetCategory = methodsJSON.data.contains("pwg.images.setCategory")
                
                if #available(iOSApplicationExtension 14.0, *) {
                    PwgSession.logger.notice("Community plugin installed: \(NetworkVars.usesCommunityPluginV29, privacy: .public)")
                    PwgSession.logger.notice("uploadAsync method available: \(NetworkVars.usesUploadAsync, privacy: .public)")
                    PwgSession.logger.notice("calculateOrphans method available: \(NetworkVars.usesCalcOrphans, privacy: .public)")
                    PwgSession.logger.notice("setCategory method available: \(NetworkVars.usesSetCategory, privacy: .public)")
                }
                completion()
            }
            catch {
                // Data cannot be digested
                let error = error as NSError
                failure(error)
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            failure(error)
        }
    }
}
