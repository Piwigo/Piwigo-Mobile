//
//  JSONsessionDelegate.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 08/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

class JSONsessionDelegate: NSObject, URLSessionDelegate {
    
    // Singleton
    @objc static var shared = JSONsessionDelegate()
    
    // Create single instance
    lazy var dataSession: URLSession = {
        let config = URLSessionConfiguration.default

        // Additional headers that are added to all tasks
        config.httpAdditionalHeaders = ["Accept"         : "application/json",
                                        "Content-Type"   : "application/json",
                                        "Accept-Charset" : "utf-8"]

        /// Network service type for data that the user is actively waiting for.
        config.networkServiceType = .responsiveData
        
        /// Indicates that the request is allowed to use the built-in cellular radios to satisfy the request.
        config.allowsCellularAccess = true

        /// How long a task should wait for additional data to arrive before giving up (10 seconds)
        config.timeoutIntervalForRequest = 10
        
        /// How long a task should be allowed to be retried or transferred (10 seconds).
        config.timeoutIntervalForResource = 10
        
        /// Determines the maximum number of simultaneous connections made to the host by tasks (4 by default)
        config.httpMaximumConnectionsPerHost = 4
        
        /// Allows a seamless handover from Wi-Fi to cellular
        if #available(iOS 11.0, *) {
            config.multipathServiceType = .handover
        }
        
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    let domain: String = {
        let strURL = "\(NetworkVars.shared.serverProtocol)\(NetworkVars.shared.serverPath)"
        return URL(string: strURL)?.host ?? ""
    }()


    // MARK: - Session Methods
    func postRequest(withMethod method: String, parameters jsonDict: [String:Any],
                     completionHandler: @escaping (Data, Error?) -> Void) {
        // Prepare Piwigo JSON request
        let urlStr = "\(NetworkVars.shared.serverProtocol)\(NetworkVars.shared.serverPath)"
        let url = URL(string: urlStr + "/ws.php?\(method)")
        var request = URLRequest(url: url!)
        request.httpMethod = "post"

        // Add parameters
        let jsonParameters = try! JSONSerialization.data(withJSONObject: jsonDict, options: [])
        request.httpBody = jsonParameters

        // Launch the HTTP(S) request
        dataSession.dataTask(with: request) { data, response, error in
            // Transaction completed?
            guard let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode) else {
                // Transaction error
                guard let error = error else {
                    // No communication error returned,
                    // so Piwigo returned an error to be handled by the caller.
                    if let jsonData = data, !jsonData.isEmpty {
                        let filteredData = self.filterPiwigo(data: jsonData)
                        completionHandler(filteredData, nil)
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
            
            // Return Piwigo error if no data returned.
            guard let jsonData = data, !jsonData.isEmpty else {
                let error = NSError(domain: "Piwigo", code: JsonError.emptyJSONobject.hashValue, userInfo: [NSLocalizedDescriptionKey : JsonError.emptyJSONobject.localizedDescription])
                completionHandler(Data(), error)
                return
            }

            // Check returned data
            let filteredData = self.filterPiwigo(data: jsonData)
            guard let _ = try? JSONSerialization.jsonObject(with: filteredData, options: []) as? [String: AnyObject] else {
                // Update upload request status
                let error = NSError(domain: "Piwigo", code: JsonError.invalidJSONobject.hashValue, userInfo: [NSLocalizedDescriptionKey : JsonError.invalidJSONobject.localizedDescription])
                completionHandler(Data(), error)
                return
            }

            // The caller will decode the returned data
            completionHandler(filteredData, nil)
        }
        .resume()
    }
    
    private func filterPiwigo(data:Data) -> Data {
        // Filter returned data (PHP may send a warning before the JSON object)
        let dataStr = String(decoding: data, as: UTF8.self)
        var filteredData = data
        // Let's first assume we got JSON data
        if let jsonPos = dataStr.range(of: "{\"stat\":")?.lowerBound {
            filteredData  = dataStr[jsonPos...].data(using: String.Encoding.utf8)!
            return filteredData
        }
        
        // Did we receive XML data ("format=json" forgotten in call)
        /// for example:
        /// <?xml version=\"1.0\"?>
        ///     <rsp stat=\"fail\">
        ///         <err code=\"501\" msg=\"Missing &quot;method&quot; name\" />
        ///         </rsp>"
        let parser = ParseXMLData(xml: dataStr)
        let jsonStr = parser.parseXML()
        // Remove rsp container
        if let jsonPos = jsonStr.range(of: "{\"stat\":")?.lowerBound {
            filteredData  = jsonStr[jsonPos...].dropLast()
                .data(using: String.Encoding.utf8)!
            return filteredData
        }
        return data
    }


    // MARK: - Session Delegate
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        print("    > The data session has been invalidated")
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("    > Session-level authentication request from the remote server \(domain)")
        
        // Get protection space for current domain
        let protectionSpace = challenge.protectionSpace
        guard protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            protectionSpace.host.contains(domain) else {
                completionHandler(.rejectProtectionSpace, nil)
                return
        }

        // Get state of the server SSL transaction state
        guard let serverTrust = protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Check validity of certificate
        if KeychainUtilities.isSSLtransactionValid(inState: serverTrust, for: domain) {
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
        if KeychainUtilities.isCertKnownForSSLtransaction(inState: serverTrust, for: domain) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            return
        }
        
        // Cancel the upload
        completionHandler(.cancelAuthenticationChallenge, nil)
    }


    // MARK: - Session Task Delegate
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("    > Task-level authentication request from the remote server")

        // Check authentication method
        let authMethod = challenge.protectionSpace.authenticationMethod
        guard authMethod == NSURLAuthenticationMethodHTTPBasic,
            authMethod == NSURLAuthenticationMethodHTTPDigest else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Get HTTP basic authentification credentials
        guard let credential = KeychainUtilities.HTTPcredentialFromKeychain() else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        completionHandler(.useCredential, credential)
    }
}
