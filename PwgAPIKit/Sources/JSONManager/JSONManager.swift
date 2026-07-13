//
//  JSONManager.swift
//  PwgAPIKit
//
//  Created by Eddy Lelièvre-Berna on 24/12/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import os
import Foundation
import PwgKit

public final class JSONManager: @unchecked Sendable {
    
    // Logs JSON activities
    /// sudo log collect --device --start '2023-04-07 15:00:00' --output piwigo.logarchive
    static let logger = Logger(subsystem: "org.piwigo.apiKit", category: String(describing: JSONManager.self))

    // Singleton
    public static let shared = JSONManager()

    // Common functions for retrieving JSON data
    public nonisolated
    func postRequest<T: Decodable>(withMethod method: String, paramDict: [String: Any],
                                   jsonObjectClientExpectsToReceive: T.Type,
                                   countOfBytesClientExpectsToReceive: Int64) async throws(PwgKitError) -> T {
        
        // Create POST request
        let url = URL(string: ServerVars.shared.service + "/ws.php?format=json&method=\(method)")
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
        
        // Do {} below is used to allow typed throws
        // withCheckedThrowingContinuation() requires any Error
        do {
            // Launch the HTTP(S) request
            return try await withCheckedThrowingContinuation { continuation in
                let task = dataSession.dataTask(with: request) { data, response, error in
                    
                    // Communication error?
                    if let error = error as? URLError {
                        continuation.resume(throwing: PwgKitError.requestFailed(innerError: error))
                        return
                    }
                    
                    // Valid response?
                    guard let jsonData = data, let httpResponse = response as? HTTPURLResponse
                    else {
                        continuation.resume(throwing: PwgKitError.invalidResponse)
                        return
                    }
                    
                    // Absence of HTTP error?
                    guard (200...299).contains(httpResponse.statusCode)
                    else {
                        continuation.resume(throwing: PwgKitError.invalidStatusCode(statusCode: httpResponse.statusCode))
                        return
                    }
                    
                    // Data received?
                    guard jsonData.isEmpty == false
                    else {
                        continuation.resume(throwing: PwgKitError.emptyJSONobject)
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
                        JSONManager.logger.notice("\(method, privacy: .public) returned \(countsOfBytes, privacy: .public) bytes: \(dataStr, privacy: .public)")
#else
                        JSONManager.logger.notice("\(method, privacy: .public) returned \(countsOfBytes, privacy: .public) bytes.")
#endif
                        
                        // Return decoded object
                        continuation.resume(returning: pwgData)
                    }
                    catch let DecodingError.dataCorrupted(context) {
                        // Piwigo error?
                        if let pwgError = context.underlyingError as? PwgKitError {
                            continuation.resume(throwing: pwgError)
                        }
                        else {
                            self.cleanAndRetryDecoding(jsonData, withDecoder: decoder, forMethod: method,
                                                       jsonObjectClientExpectsToReceive: T.self,
                                                       error: DecodingError.dataCorrupted(context)) { result in
                                switch result {
                                case .success(let decodedData):
                                    continuation.resume(returning: decodedData)
                                case .failure(let error):
                                    continuation.resume(throwing: error)
                                }
                            }
                        }
                    }
                    catch let error as DecodingError {
                        self.cleanAndRetryDecoding(jsonData, withDecoder: decoder, forMethod: method,
                                                   jsonObjectClientExpectsToReceive: T.self,
                                                   error: error) { result in
                            switch result {
                            case .success(let decodedData):
                                continuation.resume(returning: decodedData)
                            case .failure(let error):
                                continuation.resume(throwing: error)
                            }
                        }
                    }
                    catch let error {
                        continuation.resume(throwing: PwgKitError.otherError(innerError: error))
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
        }
        catch let error as PwgKitError {
            throw error
        }
        catch {
            throw PwgKitError.otherError(innerError: error)
        }
    }
    
    fileprivate
    func cleanAndRetryDecoding<T: Decodable>(_ jsonData: Data, withDecoder decoder: JSONDecoder, forMethod method: String,
                                             jsonObjectClientExpectsToReceive: T.Type, error: DecodingError,
                                             completion: @escaping (Result<T, PwgKitError>) -> Void)
    {
        // Log invalid returned data
#if DEBUG
        let dataStr = String(decoding: jsonData, as: UTF8.self)
        JSONManager.logger.notice("\(method, privacy: .public) returned the invalid JSON data: \(dataStr, privacy: .public)")
#else
        let countsOfBytes = jsonData.count * MemoryLayout<Data>.stride
        JSONManager.logger.notice("\(method, privacy: .public) returned \(countsOfBytes, privacy: .public) bytes of invalid JSON data.")
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


// MARK: - RFC 3986 allowed characters
extension CharacterSet {
    /// Creates a CharacterSet from RFC 3986 allowed characters.
    ///
    /// https://datatracker.ietf.org/doc/html/rfc3986/#section-2.2
    /// Section 2.2 states that the following characters are "reserved" characters.
    ///
    /// - General Delimiters: ":", "#", "[", "]", "@", "?", "/"
    /// - Sub-Delimiters: "!", "$", "&", "'", "(", ")", "*", "+", ",", ";", "="
    ///
    /// https://datatracker.ietf.org/doc/html/rfc3986/#section-3.4
    /// Section 3.4 states that the "?" and "/" characters should not be escaped to allow
    /// query strings to include a URL. Therefore, all "reserved" characters with the exception of "?" and "/"
    /// should be percent-escaped in the query string.
    ///
    public static let pwgURLQueryAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@"
        let subDelimitersToEncode = "!$&'()*+,;="
        let encodableDelimiters = CharacterSet(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")

        return CharacterSet.urlQueryAllowed.subtracting(encodableDelimiters)
    }()
}


// MARK: - API Key Management
extension URLRequest
{
    public mutating
    func setAPIKeyHTTPHeader(for method: String) {
        // Piwigo server managing API keys
        // and method not prohibited with API keys?
        guard NetworkVars.shared.usesAPIkeys,
              NetworkVars.shared.apiKeysProhibitedMethods.contains(method) == false
        else { return }
        
        // API key available?
        let publicKey = ServerVars.shared.username
        guard publicKey.isValidPublicKey()
        else { return }
        
        // Set HTTP header from keys
        let secretKey = KeychainUtilities.password(forService: ServerVars.shared.serverPath,
                                                   account: ServerVars.shared.username)
        setValue("\(publicKey):\(secretKey)", forHTTPHeaderField: HTTPAPIKey)
    }
}
