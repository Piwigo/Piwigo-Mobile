//
//  UploadSessionsDelegate.swift
//  uploadKit
//
//  Created by Eddy Lelièvre-Berna on 21/12/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import os
import Foundation
import piwigoKit

public final class UploadSessionsDelegate: NSObject, Sendable {
    
    // Logs networking activities
    /// sudo log collect --device --start '2025-01-11 15:00:00' --output piwigo.logarchive
    static let logger = Logger(subsystem: "org.piwigo.uploadKit", category: String(describing: UploadSessionsDelegate.self))

    // Singleton
    public static let shared = UploadSessionsDelegate()
    
    // Use actor for thread-safe counter management
    private let counterManager = UploadCounterManager()


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
            tasksToCancel.forEach { task in
                UploadSessionsDelegate.logger.notice("Task \(task.taskIdentifier, privacy: .public) cancelled.")
                // Remember that this task was cancelled
                task.taskDescription = uploadBckgSessionIdentifier + " " + pwgHTTPCancelled
                task.cancel()
            }
        }
    }
}


// MARK: - Session Delegate
extension UploadSessionsDelegate: URLSessionDelegate {

//    public func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
//        UploadSessions.logger.notice("Session waiting for connectivity (offline mode).")
//    }
        
//    public func urlSession(_ session: URLSession, task: URLSessionTask, willBeginDelayedRequest: URLRequest, completionHandler: (URLSession.DelayedRequestDisposition, URLRequest?) -> Void) {
//        UploadSessions.logger.notice("Session will begin delayed request (back to online).")
//    }

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        UploadSessionsDelegate.logger.notice("Session invalidated.")
    }
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        UploadSessionsDelegate.logger.notice("Session-level authentication requested by server.")
        
        // Get protection space for current domain
        let protectionSpace = challenge.protectionSpace
        guard protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              protectionSpace.host.contains(NetworkVars.shared.domain()) else {
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
                                                   for: NetworkVars.shared.domain()) {
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
        guard let certificates = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              let certificate = certificates.first
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Check if the certificate is trusted by user (i.e. is in the Keychain)
        // Case where the certificate is e.g. self-signed
        if KeychainUtilities.isCertKnownForSSLtransaction(certificate, for: NetworkVars.shared.domain()) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            return
        }
        
        // Could not validate the certificate
        completionHandler(.performDefaultHandling, nil)
    }
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        UploadSessionsDelegate.logger.notice("Session \(session.configuration.identifier ?? "", privacy: .public) finished events.")
        
        // Execute completion handler, i.e. inform iOS that we collect data returned by Piwigo server
        DispatchQueue.main.async {
            if let bckgHandler = uploadSessionCompletionHandler {
                bckgHandler()
            }
        }
    }
}


// MARK: - Session Task Delegate
extension UploadSessionsDelegate: URLSessionTaskDelegate {
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        UploadSessionsDelegate.logger.notice("Task-level authentication requested by server.")

        // Check authentication method
        let authMethod = challenge.protectionSpace.authenticationMethod
        guard authMethod == NSURLAuthenticationMethodHTTPBasic,
              authMethod == NSURLAuthenticationMethodHTTPDigest else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Get HTTP basic authentification credentials
        let account = NetworkVars.shared.httpUsername
        let password = KeychainUtilities.password(forService: NetworkVars.shared.service, account: account)
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
        guard let identifier = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPimageID),
              let chunk = Int((task.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunk))!)
        else {
            UploadSessionsDelegate.logger.notice("Could not extract HTTP header fields.")
            preconditionFailure("Could not extract HTTP header fields.")
        }

        // Update counter
        Task {
            // Add chunk to counter if needed (e.g. situation where the app is relauched)
            await addChunk(chunk, toCounterWithID: identifier)
            
            // Update UploadQueue cell and button shown in root album (or default album)
            await addBytes(bytesSent, toCounterWithID: identifier)
            
            // Update progress bar
            let progress = await getProgress(forCounterWithID: identifier)
            DispatchQueue.main.async {
                let uploadInfo: [String : Any] = ["localIdentifier" : identifier,
                                                  "progressFraction" : progress]
                NotificationCenter.default.post(name: .pwgUploadProgress, object: nil, userInfo: uploadInfo)
            }

            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = NumberFormatter.Style.none
            numberFormatter.usesGroupingSeparator = true
            let bytes = numberFormatter.string(from: NSNumber(value: bytesSent)) ?? ""
            numberFormatter.numberStyle = NumberFormatter.Style.decimal
            numberFormatter.roundingMode = .ceiling
            numberFormatter.roundingIncrement = NSNumber(value: 0.01)
            let progressPercent = numberFormatter.string(from: NSNumber(value: progress * 100)) ?? ""
            UploadSessionsDelegate.logger.notice("Task \(task.taskIdentifier, privacy: .public) did send \(bytes, privacy: .public) bytes | counter: \(progressPercent, privacy: .public) %")
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        // Get upload info from the task
        guard let identifier = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPimageID),
              let chunk = Int((task.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunk))!),
              let chunks = Int((task.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunks))!),
              let taskDescription = task.taskDescription
        else {
            UploadSessionsDelegate.logger.notice("Could not extract HTTP header fields.")
            preconditionFailure("Could not extract HTTP header fields.")
        }

        // Add chunk to counter if needed (e.g. situation where the app is relauched)
        Task {
            await addChunk(chunk, toCounterWithID: identifier)
        }

        // The below code updates the stored cookie with the pwg_id returned by the server.
        // This allows to check that the upload session was well closed by the server.
        // For example by requesting image properties or an image deletion.
//        debugPrint("\(task.response.debugDescription)")
//        if let requestURL = task.originalRequest?.url,
//           let cookies = HTTPCookieStorage.shared.cookies(for: requestURL), cookies.count > 0,
//           var properties = cookies[0].properties {
//            let oldPwgID = cookies[0].value
//            debugPrint("oldPwgID => \(oldPwgID)")
//
//            if let response = task.response as? HTTPURLResponse,
//               let setCookie = response.allHeaderFields["Set-Cookie"] as? String {
//                let strPart2 = setCookie.components(separatedBy: "pwg_id=")
//                if strPart2.count > 1 {
//                    let newPwgID = strPart2[1].components(separatedBy: " ")[0].drop(while: {$0 == ";"})
//                    properties.updateValue(newPwgID, forKey: .value)
//                    if let cookie = HTTPCookie(properties: properties) {
//                        debugPrint("newPwgID => \(newPwgID)")
//                        HTTPCookieStorage.shared.setCookie(cookie)
//                    }
//                }
//            }
//        }

        // Manage the error type
        var pwgError: PwgKitError?
        if let error = error as? URLError {
            pwgError = .requestFailed(innerError: error)
        }
        else if let error = error as? DecodingError {
            pwgError = .decodingFailed(innerError: error)
        }
        else if let response = task.response as? HTTPURLResponse,
                  (200...299).contains(response.statusCode) == false {
            pwgError = .invalidStatusCode(statusCode: response.statusCode)
        }
        else if let error = error {
            pwgError = .otherError(innerError: error)
        }
        
        // Log task completion
        if let pwgError, taskDescription.contains(pwgHTTPCancelled) == false {
            UploadSessionsDelegate.logger.notice("Task \(task.taskIdentifier, privacy: .public) of chunk \(chunk+1, privacy: .public)/\(chunks, privacy: .public) failed with error \(String(describing: pwgError.localizedDescription), privacy: .public).")
        } else {
            UploadSessionsDelegate.logger.notice("Task \(task.taskIdentifier, privacy: .public) of chunk \(chunk+1, privacy: .public)/\(chunks, privacy: .public) completed.")
        }
        
        // Handle the response with the Upload Manager
        let sessionIdentifier = (task.taskDescription ?? "").components(separatedBy: " ").first
        switch sessionIdentifier {
        case uploadSessionIdentifier:
            Task { @UploadManagement in
                UploadManager.shared.didCompleteUploadTask(task, withError: pwgError)
            }
        case uploadBckgSessionIdentifier:
            Task { @UploadManagement in
                UploadManager.shared.didCompleteBckgUploadTask(task, withError: pwgError)
            }
        default:
            UploadSessionsDelegate.logger.notice("Unexpected session identifier.")
            preconditionFailure("Unexpected session identifier.")
        }
    }
}


// MARK: - Session Data Delegate
extension UploadSessionsDelegate: URLSessionDataDelegate {
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data)
    {
        // Get upload info from task
        if let chunk = Int((dataTask.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunk))!),
           let chunks = Int((dataTask.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunks))!) {
            #if DEBUG
            let dataStr = String(decoding: data, as: UTF8.self)
            UploadSessionsDelegate.logger.notice("Task \(dataTask.taskIdentifier, privacy: .public) of chunk \(chunk+1, privacy: .public)/\(chunks, privacy: .public) did receive: \(dataStr, privacy: .public).")
            #else
            let countsOfBytes = data.count * MemoryLayout<Data>.stride
            UploadSessions.logger.notice("Task \(dataTask.taskIdentifier, privacy: .public) of chunk \(chunk+1, privacy: .public)/\(chunks, privacy: .public) did receive \(countsOfBytes, privacy: .public) bytes.")
            #endif
        } else {
            UploadSessionsDelegate.logger.fault("Could not extract HTTP header fields.")
            preconditionFailure("Could not extract HTTP header fields.")
        }
        
        let sessionIdentifier = (dataTask.taskDescription ?? "").components(separatedBy: " ").first
        switch sessionIdentifier {
        case uploadSessionIdentifier:
            Task { @UploadManagement in
                UploadManager.shared.didCompleteUploadTask(dataTask, withData: data)
            }
        case uploadBckgSessionIdentifier:
            Task { @UploadManagement in
                UploadManager.shared.didCompleteBckgUploadTask(dataTask, withData: data)
            }
        default:
            UploadSessionsDelegate.logger.fault("Unexpected session identifier.")
            preconditionFailure("Unexpected session identifier.")
        }
    }
}


// MARK: - Counter for Updating Progress Bars and Managing Tasks
extension UploadSessionsDelegate {
    // Upload counters kept in memory during upload
    struct UploadCounter: Sendable, Equatable, Hashable {
        var uid: String
        var bytesSent: Int64        // Bytes sent
        var totalBytes: Int64       // Bytes to upload
        var chunks: Set<Int>        // Chunk IDs of resumed tasks
        var progress: Float {
            get {
                return min(Float(bytesSent) / Float(totalBytes), 1.0)
            }
        }
        
        init(identifier: String, totalBytes: Int64 = 0) {
            self.uid = identifier
            self.bytesSent = Int64.zero
            self.totalBytes = totalBytes
            self.chunks = Set<Int>()
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.uid == rhs.uid
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(uid)
        }
    }

    // Initialise a counter before resuming upload tasks
    func initCounter(withID identifier: String, totalBytes: Int64 = 0) async {
        await counterManager.initCounter(withID: identifier, totalBytes: totalBytes)
    }
    
    // Count how many bytes were sent
    func addBytes(_ bytes: Int64, toCounterWithID identifier: String) async {
        await counterManager.addBytes(bytes, toCounterWithID: identifier)
    }

    // Remember which chunks were managed
    func addChunk(_ chunk: Int, toCounterWithID identifier: String) async {
        await counterManager.addChunk(chunk, toCounterWithID: identifier)
    }
    
    // Return chunks already managed
    func getChunks(forCounterWithID identifier: String) async -> Set<Int> {
        await counterManager.getChunks(forCounterWithID: identifier)
    }
    
    // Returns progress value
    func getProgress(forCounterWithID identifier: String) async -> Float {
        await counterManager.getProgress(forCounterWithID: identifier)
    }
    
    // Deallocate a counter upon upload completion
    func removeCounter(withID identifier: String) async {
        await counterManager.removeCounter(withID: identifier)
    }
}
