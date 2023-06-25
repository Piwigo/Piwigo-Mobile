//
//  UploadSessions.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 22/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

struct UploadCounter {
    var uid: String
    var bytesSent: Int64
    var totalBytes: Int64
    var progress: Float {
        get {
            return Float(bytesSent) / Float(totalBytes)
        }
    }
    
    init(identifier: String) {
        self.uid = identifier
        self.bytesSent = Int64.zero
        self.totalBytes = Int64.zero
    }
}

extension UploadCounter: Hashable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.uid == rhs.uid
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
    }
}

public let pwgHTTPuploadID = "X-PWG-UploadID"
public let pwgHTTPimageID  = "X-PWG-localIdentifier"
public let pwgHTTPchunk    = "X-PWG-chunk"
public let pwgHTTPchunks   = "X-PWG-chunks"
public let pwgHTTPmd5sum   = "X-PWG-md5sum"


public class UploadSessions: NSObject {
                
    // Singleton
    public static let shared = UploadSessions()

    // Session identifiers / descriptions
    public let uploadSessionIdentifier:String! = "org.piwigo.uploadSession"
    public let uploadBckgSessionIdentifier:String! = "org.piwigo.uploadBckgSession"

    // Foreground upload session
    public lazy var frgdSession: URLSession = {
        let config = URLSessionConfiguration.default
        
        /// The foreground session should wait for connectivity to become available (can be retried)
        /// only when the app uses the pwg.images.uploadAsync method.
//        config.waitsForConnectivity = NetworkVars.usesUploadAsync
        
        /// Connections should not use the network when the user has specified Low Data Mode
//        if #available(iOS 13.0, *) {
//            config.allowsConstrainedNetworkAccess = false
//        }

        /// Indicates whether the request is allowed to use the built-in cellular radios to satisfy the request.
        config.allowsCellularAccess = !(UploadVars.wifiOnlyUploading)
        
        /// How long a task should wait for additional data to arrive before giving up (1 minute)
        config.timeoutIntervalForRequest = 60
        
        /// How long an upload task should be allowed to be retried or transferred (5 minutes).
        config.timeoutIntervalForResource = 300
        
        /// Determines the maximum number of simultaneous connections made to the host by tasks (4 by default)
        config.httpMaximumConnectionsPerHost = 4
        
        /// Do not return a response from the cache
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        /// Do not send upload requests with cookie so that each upload session remains ephemeral.
        /// The user session, if it exists, remains untouched and kept alive until it expires.
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .onlyFromMainDocumentDomain
        
        /// Allows a seamless handover from Wi-Fi to cellular
        config.multipathServiceType = .handover
        
        /// Create the background session and set its description
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        session.sessionDescription = "Upload Session (frgd)"
        
        return session
    }()

    // Background upload session
    public lazy var bckgSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: uploadBckgSessionIdentifier)
        
        /// Background tasks can be scheduled at the discretion of the system for optimal performance
        config.isDiscretionary = false

        /// Indicates whether the app should be resumed or launched in the background when transfers finish
        config.sessionSendsLaunchEvents = true
        
        /// Indicates whether TCP connections should be kept open when the app moves to the background
        config.shouldUseExtendedBackgroundIdleMode = true

        /// Indicates whether the request is allowed to use the built-in cellular radios to satisfy the request.
        config.allowsCellularAccess = !(UploadVars.wifiOnlyUploading)
        
        /// How long a task should wait for additional data to arrive before giving up (1 day)
        config.timeoutIntervalForRequest = 1 * 24 * 60 * 60
        
        /// How long an upload task should be allowed to be retried or transferred (7 days).
        config.timeoutIntervalForResource = 7 * 24 * 60 * 60
        
        /// Determines the maximum number of simultaneous connections made to the host by tasks (4 by default)
        config.httpMaximumConnectionsPerHost = 4
        
        /// Do not return a response from the cache
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        /// The user session, if it exists, should remain untouched so  we do not update the Piwigo cookie.
        /// We send a custom cookie to avoid a reject by ModSecurity if it is set to reject requests not containing cookies.
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        if let validUrl = URL(string: NetworkVars.service) {
            var params: [HTTPCookiePropertyKey : Any] = [
                HTTPCookiePropertyKey.version           : NSString("0"),
                HTTPCookiePropertyKey.name              : NSString("pwg_method"),
                HTTPCookiePropertyKey.value             : NSString("uploadAsync"),
                HTTPCookiePropertyKey.domain            : NSString(string: validUrl.host ?? ""),
                HTTPCookiePropertyKey.path              : NSString(string: validUrl.path),
                HTTPCookiePropertyKey.expires           : NSDate(),
                HTTPCookiePropertyKey.discard           : NSString("TRUE")
            ]
            if NetworkVars.serverProtocol == "https" {
                params[HTTPCookiePropertyKey.secure] = "TRUE"
            }
            if let cookie = HTTPCookie(properties: params) {
                config.httpAdditionalHeaders = HTTPCookie.requestHeaderFields(with: [cookie])
            }
        }

        /// Allows a seamless handover from Wi-Fi to cellular
        config.multipathServiceType = .handover
        
        /// The identifier for the shared container into which files in background URL sessions should be downloaded.
        config.sharedContainerIdentifier = UserDefaults.appGroup
        
        /// Create the background session and set its description
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        session.sessionDescription = "Upload Session (bckg)"
        
        return session
    }()

    // Constants and variables
    public var uploadSessionCompletionHandler: (() -> Void)?

    
    // MARK: - Counters for Updating Progress Bars
    // Stores upload data as (localIdentifier, bytesSent, totalBytes)
    lazy var uploadCounters = [UploadCounter]()

    func initCounter(withID identifier: String) {
        if let index = uploadCounters.firstIndex(where: {$0.uid == identifier}) {
            uploadCounters[index].bytesSent = Int64.zero
        }
        else {
            let newCounter = UploadCounter(identifier: identifier)
            uploadCounters.append(newCounter)
        }
    }
    
    func addBytes(_ bytes: Int64, toCounterWithID identifier: String) {
        guard let index = uploadCounters.firstIndex(where: {$0.uid == identifier}) else {
            return
        }
        uploadCounters[index].totalBytes += bytes
    }

    func removeCounter(withID localIdentifier: String) {
        uploadCounters.removeAll(where: {$0.uid == localIdentifier})
    }
    

    // MARK: - Cancel Tasks Related to a Specific Upload Request
    /// This method cancels the remaining tasks when the upload is completed.
    func cancelTasksOfUpload(withID uploadIDStr:String, exceptedTaskID: Int) -> Void {
        // Loop over all tasks
        bckgSession.getAllTasks { uploadTasks in
            // Select remaining tasks related with this request if any
            let tasksToCancel = uploadTasks.filter({ $0.originalRequest?
                .value(forHTTPHeaderField: pwgHTTPuploadID) == uploadIDStr })
                .filter({ $0.taskIdentifier != exceptedTaskID})
            // Cancel remaining tasks related with this completed upload request
            tasksToCancel.forEach({
                print("\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)) > Cancel upload task \($0.taskIdentifier)")
                $0.cancel()
            })
        }
    }
    
    /// This method cancels the tasks of chunks which are already uploaded.
//    func cancelTasksOfUpload(witID uploadIDStr:String, alreadyUploadedChunks: [String],
//                             exceptedTaskID: Int) -> Void {
//        // Loop over all tasks
//        bckgSession.getAllTasks { uploadTasks in
//            // Select remaining tasks of chunks already uploaded
//            if uploadTasks.count == 0 { return }
//
//            let tasksToCancel = uploadTasks.filter({ $0.originalRequest?.value(forHTTPHeaderField: UploadVars.HTTPuploadID) == uploadIDStr})
//            if tasksToCancel.count > 0 {
//                let firstTask = tasksToCancel.first
//                let chunk = firstTask?.originalRequest?.value(forHTTPHeaderField: UploadVars.HTTPchunk) ?? ""
//                debugPrint("••> \(chunk) compared to \(alreadyUploadedChunks)?")
//            }
//            let tasksToCancel = uploadTasks.filter({ $0.originalRequest?.value(forHTTPHeaderField: UploadVars.HTTPuploadID) == uploadIDStr})
//                .filter({ alreadyUploadedChunks.contains($0.originalRequest?.value(forHTTPHeaderField: UploadVars.HTTPchunk) ?? "")})
//            // Cancel queued tasks which are useless
//            tasksToCancel.forEach({
//                print("\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)) > Cancel upload task \($0.taskIdentifier)")
//                $0.cancel()
//            })
//        }
//    }
}


// MARK: - Session Delegate
extension UploadSessions: URLSessionDelegate {

//    public func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
//        print("••> The upload session is waiting for connectivity (offline mode)")
//    }
        
//    public func urlSession(_ session: URLSession, task: URLSessionTask, willBeginDelayedRequest: URLRequest, completionHandler: (URLSession.DelayedRequestDisposition, URLRequest?) -> Void) {
//        print("••> The upload session will begin delayed request (back to online)")
//    }

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        print("••> The upload session has been invalidated")
    }
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("    > Session-level authentication request from the remote server.")
        
        // Get protection space for current domain
        let protectionSpace = challenge.protectionSpace
        guard protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              protectionSpace.host.contains(NetworkVars.domain()) else {
                completionHandler(.rejectProtectionSpace, nil)
                return
        }

        // Get state of the server SSL transaction state
        guard let serverTrust = protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Check validity of certificate
        if KeychainUtilities.isSSLtransactionValid(inState: serverTrust,
                                                   for: NetworkVars.domain()) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            return
        }
        
        // If there is no certificate, reject server (should rarely happen)
        if SecTrustGetCertificateCount(serverTrust) == 0 {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Retrieve the certificate of the server
        guard let certificate = SecTrustGetCertificateAtIndex(serverTrust, CFIndex(0)) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Check if the certificate is trusted by user (i.e. is in the Keychain)
        // Case where the certificate is e.g. self-signed
        if KeychainUtilities.isCertKnownForSSLtransaction(certificate, for: NetworkVars.domain()) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            return
        }
        
        // Could not validate the certificate
        completionHandler(.performDefaultHandling, nil)
    }
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("••> Background session \(session.configuration.identifier ?? "") finished events.")
        
        // Execute completion handler, i.e. inform iOS that we collect data returned by Piwigo server
        DispatchQueue.main.async {
            if let bckgHandler = self.uploadSessionCompletionHandler {
                bckgHandler()
            }
        }
    }
}


// MARK: - Session Task Delegate
extension UploadSessions: URLSessionTaskDelegate {
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("••> Task-level authentication request from the remote server")

        // Check authentication method
        let authMethod = challenge.protectionSpace.authenticationMethod
        guard authMethod == NSURLAuthenticationMethodHTTPBasic,
            authMethod == NSURLAuthenticationMethodHTTPDigest else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Get HTTP basic authentification credentials
        let account = NetworkVars.httpUsername
        let password = KeychainUtilities.password(forService: NetworkVars.service, account: account)
        if password.isEmpty {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        let credential = URLCredential(user: account,
                                       password: password,
                                       persistence: .forSession)
        completionHandler(.useCredential, credential)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {

        // Get upload info from the task
        // The size of the uploaded image is set in the Content-Length field.
        guard let identifier = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPimageID) else {
                print("••> Could not extract HTTP header fields !!!!!!")
                return
        }
        
        // Update counter
        guard let index = uploadCounters.firstIndex(where: { $0.uid == identifier}) else { return }
        print("••> task \(task.taskIdentifier) did send \(totalBytesSent) bytes (\(totalBytesExpectedToSend) bytes expected)")
        uploadCounters[index].bytesSent += bytesSent
        print("••> counter: \(uploadCounters[index].bytesSent) bytes sent, \(uploadCounters[index].totalBytes) bytes expected —> \(uploadCounters[index].progress * 100)%")
        let uploadInfo: [String : Any] = ["localIdentifier" : identifier,
                                          "progressFraction" : uploadCounters[index].progress]
        DispatchQueue.main.async {
            // Update UploadQueue cell and button shown in root album (or default album)
            NotificationCenter.default.post(name: .pwgUploadProgress, object: nil, userInfo: uploadInfo)
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        // Get upload info from task
        guard let md5sum = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPmd5sum),
            let chunk = Int((task.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunk))!),
            let chunks = Int((task.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunks))!) else {
                print("••> Could not extract HTTP header fields !!!!!!")
                return
        }

        // Task did complete without error?
        if let error = error {
            print("••> Upload task \(task.taskIdentifier) of chunk \(chunk+1)/\(chunks) failed with error \(String(describing: error.localizedDescription)) [\(md5sum)]")
        } else {
            print("••> Upload task \(task.taskIdentifier) of chunk \(chunk+1)/\(chunks) finished transferring data at \(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)) [\(md5sum)]")
        }

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
        switch task.taskDescription {
        case uploadSessionIdentifier:
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.didCompleteUploadTask(task, withError: error)
            }
        case uploadBckgSessionIdentifier:
            if UploadManager.shared.isExecutingBackgroundUploadTask {
                UploadManager.shared.didCompleteBckgUploadTask(task, withError: error)
            } else {
                UploadManager.shared.backgroundQueue.async {
                    UploadManager.shared.didCompleteBckgUploadTask(task, withError: error)
                }
            }
        default:
            print("!!! unexpected session identifier !!!")
        }
    }
}


// MARK: - Session Data Delegate
extension UploadSessions: URLSessionDataDelegate {
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // Get upload info from task
        guard let md5sum = dataTask.originalRequest?.value(forHTTPHeaderField: pwgHTTPmd5sum),
            let chunk = Int((dataTask.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunk))!),
            let chunks = Int((dataTask.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunks))!) else {
                print("••> Could not extract HTTP header fields !!!!!!")
                return
        }
        print("••> Upload task \(dataTask.taskIdentifier) of chunk \(chunk+1)/\(chunks) did receive some data at \(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)) [\(md5sum)]")
        
        #if DEBUG
        let dataStr = String(decoding: data, as: UTF8.self)
        print("••> JSON: \(dataStr)")
        #endif
        
        switch dataTask.taskDescription {
        case uploadSessionIdentifier:
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.didCompleteUploadTask(dataTask, withData: data)
            }
        case uploadBckgSessionIdentifier:
            fallthrough
        default:
            if UploadManager.shared.isExecutingBackgroundUploadTask {
                UploadManager.shared.didCompleteBckgUploadTask(dataTask, withData: data)
            } else {
                UploadManager.shared.backgroundQueue.async {
                    UploadManager.shared.didCompleteBckgUploadTask(dataTask, withData: data)
                }
            }
        }
    }
}
