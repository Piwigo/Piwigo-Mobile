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
        
        /// Create the main session and set its description
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        session.sessionDescription = "Main Session"
        
        return session
    }()
    

    // MARK: - Session Methods
    public func postRequest<T: Decodable>(withMethod method: String, paramDict: [String: Any],
                                          jsonObjectClientExpectsToReceive: T.Type,
                                          countOfBytesClientExpectsToReceive:Int64,
                                          success: @escaping (Data) -> Void,
                                          failure: @escaping (NSError) -> Void) {
        // Create POST request
        let urlStr = "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)"
        let url = URL(string: urlStr + "/ws.php?\(method)")
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        request.networkServiceType = .responsiveData

        // Combine percent encoded parameters
        var encPairs = [String]()
        for (key, value) in paramDict {
            if let valStr = value as? String, valStr.isEmpty == false {
                let encKey = key.addingPercentEncoding(withAllowedCharacters: .pwgURLQueryAllowed) ?? key
                // Piwigo 2.10.2 supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
                let utf8mb3Str = NetworkUtilities.utf8mb3String(from: valStr)
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
                            failure(JsonError.emptyJSONobject as NSError)
                            return
                        }
                        
                        // Return error code
                        let error = PwgSession.shared.localizedError(for: httpResponse.statusCode)
                        failure(error as NSError)
                        return
                    }

                    // Data returned, is this a valid JSON object?
                    guard jsonData.isPiwigoResponseValid(for: jsonObjectClientExpectsToReceive.self) else {
                        // Invalid JSON data
						#if DEBUG
						let dataStr = String(decoding: jsonData, as: UTF8.self)
						print(" > JSON: \(dataStr)")
						#endif
                        guard let httpResponse = response as? HTTPURLResponse else {
                            // Nothing to report
                            failure(JsonError.invalidJSONobject as NSError)
                            return
                        }
                        
                        // Return error code
                        let errorMessage = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                        let error = PwgSession.shared.localizedError(for: httpResponse.statusCode,
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
                failure(JsonError.emptyJSONobject as NSError)
                return
            }
            
            // Return Piwigo error if no error and no data returned.
            guard jsonData.isPiwigoResponseValid(for: jsonObjectClientExpectsToReceive.self) else {
                failure(JsonError.invalidJSONobject as NSError)
                return
            }

            // Check returned data
            /// - The following 2 lines are used to determine the count of returned bytes.
            /// - This value can then be used to provide the expected count of returned bytes.
            /// - The last 2 lines display the content of the returned data for debugging.
            #if DEBUG
            let countsOfByte = httpResponse.allHeaderFields.count * MemoryLayout<Dictionary<String, Any>>.stride +
                jsonData.count * MemoryLayout<Data>.stride
            print(" > Bytes received: \(countsOfByte) bytes")
            let dataStr = String(decoding: jsonData, as: UTF8.self)
            print(" > JSON: \(dataStr)")
            #endif
            
            // The caller will decode the returned data
            success(jsonData)
        }
        
        // Inform iOS so that it can optimize the scheduling of the task
        if #available(iOS 11.0, *) {
            // Tell the system how many bytes are expected to be exchanged
            task.countOfBytesClientExpectsToSend = Int64((httpBody ?? Data()).count +
                                                            (request.allHTTPHeaderFields ?? [:]).count)
            task.countOfBytesClientExpectsToReceive = countOfBytesClientExpectsToReceive
        }

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

        // Initialise SSL certificate approval flag
        NetworkVars.didRejectCertificate = false

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
            completionHandler(.performDefaultHandling, nil)
        }

        // Retrieve the certificate of the server
        guard let certificate = SecTrustGetCertificateAtIndex(serverTrust, CFIndex(0)) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Check if the certificate is trusted by user (i.e. is in the Keychain)
        // Case where the certificate is e.g. self-signed
        if KeychainUtilities.isCertKnownForSSLtransaction(certificate, for: NetworkVars.domain) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            return
        }
        
        // No certificate or different non-trusted certificate found in Keychain
        // Did the user approve this certificate?
        if NetworkVars.didApproveCertificate {
            // Delete certificate in Keychain (updating the certificate data is not sufficient)
            KeychainUtilities.deleteCertificate(for: NetworkVars.domain)

            // Store server certificate in Keychain with same label "Piwigo:<host>"
            KeychainUtilities.storeCertificate(certificate, for: NetworkVars.domain)

            // Will reject a connection if the certificate is changed during a session
            // but it will still be possible to logout.
            NetworkVars.didApproveCertificate = false
            
            // Accept connection
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            return
        }
        
        // Will ask the user whether we should trust this server.
        NetworkVars.certificateInformation = KeychainUtilities.getCertificateInfo(certificate, for: NetworkVars.domain)
        NetworkVars.didRejectCertificate = true

        // Reject the request
        completionHandler(.performDefaultHandling, nil)
    }
}


// MARK: - Session Task Delegate
extension PwgSession: URLSessionDataDelegate {
        
    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("    > Task-level authentication request from the remote server")

        // Check authentication method
        let authMethod = challenge.protectionSpace.authenticationMethod
        guard [NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest].contains(authMethod) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Initialise HTTP authentication flag
        NetworkVars.didFailHTTPauthentication = false
        
        // Get HTTP basic authentification credentials
        let service = NetworkVars.serverProtocol + NetworkVars.serverPath
        var account = NetworkVars.httpUsername
        var password = KeychainUtilities.password(forService: service, account: account)

        // Without HTTP credentials available, tries Piwigo credentials
        if account.isEmpty || password.isEmpty {
            // Retrieve Piwigo credentials
            account = NetworkVars.username
            password = KeychainUtilities.password(forService: NetworkVars.serverPath, account: account)
            
            // Adopt Piwigo credentials as HTTP basic authentification credentials
            NetworkVars.httpUsername = account
            KeychainUtilities.setPassword(password, forService: service, account: account)
        }

        // Supply requested credentials if not provided yet
        if (challenge.previousFailureCount == 0) {
            // Try HTTP credentials…
			let credential = URLCredential(user: account,
										   password: password,
										   persistence: .forSession)
			completionHandler(.useCredential, credential)
            return
        }

        // HTTP credentials refused... delete them in Keychain
        KeychainUtilities.deletePassword(forService: service, account: account)

        // Remember failed HTTP authentication
        NetworkVars.didFailHTTPauthentication = true
        completionHandler(.performDefaultHandling, nil)
    }
}
