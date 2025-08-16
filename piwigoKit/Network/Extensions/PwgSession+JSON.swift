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
                                          completion: @escaping (Result<Data, Error>) -> Void) {
        // Create POST request
        let url = URL(string: NetworkVars.shared.service + "/ws.php?\(method)")
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("utf-8", forHTTPHeaderField: "Accept-Charset")

        // Identify requests performed for a specific album
        // so that they can be easily cancelled.
        switch method {
        case pwgCategoriesGetList, pwgCategoriesGetImages:
            if let albumId = paramDict["cat_id"] as? Int {
                request.setValue(String(albumId), forHTTPHeaderField: NetworkVars.shared.HTTPCatID)
            }
        default:
            break
        }

        // Combine percent encoded parameters
        request.httpBody = httpBody(for: paramDict)

        // Launch the HTTP(S) request
        let task = dataSession.dataTask(with: request) { data, response, error in
            do {
                // Return communication error if any
                if let error = error {
                    throw error
                }
                
                // No error, check that we received a valid response
                guard var jsonData = data, let httpResponse = response as? HTTPURLResponse
                else { throw PwgSessionError.invalidResponse }
                
                // Valid response, check the absence of HTTP error
                guard (200...299).contains(httpResponse.statusCode)
                else { // Return HTTP error code
                    let errorMessage = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                    let error = PwgSessionError.otherError(code: httpResponse.statusCode, msg: errorMessage)
                    throw error
                }
                
                // Check that we have received some data
                guard var jsonData = data, jsonData.isEmpty == false
                else { throw PwgSessionError.emptyJSONobject }
                
                // Data returned, check that it is a valid JSON object after cleanup
                guard jsonData.isPiwigoResponseValid(for: jsonObjectClientExpectsToReceive.self, method: method)
                else {
                    // Invalid JSON data
                    if #available(iOSApplicationExtension 14.0, *) {
                        #if DEBUG
                        let dataStr = String(decoding: jsonData, as: UTF8.self)
                        PwgSession.logger.notice("Received invalid JSON data: \(dataStr, privacy: .public)")
                        #else
                        let countsOfBytes = jsonData.count * MemoryLayout<Data>.stride
                        PwgSession.logger.notice("Received \(countsOfBytes, privacy: .public) bytes of invalid JSON data.")
                        #endif
                    }
                    // Return error
                    throw PwgSessionError.invalidJSONobject
                }
                
                // Log returned data
                if #available(iOSApplicationExtension 14.0, *) {
                    let countsOfBytes = httpResponse.allHeaderFields.count * MemoryLayout<Dictionary<String, Any>>.stride + jsonData.count * MemoryLayout<Data>.stride
                #if DEBUG
                    let dataStr = String(decoding: jsonData.prefix(100), as: UTF8.self) + "…"
    //                let dataStr = String(decoding: jsonData, as: UTF8.self)
                    PwgSession.logger.notice("Received \(countsOfBytes, privacy: .public) bytes: \(dataStr, privacy: .public)")
                #else
                    PwgSession.logger.notice("Received \(countsOfBytes, privacy: .public) bytes of data.")
                #endif
                }

                // The caller will decode the returned data
                completion(.success(jsonData))
                
            } catch {
                completion(.failure(error))
            }
        }
        
        // Tell the system how many bytes are expected to be exchanged
        task.countOfBytesClientExpectsToSend = Int64((request.httpBody ?? Data()).count +
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
    
    private func httpBody(for paramDict: [String: Any]) -> Data?
    {
        var urlComponents = URLComponents()
        var queryItems: [URLQueryItem] = []
        for (key, value) in paramDict {
            if let valArray = value as? [NSNumber] {
                let keyArray = key + "[]"
                valArray.forEach { valNum in
                    let queryItem = URLQueryItem(name: keyArray, value: valNum.stringValue)
                    queryItems.append(queryItem)
                }
            }
            else if let valArray = value as? [String] {
                let keyArray = key + "[]"
                valArray.forEach { valStr in
                    // Piwigo 2.10.2 supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
                    let utf8mb3Str = valStr.utf8mb3Encoded
                    let encStr = utf8mb3Str.addingPercentEncoding(withAllowedCharacters: .pwgURLQueryAllowed) ?? utf8mb3Str
                    let queryItem = URLQueryItem(name: keyArray, value: encStr)
                    queryItems.append(queryItem)
                }
            }
            else if let valNum = value as? NSNumber {
                let queryItem = URLQueryItem(name: key, value: valNum.stringValue)
                queryItems.append(queryItem)
            }
            else if let valStr = value as? String, valStr.isEmpty == false {
                // Piwigo 2.10.2 supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
                let utf8mb3Str = valStr.utf8mb3Encoded
                let encStr = utf8mb3Str.addingPercentEncoding(withAllowedCharacters: .pwgURLQueryAllowed) ?? utf8mb3Str
                let queryItem = URLQueryItem(name: key, value: encStr)
                queryItems.append(queryItem)
            }
            else {
                let queryItem = URLQueryItem(name: key, value: nil)
                queryItems.append(queryItem)
            }
        }
        urlComponents.queryItems = queryItems
        return urlComponents.query?.data(using: .utf8)
    }
}
