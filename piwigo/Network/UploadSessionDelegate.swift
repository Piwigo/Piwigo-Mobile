//
//  UploadSessionDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 29/07/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

@objc
class UploadSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
    
    @objc static var shared = UploadSessionDelegate()
    @objc var bckgSessionCompletionHandler: (() -> Void)?

    private let bckgIdentifier:String! = "org.piwigo.bckgSession"
    
    // Create single instance
    lazy var uploadSession: URLSession = {
//        let config = URLSessionConfiguration.background(withIdentifier: bckgIdentifier)
        let config = URLSessionConfiguration.default
        
        /// Background tasks can be scheduled at the discretion of the system for optimal performance
        config.isDiscretionary = false
        
        /// Indicates whether the app should be resumed or launched in the background when transfers finish
        config.sessionSendsLaunchEvents = false
        
        /// Indicates whether TCP connections should be kept open when the app moves to the background
        config.shouldUseExtendedBackgroundIdleMode = false

        /// Indicates whether the request is allowed to use the built-in cellular radios to satisfy the request.
        config.allowsCellularAccess = true
        
        /// How long a task should wait for additional data to arrive before giving up (60s by default)
        config.timeoutIntervalForRequest = 60
        
        /// Any upload task created by a background session is automatically retried if the original request fails due to a timeout.
        /// To configure how long an upload or download task should be allowed to be retried or transferred, use the timeoutIntervalForResource property.
        /// How long a task should wait for additional data to arrive before giving up (60s by default)
        config.timeoutIntervalForResource = 60
        
        /// Determines the maximum number of simultaneous connections made to the host by tasks (4 by default)
        config.httpMaximumConnectionsPerHost = 2
        
        /// Do not return a response from the cache
        config.requestCachePolicy = .reloadIgnoringCacheData
        config.urlCache = nil
        
        /// Allows a seamless handover from Wi-Fi to cellular
        if #available(iOS 11.0, *) {
            config.multipathServiceType = .handover
        } else {
            // Fallback on earlier versions
        }
        
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    let domain: String = {
        let strURL = "\(Model.sharedInstance().serverProtocol ?? "http://")\(Model.sharedInstance().serverName ?? "")"
        return URL(string: strURL)?.host ?? ""
    }()

    
    // MARK: - Session Delegate
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        print("    > The upload session has been invalidated")
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("    > Session-level authentication request from the remote server \(domain)")
        
        // Get protection space for current domain
        let protectionSpace = challenge.protectionSpace
        guard protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            protectionSpace.host.contains(domain) else {
                completionHandler(.performDefaultHandling, nil)
                return
        }

        
        // Get state of the server SSL transaction state
        guard let serverTrust = protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Check validity of certificate
        if checkValidity(of: serverTrust) {
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
        if certificateIsInKeychain(with: serverTrust) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            return
        }
        
        // Cancel the upload
        completionHandler(.cancelAuthenticationChallenge, nil)
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("    > Background session \(session) finished events.")
        
        // Execute completion handler
        if let bckgHandler = bckgSessionCompletionHandler {
            bckgHandler()
        }
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
        guard let credential = credentialsFromKeychain() else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        completionHandler(.useCredential, credential)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("    > Upload task finished transferring data")
        
        // What should we do with this error?
        guard let query = task.originalRequest?.url?.query else {
            assertionFailure("    > session \(session): task with no query!")
            return
        }

        // Task did complete without error?
        guard let error = error else {
            // Case of an upload
            if query.contains(kPiwigoImagesUpload) {
                // Case of an upload
                print("    > Upload task completed")
                return
            }
            
            assertionFailure("    > session \(session): Unknown task completed!!")
            return
        }
        
        // An error was encountered - Case of an upload
        if query.contains(kPiwigoImagesUpload) {
            print("    > session \(session): Upload task failed with error \(String(describing: error.localizedDescription))")
            return
        }
        assertionFailure("    > session \(session): Unknown task failed with error \(String(describing: error.localizedDescription))")
    }


    //MARK: - Session Data Delegate
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        print("    > Upload task has received some of the expected data")
        
        // What should we do with this data?
        guard let query = dataTask.originalRequest?.url?.query else {
            assertionFailure("    > session \(session): task with no query!")
            return
        }

        // Case of an upload
        if query.contains(kPiwigoImagesUpload) {
            UploadManager.shared.didCompleteUploadTask(dataTask, withData: data)
        }
    }


    // MARK: - Certificate Validation
    func checkValidity(of serverTrust: SecTrust) -> (Bool) {
        // Define policy for validating domain name
        let policy = SecPolicyCreateSSL(true, domain as CFString)
        let status = SecTrustSetPolicies(serverTrust, policy)
        if status != 0 { return false }     // Could not set policy
        
        // Evaluate certificate
        var isValid = false
        if #available(iOS 12.0, *) {
            isValid = SecTrustEvaluateWithError(serverTrust, nil)
        } else {
            // Fallback on earlier versions
            var result: SecTrustResultType = .invalid
            SecTrustEvaluate(serverTrust, &result)
            if status == errSecSuccess {
                isValid = (result == .unspecified) || (result == .proceed)
            }
        }
        
        return isValid
    }
    
    func certificateIsInKeychain(with serverTrust: SecTrust) -> (Bool) {
        // Retrieve the certificate of the server
        let certificate = SecTrustGetCertificateAtIndex(serverTrust, CFIndex(0))!

        // Get certificate in Keychain (should exist)
        // Certificates are stored in the Keychain with label "Piwigo:<host>"
        let query = [kSecClass as String       : kSecClassCertificate,
                     kSecAttrLabel as String   : "Piwigo:\(domain)",
                     kSecReturnRef as String   : kCFBooleanTrue!] as [String : Any]

        var dataTypeRef: AnyObject? = nil
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        var isInKeychain = false
        if status == errSecSuccess {
            // A certificate exists for that host, does it match the one of the server?
            let certData = SecCertificateCopyData(certificate)
            let storedData = SecCertificateCopyData(dataTypeRef as! SecCertificate)
            if certData == storedData {
                // Certificates are identical
                isInKeychain = true
            }
        }
        return isInKeychain
    }
    
    
    // MARK: - HTTP Credentials
    func credentialsFromKeychain() -> URLCredential? {
        // Return credentials retrieved from the keychain
        guard let username = Model.sharedInstance().httpUsername, !username.isEmpty,
            let password = SAMKeychain.password(forService:  "\(Model.sharedInstance().serverProtocol ?? "https://")\(Model.sharedInstance().serverName ?? "")", account: username), !password.isEmpty else {
                return nil
        }
        return URLCredential(user: username, password: password,
                             persistence: .forSession)
    }
}
