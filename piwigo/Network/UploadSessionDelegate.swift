//
//  UploadSessionDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 29/07/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

class UploadSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
    
    // Singleton
    @objc static var shared = UploadSessionDelegate()
    
    // Constants and variables
    @objc let uploadSessionIdentifier:String! = "org.piwigo.uploadBckgSession"
    @objc var uploadSessionCompletionHandler: (() -> Void)?
            
    // Create single instance
    lazy var uploadSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: uploadSessionIdentifier)
        
        /// Background tasks can be scheduled at the discretion of the system for optimal performance
        config.isDiscretionary = false

        /// Indicates whether the app should be resumed or launched in the background when transfers finish
        config.sessionSendsLaunchEvents = true
        
        /// Indicates whether TCP connections should be kept open when the app moves to the background
        config.shouldUseExtendedBackgroundIdleMode = true

        /// Indicates whether the request is allowed to use the built-in cellular radios to satisfy the request.
        config.allowsCellularAccess = !(UploadVars.shared.wifiOnlyUploading)
        
        /// How long a task should wait for additional data to arrive before giving up (1 day)
        config.timeoutIntervalForRequest = 1 * 24 * 60 * 60
        
        /// How long an upload task should be allowed to be retried or transferred (7 days).
        config.timeoutIntervalForResource = 7 * 24 * 60 * 60
        
        /// Determines the maximum number of simultaneous connections made to the host by tasks (4 by default)
        config.httpMaximumConnectionsPerHost = 4
        
        /// Do not return a response from the cache
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        /// Do not send upload requests with cookie so that each upload session remains ephemeral.
        /// The user session, if it exists, remains untouched and kept alive until it expires.
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        
        /// Allows a seamless handover from Wi-Fi to cellular
        if #available(iOS 11.0, *) {
            config.multipathServiceType = .handover
        }
        
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    let domain: String = {
        let strURL = NetworkHandler.getURLWithPath("", withURLParams: nil)!
        return URL(string: strURL)?.host ?? ""
    }()

    
    // MARK: - Byte Counters
    // Counters for updating the progress bars of the UI
    // are set with: (localIdentifier, bytesSent, fileSize)
    lazy var bytesSentToPiwigoServer: [(String, Float, Float)] = []

    func clearCounter(withID localIdentifier: String) {
        if let indexOfUpload = bytesSentToPiwigoServer.firstIndex(where: { $0.0 == localIdentifier}) {
            bytesSentToPiwigoServer[indexOfUpload].1 = 0.0
        }
    }

    func removeCounter(withID localIdentifier: String) {
        if let indexOfUpload = bytesSentToPiwigoServer.firstIndex(where: { $0.0 == localIdentifier}) {
            bytesSentToPiwigoServer.remove(at: indexOfUpload)
        }
    }
    
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
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("    > Background session \(session.configuration.identifier ?? "") finished events.")
        
        // Execute completion handler, i.e. inform iOS that we collect data returned by Piwigo server
        DispatchQueue.main.async {
            if let bckgHandler = self.uploadSessionCompletionHandler {
                bckgHandler()
            }
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
        guard let credential = KeychainUtilities.HTTPcredentialFromKeychain() else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        completionHandler(.useCredential, credential)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {

        // Get upload info from the task
        // The size of the uploaded image is set in the Content-Length field.
        guard let identifier = task.originalRequest?.value(forHTTPHeaderField: "identifier"),
              let fileSizeStr = task.originalRequest?.value(forHTTPHeaderField: "fileSize"),
              let fileSize = Float(fileSizeStr)
               else {
                print("   > Could not extract HTTP header fields !!!!!!")
                return
        }
        
        // Update counter
        let progressFraction: Float
        if let indexOfUpload = bytesSentToPiwigoServer.firstIndex(where: { $0.0 == identifier}) {
            // Update counter
            bytesSentToPiwigoServer[indexOfUpload].1 += Float(bytesSent)
            progressFraction = bytesSentToPiwigoServer[indexOfUpload].1 / bytesSentToPiwigoServer[indexOfUpload].2
//            print("    > Upload task \(task.taskIdentifier), progressFraction = \(bytesSentToPiwigoServer[indexOfUpload].1) / \(bytesSentToPiwigoServer[indexOfUpload].2) i.e. \(progressFraction)")
        } else {
            // Add counter for this image
            bytesSentToPiwigoServer.append((identifier, Float(bytesSent), fileSize))
            progressFraction = Float(bytesSent) / fileSize
//            print("    > Upload task \(task.taskIdentifier), progressFraction = \(bytesSent) / \(fileSize) i.e. \(progressFraction)")
        }
        
        // Update UI
        let uploadInfo: [String : Any] = ["localIdentifier" : identifier,
                                          "stateLabel" : kPiwigoUploadState.uploading.stateInfo,
                                          "progressFraction" : progressFraction]
        DispatchQueue.main.async {
            // Update UploadQueue cell and button shown in root album (or default album)
            let name = NSNotification.Name(rawValue: kPiwigoNotificationUploadProgress)
            NotificationCenter.default.post(name: name, object: nil, userInfo: uploadInfo)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        // Get upload info from task
//        guard let md5sum = task.originalRequest?.value(forHTTPHeaderField: "md5sum"),
//            let chunk = Int((task.originalRequest?.value(forHTTPHeaderField: "chunk"))!),
//            let chunks = Int((task.originalRequest?.value(forHTTPHeaderField: "chunks"))!) else {
//                print("   > Could not extract HTTP header fields !!!!!!")
//                return
//        }

        // Task did complete without error?
//        if let error = error {
//            print("    > Upload task \(task.taskIdentifier) of chunk \(chunk)/\(chunks) failed with error \(String(describing: error.localizedDescription)) [\(md5sum)]")
//        } else {
//            print("    > Upload task \(task.taskIdentifier) of chunk \(chunk)/\(chunks) finished transferring data at \(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)) [\(md5sum)]")
//        }

        // The below code updates the stored cookie with the pwg_id returned by the server.
        // This allows to check that the upload session was well closed by the server.
        // For example by requesting image properties or an image deletion.
//        print("\(task.response.debugDescription)")
//        if let requestURL = task.originalRequest?.url,
//           let cookies = HTTPCookieStorage.shared.cookies(for: requestURL), cookies.count > 0,
//           var properties = cookies[0].properties {
//            let oldPwgID = cookies[0].value
//            print("oldPwgID => \(oldPwgID)")
//
//            if let response = task.response as? HTTPURLResponse,
//               let setCookie = response.allHeaderFields["Set-Cookie"] as? String {
//                let strPart2 = setCookie.components(separatedBy: "pwg_id=")
//                if strPart2.count > 1 {
//                    let newPwgID = strPart2[1].components(separatedBy: " ")[0].drop(while: {$0 == ";"})
//                    properties.updateValue(newPwgID, forKey: .value)
//                    if let cookie = HTTPCookie(properties: properties) {
//                        print("newPwgID => \(newPwgID)")
//                        HTTPCookieStorage.shared.setCookie(cookie)
//                    }
//                }
//            }
//        }

        // Handle the response with the Upload Manager
        if UploadManager.shared.isExecutingBackgroundUploadTask {
            UploadManager.shared.didCompleteUploadTask(task, withError: error)
        } else {
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.didCompleteUploadTask(task, withError: error)
            }
        }
    }

    //MARK: - Session Data Delegate
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // Get upload info from task
//        guard let md5sum = dataTask.originalRequest?.value(forHTTPHeaderField: "md5sum"),
//            let chunk = Int((dataTask.originalRequest?.value(forHTTPHeaderField: "chunk"))!),
//            let chunks = Int((dataTask.originalRequest?.value(forHTTPHeaderField: "chunks"))!) else {
//                print("   > Could not extract HTTP header fields !!!!!!")
//                return
//        }
//        print("    > Upload task \(dataTask.taskIdentifier) of chunk \(chunk)/\(chunks) did receive some data at \(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)) [\(md5sum)]")
        if UploadManager.shared.isExecutingBackgroundUploadTask {
            UploadManager.shared.didCompleteUploadTask(dataTask, withData: data)
        } else {
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.didCompleteUploadTask(dataTask, withData: data)
            }
        }
    }
    
    
    // MARK: - Cancel Tasks Related to a Specific Upload Request
    func cancelTasks(taskDescription: String, exceptedTaskIdentifier: Int) -> Void {
        // Loop over all tasks
        uploadSession.getAllTasks { uploadTasks in
            // Select remaining tasks related with this request if any
            let tasksToCancel = uploadTasks.filter({ $0.taskDescription == taskDescription })
                                           .filter({ $0.taskIdentifier != exceptedTaskIdentifier})
            // Cancel remaining tasks related with this completed upload request
            tasksToCancel.forEach({
                print("\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)) > Cancel upload task \($0.taskIdentifier)")
                $0.cancel()
            })
        }
    }
}
