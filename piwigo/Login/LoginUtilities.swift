//
//  LoginUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 14/02/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

@objc
class LoginUtilities: NSObject {
    
    // MARK: - Piwigo Server Methods
    @objc
    class func getMethods(completion: @escaping () -> Void,
                          failure: @escaping (NSError) -> Void) {
        // Launch request
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kReflectionGetMethodList, paramDict: [:],
                                jsonObjectClientExpectsToReceive: ReflectionGetMethodListJSON.self,
                                countOfBytesClientExpectsToReceive: 32500) { jsonData, error in
            // Any error?
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            if let error = error as NSError? {
                failure(error)
                return
            }
            
            // Decode the JSON and import it into Core Data.
            do {
                // Decode the JSON into codable type ImagesGetInfoJSON.
                let decoder = JSONDecoder()
                let methodsJSON = try decoder.decode(ReflectionGetMethodListJSON.self, from: jsonData)

                // Piwigo error?
                if (methodsJSON.errorCode != 0) || methodsJSON.data.isEmpty {
                    let error = NSError(domain: "Piwigo", code: methodsJSON.errorCode,
                                        userInfo: [NSLocalizedDescriptionKey : methodsJSON.errorMessage])
                    failure(error)
                    return
                }

                // Check if the Community extension is installed and active (> 2.9a)
                NetworkVars.usesCommunityPluginV29 = methodsJSON.data.contains("community.session.getStatus")
                
                // Check if the pwg.images.uploadAsync method is available
                NetworkVars.usesUploadAsync = methodsJSON.data.contains("pwg.images.uploadAsync")

                completion()
            }
            catch {
                // Data cannot be digested
                let error = error as NSError
                failure(error)
            }
        }
    }
}
