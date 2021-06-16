//
//  NetworkUtilities.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 08/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

public class NetworkUtilities: NSObject {
    
    let domain: String = {
        let strURL = "\(NetworkVars.shared.serverProtocol)\(NetworkVars.shared.serverPath)"
        return URL(string: strURL)?.host ?? ""
    }()

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
    
    
    // MARK: - UTF-8 encoding on 3 and 4 bytes
    public class
    func utf8mb4String(from string: String?) -> String {
        // Return empty string is nothing provided
        guard let strToConvert = string else {
            return ""
        }
        // Convert string to UTF-8 encoding
        let serverEncoding = String.Encoding(rawValue: NetworkVars.shared.stringEncoding )
        if let strData = strToConvert.data(using: serverEncoding, allowLossyConversion: true) {
            return String(data: strData, encoding: .utf8) ?? strToConvert
        }
        return ""
    }

    // Piwigo supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
    // See https://github.com/Piwigo/Piwigo-Mobile/issues/429, https://github.com/Piwigo/Piwigo/issues/750
    public class
    func utf8mb3String(from string: String?) -> String {
        // Return empty string is nothing provided
        guard let strToFilter = string else {
            return ""
        }

        // Replace characters encoded on 4 bytes
        var utf8mb3String = ""
        for char in strToFilter {
            if char.utf8.count > 3 {
                // 4-byte char => Not handled by Piwigo Server
                utf8mb3String.append("\u{FFFD}")  // Use the Unicode replacement character
            } else {
                // Up to 3-byte char
                utf8mb3String.append(char)
            }
        }
        return utf8mb3String
    }
}
