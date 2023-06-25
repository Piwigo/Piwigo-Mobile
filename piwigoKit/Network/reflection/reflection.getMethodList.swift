//
//  reflection.getMethodList.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 14/02/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

public let kReflectionGetMethodList = "format=json&method=reflection.getMethodList"

// MARK: Piwigo JSON Structure
public struct ReflectionGetMethodListJSON: Decodable {
    
    public var status: String?
    public var data = [String]()
    public var errorCode = 0
    public var errorMessage = ""

    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case data = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }

    private enum ResultCodingKeys: String, CodingKey {
        case methods
    }
    
    private enum ErrorCodingKeys: String, CodingKey {
        case code = "code"
        case message = "msg"
    }

    public init(from decoder: Decoder) throws
    {
        // Root container keyed by RootCodingKeys
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
        
        // Status returned by Piwigo
        status = try rootContainer.decodeIfPresent(String.self, forKey: .status)
        if (status == "ok")
        {
            // Result container keyed by ResultCodingKeys
            let resultContainer = try rootContainer.nestedContainer(keyedBy: ResultCodingKeys.self, forKey: .data)
//            dump(resultContainer)
            
            // Decodes pending properties from the data and store them in the array
            do {
                // Use ComImageProperties struct
                try data = resultContainer.decode([String].self, forKey: .methods)
            }
            catch {
                // Returns an empty array => No method!
            }
        }
        else if (status == "fail")
        {
            // Retrieve Piwigo server error
            do {
                // Retrieve Piwigo server error
                errorCode = try rootContainer.decode(Int.self, forKey: .errorCode)
                errorMessage = try rootContainer.decode(String.self, forKey: .errorMessage)
            }
            catch {
                // Error container keyed by ErrorCodingKeys ("format=json" forgotten in call)
                let errorContainer = try rootContainer.nestedContainer(keyedBy: ErrorCodingKeys.self, forKey: .errorCode)
                errorCode = Int(try errorContainer.decode(String.self, forKey: .code)) ?? NSNotFound
                errorMessage = try errorContainer.decode(String.self, forKey: .message)
            }
        }
        else {
            // Unexpected Piwigo server error
            errorCode = -1
            errorMessage = NSLocalizedString("serverUnknownError_message", comment: "Unexpected error encountered while calling server method with provided parameters.")
        }
    }
}


// MARK: - Piwigo Method Caller
extension PwgSession {
    
    public func getMethods(completion: @escaping () -> Void,
                           failure: @escaping (NSError) -> Void) {
        if #available(iOSApplicationExtension 14.0, *) {
            NetworkUtilities.logger.notice("Retrieve methods…")
        }
        // Launch request
        postRequest(withMethod: kReflectionGetMethodList, paramDict: [:],
                    jsonObjectClientExpectsToReceive: ReflectionGetMethodListJSON.self,
                    countOfBytesClientExpectsToReceive: 32500) { jsonData in
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
                
                // Check if the Community extension is installed and active (> 2.9a)
                NetworkVars.usesCommunityPluginV29 = methodsJSON.data.contains("community.session.getStatus")
                
                // Check if the pwg.images.uploadAsync method is available
                NetworkVars.usesUploadAsync = methodsJSON.data.contains("pwg.images.uploadAsync")
                
                // Check if the pwg.categories.calculateOrphans method is available
                NetworkVars.usesCalcOrphans = methodsJSON.data.contains("pwg.categories.calculateOrphans")
                
                if #available(iOSApplicationExtension 14.0, *) {
                    NetworkUtilities.logger.notice("Has Community: \(NetworkVars.usesUploadAsync, privacy: .public), uploadAsync: \(NetworkVars.usesUploadAsync, privacy: .public), calcOrphans: \(NetworkVars.usesCalcOrphans, privacy: .public)")
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
