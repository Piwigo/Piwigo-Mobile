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

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: (any Error)?) {
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
