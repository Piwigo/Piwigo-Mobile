//
//  PwgSession+Delegate.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 08/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - Session Delegate
extension PwgSession: URLSessionDelegate {

//    public func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
//        debugPrint("    > The upload session is waiting for connectivity (offline mode)")
//    }
        
//    public func urlSession(_ session: URLSession, task: URLSessionTask, willBeginDelayedRequest: URLRequest, completionHandler: (URLSession.DelayedRequestDisposition, URLRequest?) -> Void) {
//        debugPrint("    > The upload session will begin delayed request (back to online)")
//    }

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        if #available(iOSApplicationExtension 14.0, *) {
            PwgSession.logger.notice("Session invalidated.")
        }
        activeDownloads = [ : ]
    }
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if #available(iOSApplicationExtension 14.0, *) {
            PwgSession.logger.notice("Session-level authentication requested by server.")
        }
        // Get protection space for current domain
        let protectionSpace = challenge.protectionSpace
        guard protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
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
        if KeychainUtilities.isSSLtransactionValid(inState: serverTrust, for: NetworkVars.domain()) {
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
        if KeychainUtilities.isCertKnownForSSLtransaction(certificate, for: NetworkVars.domain()) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            return
        }
        
        // No certificate or different non-trusted certificate found in Keychain
        // Did the user approve this certificate?
        if NetworkVars.didApproveCertificate {
            // Delete certificate in Keychain (updating the certificate data is not sufficient)
            KeychainUtilities.deleteCertificate(for: NetworkVars.domain())

            // Store server certificate in Keychain with same label "Piwigo:<host>"
            KeychainUtilities.storeCertificate(certificate, for: NetworkVars.domain())

            // Will reject a connection if the certificate is changed during a session
            // but it will still be possible to logout.
            NetworkVars.didApproveCertificate = false
            
            // Accept connection
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            return
        }
        
        // Will ask the user whether we should trust this server.
        NetworkVars.certificateInformation = KeychainUtilities.getCertificateInfo(certificate, for: NetworkVars.domain())
        NetworkVars.didRejectCertificate = true

        // Reject the request
        completionHandler(.performDefaultHandling, nil)
    }
}
