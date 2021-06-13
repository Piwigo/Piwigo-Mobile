//
//  KeychainUtilities.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 09/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

public
class KeychainUtilities : NSObject {
    
    // MARK: - SSL Certificate Validation
    public class
    func isSSLtransactionValid(inState serverTrust: SecTrust,
                               for domain: String) -> (Bool) {
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
    
    public class
    func isCertKnownForSSLtransaction(inState serverTrust: SecTrust,
                                      for domain: String) -> (Bool) {
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
    
    
    // MARK: - HTTP Authentication challenge
    public class
    func HTTPcredentialFromKeychain() -> URLCredential? {
        // Retrieve username stored in UserDefaults
        let httpUsername = NetworkVars.shared.httpUsername
        guard httpUsername.isEmpty else { return nil }
        
        // Retrieve password stored in Keychain
        /// HTTP credentials are stored in the Keychain with:
        /// - sevice: <scheme>:<host>
        /// - account: <httpUsername>
        let service = "\(NetworkVars.shared.serverProtocol)\(NetworkVars.shared.serverPath)"
        let account = "\(httpUsername)".data(using: .utf8)!
        let query = [kSecAttrService as String  : service,
                     kSecAttrAccount as String  : account,
                     kSecReturnData as String   : kCFBooleanTrue!,
                     kSecMatchLimit as String   : kSecMatchLimitOne] as [String: Any]

        var data: CFTypeRef?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &data)

        guard status == errSecSuccess else { return nil }
        guard let password = String(data: data as! Data, encoding: .utf8),
              !password.isEmpty else { return nil }
        return URLCredential(user: httpUsername, password: password,
                                 persistence: .forSession)
    }
}
