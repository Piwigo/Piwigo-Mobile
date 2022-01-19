//
//  PwgSession.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 08/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

public class PwgSession: NSObject {
    
    // Singleton
    public static var shared = PwgSession()
    
    // Create single instance
    public lazy var dataSession: URLSession = {
        let config = URLSessionConfiguration.default

        // Additional headers that are added to all tasks
        config.httpAdditionalHeaders = ["Content-Type"   : "application/x-www-form-urlencoded",
                                        "Accept"         : "application/json",
                                        "Accept-Charset" : "utf-8"]

        /// Network service type for data that the user is actively waiting for.
        config.networkServiceType = .responsiveData
        
        /// Indicates that the request is allowed to use the built-in cellular radios to satisfy the request.
        config.allowsCellularAccess = true

        /// How long a task should wait for additional data to arrive before giving up (30 seconds)
        config.timeoutIntervalForRequest = 30
        
        /// How long a task should be allowed to be retried or transferred (10 minutes).
        config.timeoutIntervalForResource = 600
        
        /// Determines the maximum number of simultaneous connections made to the host by tasks (4 by default)
        config.httpMaximumConnectionsPerHost = 4
        
        /// Requests should contain cookies from the cookie store.
        config.httpShouldSetCookies = true
        
        /// Accept all cookies.
        config.httpCookieAcceptPolicy = .always
        
        /// Allows a seamless handover from Wi-Fi to cellular
        if #available(iOS 11.0, *) {
            config.multipathServiceType = .handover
        }
        
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    

    // MARK: - Session Methods
    public func postRequest<T: Decodable>(withMethod method: String, paramDict: [String: Any],
                     jsonObjectClientExpectsToReceive: T.Type,
                     countOfBytesClientExpectsToReceive:Int64,
                     completionHandler: @escaping (Data, Error?) -> Void) {
        // Create POST request
        let urlStr = "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)"
        let url = URL(string: urlStr + "/ws.php?\(method)")
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        request.networkServiceType = .responsiveData

        // Combine percent encoded parameters
        var encPairs = [String]()
        for (key, value) in paramDict {
            if let valStr = value as? String, !valStr.isEmpty {
                // Piwigo 2.10.2 supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
                let utf8mb3Str = NetworkUtilities.utf8mb3String(from: valStr)
                if let encVal = utf8mb3Str.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                   let encKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                    encPairs.append(String(format: "%@=%@", encKey, encVal))
                    continue
                }
            }
            else if let val = value as? NSNumber,
                let encKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                let encVal = val.stringValue
                encPairs.append(String(format: "%@=%@", encKey, encVal))
                continue
            }
            else if let encKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
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
                    if var jsonData = data, jsonData.isPiwigoResponseValid(for: jsonObjectClientExpectsToReceive.self) {
                        #if DEBUG
                        let dataStr = String(decoding: jsonData, as: UTF8.self)
                        print(" > JSON: \(dataStr.debugDescription)")
                        #endif
                        completionHandler(jsonData, nil)
                    } else {
                        let error = NSError(domain: "Piwigo", code: JsonError.emptyJSONobject.hashValue, userInfo: [NSLocalizedDescriptionKey : JsonError.emptyJSONobject.localizedDescription])
                        completionHandler(Data(), error)
                    }
                    return
                }
                
                // Return transaction error
                completionHandler(Data(), error)
                return
            }
            
            // Return Piwigo error if no error and no data returned.
            guard var jsonData = data, jsonData.isPiwigoResponseValid(for: jsonObjectClientExpectsToReceive.self) else {
                let error = NSError(domain: "Piwigo", code: JsonError.emptyJSONobject.hashValue, userInfo: [NSLocalizedDescriptionKey : JsonError.emptyJSONobject.localizedDescription])
                completionHandler(Data(), error)
                return
            }

            // Check returned data
            /// - The following 2 lines are used to determine the count of returned bytes.
            /// - This value can then be used to provide the expected count of returned bytes.
            /// - The last 2 lines display the content of the returned data for debugging.
            #if DEBUG
            let countsOfByte = httpResponse.allHeaderFields.count * MemoryLayout<Dictionary<String, Any>>.stride +
                jsonData.count * MemoryLayout<Data>.stride
            print("countsOfBytesReceived: \(countsOfByte) bytes")
            let dataStr = String(decoding: jsonData, as: UTF8.self)
            print(" > JSON: \(dataStr.debugDescription)")
            #endif
            
            // The caller will decode the returned data
            completionHandler(jsonData, nil)
        }
        
        // Inform iOS so that it can optimize the scheduling of the task
        if #available(iOS 11.0, *) {
            // Tell the system how many bytes are expected to be exchanged
            task.countOfBytesClientExpectsToSend = Int64((httpBody ?? Data()).count +
                                                            (request.allHTTPHeaderFields ?? [:]).count)
            task.countOfBytesClientExpectsToReceive = countOfBytesClientExpectsToReceive
        }
        task.resume()
    }
}


// MARK: - Session Delegate
extension PwgSession: URLSessionDelegate {

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        print("    > The data session has been invalidated")
    }
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("    > Session-level authentication request from the remote server \(NetworkVars.domain)")
        
        // Get protection space for current domain
        let protectionSpace = challenge.protectionSpace
        guard protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              protectionSpace.host.contains(NetworkVars.domain) else {
                completionHandler(.rejectProtectionSpace, nil)
                return
        }

        // Get state of the server SSL transaction state
        guard let serverTrust = protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Check validity of certificate
        if KeychainUtilities.isSSLtransactionValid(inState: serverTrust, for: NetworkVars.domain) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            return
        }
        
        // If there is no certificate, reject server (should rarely happen)
        if SecTrustGetCertificateCount(serverTrust) == 0 {
            // No certificate!
            completionHandler(.rejectProtectionSpace, nil)
        }

        // Check if the certificate is trusted by user (i.e. is in the Keychain)
        // Case where the certificate is e.g. self-signed
        if KeychainUtilities.isCertKnownForSSLtransaction(inState: serverTrust, for: NetworkVars.domain) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            return
        }
        
        // Cancel the upload
        completionHandler(.cancelAuthenticationChallenge, nil)
    }
}


// MARK: - Session Task Delegate
extension PwgSession: URLSessionDataDelegate {
        
    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("    > Task-level authentication request from the remote server")

        // Check authentication method
        let authMethod = challenge.protectionSpace.authenticationMethod
        guard authMethod == NSURLAuthenticationMethodHTTPBasic,
            authMethod == NSURLAuthenticationMethodHTTPDigest else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Get HTTP basic authentification credentials
        let service = NetworkVars.serverProtocol + NetworkVars.serverPath
        let account = NetworkVars.httpUsername
        let password = KeychainUtilities.password(forService: service, account: account)
        if password.isEmpty {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        let credential = URLCredential(user: account,
                                       password: password,
                                       persistence: .forSession)
        completionHandler(.useCredential, credential)
    }
}
