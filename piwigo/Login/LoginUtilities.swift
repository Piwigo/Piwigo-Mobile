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
                                countOfBytesClientExpectsToReceive: 32500) { jsonData in
            // Decode the JSON object and set variables.
            do {
                // Decode the JSON into codable type ImagesGetInfoJSON.
                let decoder = JSONDecoder()
                let methodsJSON = try decoder.decode(ReflectionGetMethodListJSON.self, from: jsonData)

                // Piwigo error?
                if methodsJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: methodsJSON.errorCode,
                                                                    errorMessage: methodsJSON.errorMessage)
                    failure(error as NSError)
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
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            failure(error)
        }
    }

    @objc
    class func performLogin(withUsername username:String, password:String,
                            completion: @escaping () -> Void,
                            failure: @escaping (NSError) -> Void) {
        // Prepare parameters for retrieving image/video infos
        let paramsDict: [String : Any] = ["username" : username,
                                          "password" : password]
        // Launch request
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kPiwigoSessionLogin, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: SessionLoginJSON.self,
                                countOfBytesClientExpectsToReceive: 620) { jsonData in
            // Decode the JSON object and check if the login was successful
            do {
                // Decode the JSON into codable type ImagesGetInfoJSON.
                let decoder = JSONDecoder()
                let loginJSON = try decoder.decode(SessionLoginJSON.self, from: jsonData)

                // Piwigo error?
                if loginJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: loginJSON.errorCode,
                                                                    errorMessage: loginJSON.errorMessage)
                    NetworkVars.hadOpenedSession = false
                    failure(error as NSError)
                    return
                }

                // Login successful
                NetworkVars.username = username
                NetworkVars.hadOpenedSession = true
                completion()
            }
            catch {
                // Data cannot be digested
                NetworkVars.hadOpenedSession = false
                let error = error as NSError
                failure(error)
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            NetworkVars.hadOpenedSession = false
            failure(error)
        }
    }

    @objc
    class func performLogout(completion: @escaping () -> Void,
                             failure: @escaping (NSError) -> Void) {
        // Launch request
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kPiwigoSessionLogout, paramDict: [:],
                                jsonObjectClientExpectsToReceive: SessionLogoutJSON.self,
                                countOfBytesClientExpectsToReceive: 620) { jsonData in
            // Decode the JSON object and check if the logout was successful
            do {
                // Decode the JSON into codable type ImagesGetInfoJSON.
                let decoder = JSONDecoder()
                let loginJSON = try decoder.decode(SessionLogoutJSON.self, from: jsonData)

                // Piwigo error?
                if loginJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: loginJSON.errorCode,
                                                                    errorMessage: loginJSON.errorMessage)
                    NetworkVars.hadOpenedSession = false
                    failure(error as NSError)
                    return
                }

                // Logout successful
                NetworkVars.hadOpenedSession = false
                let error = PwgSession.shared.localizedError(for: 0, errorMessage: "prout")
                failure(error as NSError)
//                completion()
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
            NetworkVars.hadOpenedSession = false
            failure(error)
        }
    }
}
