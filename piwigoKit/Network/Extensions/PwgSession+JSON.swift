//
//  PwgSession+JSON.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 08/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - JSON Requests
extension PwgSession
{
    public func postRequest<T: Decodable>(withMethod method: String, paramDict: [String: Any],
                                          jsonObjectClientExpectsToReceive: T.Type,
                                          countOfBytesClientExpectsToReceive: Int64,
                                          success: @escaping (Data) -> Void,
                                          failure: @escaping (NSError) -> Void) {
        // Create POST request
        let url = URL(string: NetworkVars.service + "/ws.php?\(method)")
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("utf-8", forHTTPHeaderField: "Accept-Charset")
        switch method {
        case pwgCategoriesGetList, pwgCategoriesGetImages:
            // Identify requests performed for a specific album
            // so that they can be easily cancelled.
            if let albumId = paramDict["cat_id"] as? Int {
                request.setValue(String(albumId), forHTTPHeaderField: NetworkVars.HTTPCatID)
            }
        default:
            break
        }

        // Combine percent encoded parameters
        var encPairs = [String]()
        for (key, value) in paramDict {
            if let valStr = value as? String, valStr.isEmpty == false {
                let encKey = key.addingPercentEncoding(withAllowedCharacters: .pwgURLQueryAllowed) ?? key
                // Piwigo 2.10.2 supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
                let utf8mb3Str = PwgSession.utf8mb3String(from: valStr)
                let encVal = utf8mb3Str.addingPercentEncoding(withAllowedCharacters: .pwgURLQueryAllowed) ?? utf8mb3Str
                encPairs.append(String(format: "%@=%@", encKey, encVal))
                continue
            }
            else if let val = value as? NSNumber {
                let encKey = key.addingPercentEncoding(withAllowedCharacters: .pwgURLQueryAllowed) ?? key
                let encVal = val.stringValue
                encPairs.append(String(format: "%@=%@", encKey, encVal))
                continue
            }
            else {
                let encKey = key.addingPercentEncoding(withAllowedCharacters: .pwgURLQueryAllowed) ?? key
                encPairs.append(encKey)
            }
        }
        let encParams = encPairs.joined(separator: "&")
        let httpBody = encParams.data(using: .utf8, allowLossyConversion: true)
        request.httpBody = httpBody

        // Launch the HTTP(S) request
        let task = dataSession.dataTask(with: request) { data, response, error in
            // Transaction completed?
            guard let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode) else {
                // Transaction error
                guard let error = error else {
                    // No communication error returned,
                    // so Piwigo returned an error to be handled by the caller.
                    guard var jsonData = data, jsonData.isEmpty == false else {
                        // Empty JSON data
                        guard let httpResponse = response as? HTTPURLResponse else {
                            // Nothing to report
                            failure(PwgSessionError.emptyJSONobject as NSError)
                            return
                        }
                        
                        // Return error code
                        let error = self.localizedError(for: httpResponse.statusCode)
                        failure(error as NSError)
                        return
                    }

                    // Data returned, is this a valid JSON object?
                    guard jsonData.isPiwigoResponseValid(for: jsonObjectClientExpectsToReceive.self,
                                                         method: method) else {
                        // Invalid JSON data
                        #if DEBUG
                        if #available(iOSApplicationExtension 14.0, *) {
                            let dataStr = String(decoding: jsonData, as: UTF8.self)
                            PwgSession.logger.notice("Received invalid JSON data: \(dataStr, privacy: .public)")
                        }
                        #endif
                        guard let httpResponse = response as? HTTPURLResponse else {
                            // Nothing to report
                            failure(PwgSessionError.invalidJSONobject as NSError)
                            return
                        }
                        
                        // Return error code
                        let errorMessage = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                        let error = self.localizedError(for: httpResponse.statusCode,
                                                        errorMessage: errorMessage)
                        failure(error as NSError)
                        return
                    }
                    
                    // The caller will decode the returned data
                    success(jsonData)
                    return
                }
                
                // Return transaction error
                failure(error as NSError)
                return
            }
            
            // No error, check that the JSON object is not empty
            guard var jsonData = data, jsonData.isEmpty == false else {
                // Empty JSON data
                failure(PwgSessionError.emptyJSONobject as NSError)
                return
            }
            
            // Log returned data
            if #available(iOSApplicationExtension 14.0, *) {
                let countsOfByte = httpResponse.allHeaderFields.count * MemoryLayout<Dictionary<String, Any>>.stride + jsonData.count * MemoryLayout<Data>.stride
            #if DEBUG
                let dataStr = String(decoding: jsonData.prefix(70), as: UTF8.self) + "…"
//                let dataStr = String(decoding: jsonData, as: UTF8.self)
                PwgSession.logger.notice("Received \(countsOfByte, privacy: .public) bytes of JSON data: \(dataStr, privacy: .public)")
            #else
                PwgSession.logger.notice("Received \(countsOfByte, privacy: .public) bytes of JSON data")
            #endif
            }

            // Return Piwigo error if no error and no data returned.
            guard jsonData.isPiwigoResponseValid(for: jsonObjectClientExpectsToReceive.self, 
                                                 method: method) else {
                failure(PwgSessionError.invalidJSONobject as NSError)
                return
            }

            // The caller will decode the returned data
            success(jsonData)
        }
        
        // Tell the system how many bytes are expected to be exchanged
        task.countOfBytesClientExpectsToSend = Int64((httpBody ?? Data()).count +
                                                        (request.allHTTPHeaderFields ?? [:]).count)
        task.countOfBytesClientExpectsToReceive = countOfBytesClientExpectsToReceive

        // Sets the task description from the method
        if let pos = method.lastIndex(of: "=") {
            task.taskDescription = String(method[pos...].dropFirst())
        } else {
            task.taskDescription = method.components(separatedBy: "=").last
        }
        
        // Execute the task
        task.resume()
    }
}
