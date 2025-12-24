//
//  JSONManager.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 24/12/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import os
import Foundation

public final class JSONManager: @unchecked Sendable {
    
    // Logs JSON activities
    /// sudo log collect --device --start '2023-04-07 15:00:00' --output piwigo.logarchive
    static let logger = Logger(subsystem: "org.piwigo.piwigoKit", category: String(describing: JSONManager.self))

    // Singleton
    public static let shared = JSONManager()

    // Common functions for retrieving JSON data
    public func postRequest<T: Decodable>(withMethod method: String, paramDict: [String: Any],
                                          jsonObjectClientExpectsToReceive: T.Type,
                                          countOfBytesClientExpectsToReceive: Int64,
                                          completion: @escaping (Result<T, PwgKitError>) -> Void) {
        // Create POST request
        let url = URL(string: NetworkVars.shared.service + "/ws.php?format=json&method=\(method)")
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("utf-8", forHTTPHeaderField: "Accept-Charset")

        // Identify requests performed for a specific album
        // so that they can be easily cancelled.
        if [pwgCategoriesGetList, pwgCategoriesGetImages].contains(method),
           let albumId = paramDict["cat_id"] as? Int {
            request.setValue(String(albumId), forHTTPHeaderField: HTTPCatID)
        }
        
        // Set HTTP header when API keys are used
        request.setAPIKeyHTTPHeader(for: method)
        
        // Combine percent encoded parameters
        request.httpBody = httpBody(for: paramDict)

        // Launch the HTTP(S) request
        let task = dataSession.dataTask(with: request) { data, response, error in
            
            // Communication error?
            if let error = error as? URLError {
                completion(.failure(.requestFailed(innerError: error)))
                return
            }
            
            // Valid response?
            guard let jsonData = data, let httpResponse = response as? HTTPURLResponse
            else {
                completion(.failure(.invalidResponse))
                return
            }
            
            // Absence of HTTP error?
            guard (200...299).contains(httpResponse.statusCode)
            else {
                completion(.failure(.invalidStatusCode(statusCode: httpResponse.statusCode)))
                return
            }
        
            // Data received?
            guard jsonData.isEmpty == false
            else {
                completion(.failure(.emptyJSONobject))
                return
            }

            // Try decoding JSON object
            let decoder = JSONDecoder()
            do {
                let pwgData = try decoder.decode(T.self, from: jsonData)
                
                // Log returned data
                let countsOfBytes = httpResponse.allHeaderFields.count * MemoryLayout<Dictionary<String, Any>>.stride + jsonData.count * MemoryLayout<Data>.stride
#if DEBUG
                let dataStr = String(decoding: jsonData.prefix(100), as: UTF8.self) + "…"
//                let dataStr = String(decoding: jsonData, as: UTF8.self)
                JSONManager.logger.notice("\(method) returned \(countsOfBytes, privacy: .public) bytes: \(dataStr, privacy: .public)")
#else
                JSONManager.logger.notice("\(method) returned \(countsOfBytes, privacy: .public) bytes.")
#endif
                
                // Return decoded object
                completion(.success(pwgData))
            }
            catch let DecodingError.dataCorrupted(context) {
                // Piwigo error?
                if let pwgError = context.underlyingError as? PwgKitError {
                    completion(.failure(pwgError))
                }
                else {
                    self.cleanAndRetryDecoding(jsonData, withDecoder: decoder, forMethod: method,
                                               jsonObjectClientExpectsToReceive: T.self,
                                               error: DecodingError.dataCorrupted(context), completion: completion)
                }
            }
            catch let error as DecodingError {
                self.cleanAndRetryDecoding(jsonData, withDecoder: decoder, forMethod: method,
                                           jsonObjectClientExpectsToReceive: T.self,
                                           error: error, completion: completion)
            }
            catch let error {
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
    
    fileprivate
    func cleanAndRetryDecoding<T: Decodable>(_ jsonData: Data, withDecoder decoder: JSONDecoder, forMethod method: String,
                                             jsonObjectClientExpectsToReceive: T.Type, error: DecodingError,
                                             completion: @escaping (Result<T, PwgKitError>) -> Void)
    {
        // Log invalid returned data
#if DEBUG
        let dataStr = String(decoding: jsonData, as: UTF8.self)
        JSONManager.logger.notice("\(method) returned the invalid JSON data: \(dataStr, privacy: .public)")
#else
        let countsOfBytes = jsonData.count * MemoryLayout<Data>.stride
        JSONManager.logger.notice("\(method) returned \(countsOfBytes, privacy: .public) bytes of invalid JSON data.")
#endif
        
        // Store invalid JSON data for helping user
        jsonData.saveInvalidJSON(for: method)
        
        // Try cleaning JSON object
        var cleanData = jsonData
        guard cleanData.extractingBalancedBraces()
        else {
            completion(.failure(.decodingFailed(innerError: error)))
            return
        }
        
        do {
            // Try decoding cleaner JSON object
            let decodedObject = try decoder.decode(T.self, from: cleanData)

            // Return decoded object
            completion(.success(decodedObject))
        }
        catch let error as DecodingError {
            completion(.failure(.decodingFailed(innerError: error)))
        }
        catch let error {
            completion(.failure(.otherError(innerError: error)))
        }
    }
    
    fileprivate
    func httpBody(for paramDict: [String: Any]) -> Data?
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
