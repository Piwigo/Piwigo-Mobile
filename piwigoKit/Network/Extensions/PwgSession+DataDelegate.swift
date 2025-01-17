//
//  PwgSession+DataDelegate.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 08/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - Session Data Delegate
extension PwgSession: URLSessionDataDelegate {
        
    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if #available(iOSApplicationExtension 14.0, *) {
            PwgSession.logger.notice("Task-level authentication requested.")
        }
        // Check authentication method
        let authMethod = challenge.protectionSpace.authenticationMethod
        guard [NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest].contains(authMethod) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Initialise HTTP authentication flag
        NetworkVars.didFailHTTPauthentication = false
        
        // Get HTTP basic authentification credentials
        let service = NetworkVars.service
        var account = NetworkVars.httpUsername
        var password = KeychainUtilities.password(forService: service, account: account)

        // Without HTTP credentials available, tries Piwigo credentials
        if account.isEmpty || password.isEmpty {
            // Retrieve Piwigo credentials
            account = NetworkVars.username
            password = KeychainUtilities.password(forService: NetworkVars.serverPath, account: account)
            
            // Adopt Piwigo credentials as HTTP basic authentification credentials
            NetworkVars.httpUsername = account
            KeychainUtilities.setPassword(password, forService: NetworkVars.service, account: account)
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
