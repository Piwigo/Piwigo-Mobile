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
                                          completion: @escaping (Result<T, PwgKitError>) -> Void) {
        // Create POST request
        let url = URL(string: NetworkVars.shared.service + "/ws.php?\(method)")
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("utf-8", forHTTPHeaderField: "Accept-Charset")

        // Identify requests performed for a specific album
        // so that they can be easily cancelled.
        if [pwgCategoriesGetList, pwgCategoriesGetImages].contains(method),
           let albumId = paramDict["cat_id"] as? Int {
            request.setValue(String(albumId), forHTTPHeaderField: NetworkVars.shared.HTTPCatID)
        }
        
        // Set HTTP header when API keys are used
        request.setAPIKeyHTTPHeader(for: method)
        
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
                else { throw PwgKitError.invalidResponse }
                
                // Valid response, check the absence of HTTP error
                guard (200...299).contains(httpResponse.statusCode)
                else { throw PwgKitError.invalidStatusCode(statusCode: httpResponse.statusCode) }
                
                // Check that we have received some data
                guard jsonData.isEmpty == false
                else { throw PwgKitError.emptyJSONobject }
                
                // Data returned, try decoding JSON object
                do {
                    let decoder = JSONDecoder()
                    let pwgData = try decoder.decode(jsonObjectClientExpectsToReceive.self, from: jsonData)
                    
                    // Log returned data
                    let countsOfBytes = httpResponse.allHeaderFields.count * MemoryLayout<Dictionary<String, Any>>.stride + jsonData.count * MemoryLayout<Data>.stride
#if DEBUG
                    let dataStr = String(decoding: jsonData.prefix(100), as: UTF8.self) + "…"
//                    let dataStr = String(decoding: jsonData, as: UTF8.self)
                    PwgSession.logger.notice("\(method) returned \(countsOfBytes, privacy: .public) bytes: \(dataStr, privacy: .public)")
#else
                    PwgSession.logger.notice("\(method) returned \(countsOfBytes, privacy: .public) bytes.")
#endif
                    
                    // Return decoded object
                    completion(.success(pwgData))
                }
                catch let error {
                    // Log invalid returned data
#if DEBUG
                    let dataStr = String(decoding: jsonData, as: UTF8.self)
                    PwgSession.logger.notice("\(method) returned the invalid JSON data: \(dataStr, privacy: .public)")
#else
                    let countsOfBytes = jsonData.count * MemoryLayout<Data>.stride
                    PwgSession.logger.notice("\(method) returned \(countsOfBytes, privacy: .public) bytes of invalid JSON data.")
#endif
                    
                    // Store invalid JSON data for helping user
                    jsonData.saveInvalidJSON(for: method)

                    // Try extracting a JSON object
                    guard jsonData.extractingBalancedBraces()
                    else { throw error }
                    
                    // Data filtered, try decoding JSON object
                    do {
                        let decoder = JSONDecoder()
                        let decodedObject = try decoder.decode(jsonObjectClientExpectsToReceive.self, from: jsonData)
                        
                        // Return decoded object
                        completion(.success(decodedObject))
                    }
                    catch {
                        // Still invalid JSON data
                        throw error
                    }
                }
            }
            catch let error as DecodingError {
                completion(.failure(.decodingFailed(innerError: error)))
            }
            catch let error as URLError {
                completion(.failure(.requestFailed(innerError: error)))
            }
            catch let error as PwgKitError {
                completion(.failure(error))
            }
            catch {
                completion(.failure(.otherError(innerError: error)))
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
    
    fileprivate func httpBody(for paramDict: [String: Any]) -> Data?
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
