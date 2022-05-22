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
    
    // Access group
    private class
    func getAccessGroup() -> String {
        let teamID = Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String
        let bundleID = Bundle.main.bundleIdentifier!.components(separatedBy: ".")
        let pos = bundleID.firstIndex(of: "piwigo")
        let mainBundleID = bundleID[0...pos!].joined(separator: ".")
        return teamID + mainBundleID
    }
    
    // MARK: - Piwigo & HTTP Authentication
    /// - https://www.osstatus.com/search/results?platform=all&framework=all&search=0
    // Convention
    /// Piwigo credentials are identified in the Keychain with:
    /// - service: <host>
    /// - account: <username>
    /// HTTP credentials are stored in the Keychain with:
    /// - service: <scheme>:<host>
    /// - account: <httpUsername>
    public class
    func setPassword(_ password:String, forService service:String, account:String) {
        // Check input parameters
        guard service.isEmpty == false, account.isEmpty == false, password.isEmpty == false,
              let passwordData = password.data(using: .utf8) else { return }
        
        // Prepare query
        let searchQuery = [kSecClass as String                : kSecClassGenericPassword,
                           kSecAttrService as String          : service,
                           kSecAttrAccount as String          : account,
                           kSecAttrAccessGroup as String      : getAccessGroup(),
                           kSecAttrSynchronizable as String   : kSecAttrSynchronizableAny] as [String : Any]

        // Already in Keychain?
        var status = SecItemCopyMatching(searchQuery as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            // Already existing —> update it
            let query = [kSecValueData as String            : passwordData,
                         kSecAttrAccessible as String       : kSecAttrAccessibleAfterFirstUnlock] as [String : Any]
            status = SecItemUpdate(searchQuery as CFDictionary, query as CFDictionary)

        case errSecItemNotFound:
            // Create new item in Keychain
            let query = [kSecClass as String                : kSecClassGenericPassword,
                         kSecAttrService as String          : service,
                         kSecAttrAccount as String          : account,
                         kSecAttrAccessGroup as String      : getAccessGroup(),
                         kSecAttrSynchronizable as String   : kSecAttrSynchronizableAny,
                         kSecValueData as String            : passwordData,
                         kSecAttrAccessible as String       : kSecAttrAccessibleAfterFirstUnlock] as [String : Any]
            status = SecItemAdd(query as CFDictionary, nil)
            
        default:
            // Log error
            logOSStatus(status)
        }
        
        if status != errSecSuccess { logOSStatus(status) }
        return
    }
    
    public class
    func password(forService service:String, account:String) -> String {
        // Check input parameters
        guard service.isEmpty == false, account.isEmpty == false else { return "" }

        // Prepare query
        let query = [kSecClass as String                : kSecClassGenericPassword,
                     kSecAttrService as String          : service,
                     kSecAttrAccount as String          : account,
                     kSecAttrAccessGroup as String      : getAccessGroup(),
                     kSecAttrSynchronizable as String   : kSecAttrSynchronizableAny,
                     kSecReturnData as String           : kCFBooleanTrue!,
                     kSecMatchLimit as String           : kSecMatchLimitOne] as [String: Any]

        // Apply the query
        var data: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &data)

        // Results?
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                // Security item not found -> try old method
                /// Piwigo credentials are identified in the Keychain with:
                /// - generic: "PiwigoLogin"
                /// - attribute: <username>
                let kKeychainAppID = "PiwigoLogin"
                let query = [kSecClass as String            : kSecClassGenericPassword,
                             kSecAttrGeneric as String      : kKeychainAppID,
                             kSecReturnAttributes as String : kCFBooleanTrue!,
                             kSecMatchLimit as String       : kSecMatchLimitOne] as [String: Any]

                var data: CFTypeRef?
                let status = SecItemCopyMatching(query as CFDictionary, &data)
                guard status == errSecSuccess else {
                    logOSStatus(status)
                    return ""
                }
                
                // Did found username
                guard let username = String(data: data as! Data, encoding: .utf8),
                      username.isEmpty == false else { return "" }
                if username == NetworkVars.username {
                    // Retrieve password
                    let query = [kSecClass as String            : kSecClassGenericPassword,
                                 kSecAttrGeneric as String      : kKeychainAppID,
                                 kSecAttrAccount as String      : username,
                                 kSecAttrAccessGroup as String  : getAccessGroup(),
                                 kSecMatchLimit as String       : kSecMatchLimitOne] as [String: Any]

                    var data: CFTypeRef?
                    let status = SecItemCopyMatching(query as CFDictionary, &data)
                    guard status == errSecSuccess else {
                        logOSStatus(status)
                        return ""
                    }
                    guard let password = String(data: data as! Data, encoding: .utf8),
                          password.isEmpty == false else { return "" }
                    return password
                }
            }
            logOSStatus(status)
            return ""
        }
        guard let password = String(data: data as! Data, encoding: .utf8),
              password.isEmpty == false else {
            logOSStatus(status)
            return ""
        }
        return password
    }
    
    public class
    func deletePassword(forService service:String, account:String) {
        // Check input parameters
        guard service.isEmpty == false, account.isEmpty == false else { return }

        // Prepare query
        let query = [kSecClass as String                : kSecClassGenericPassword,
                     kSecAttrService as String          : service,
                     kSecAttrAccount as String          : account,
                     kSecAttrAccessGroup as String      : getAccessGroup(),
                     kSecAttrSynchronizable as String   : kSecAttrSynchronizableAny] as [String: Any]

        // Apply the query
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess { logOSStatus(status) }
        return
    }
    
    public class
    func logOSStatus(_ status:OSStatus) {
        #if DEBUG
        if #available(iOSApplicationExtension 11.3, *) {
            let msg = SecCopyErrorMessageString(status, nil)
            print("••> OSStatus Error #\(status): \(msg as String?)")
        } else {
            let url = "https://www.osstatus.com/search/results?platform=all&framework=all&search=\(status)"
            print("••> OSStatus Error #\(status): \(url)")
        }
        #endif
    }

    
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
    func isCertKnownForSSLtransaction(_ certificate: SecCertificate,
                                      for domain: String) -> Bool {
        // Get certificate in Keychain (should exist)
        // Certificates are stored in the Keychain with label "Piwigo:<host>"
        let query = [kSecClass as String            : kSecClassCertificate,
                     kSecAttrLabel as String        : "Piwigo:\(domain)",
                     kSecAttrAccessGroup as String  : getAccessGroup(),
                     kSecReturnRef as String        : kCFBooleanTrue!] as [String : Any]

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
    
    public class
    func deleteCertificate(for domain: String) {
        // Certificates are stored in the Keychain with label "Piwigo:<host>"
        let query = [kSecClass as String            : kSecClassCertificate,
                     kSecAttrLabel as String        : "Piwigo:\(domain)",
                     kSecAttrAccessGroup as String  : getAccessGroup()] as [String : Any]
        let status: OSStatus = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess { logOSStatus(status) }
    }
    
    public class
    func storeCertificate(_ certificate: SecCertificate, for domain: String) {
        // Certificates are stored in the Keychain with label "Piwigo:<host>"
        let query = [kSecClass as String            : kSecClassCertificate,
                     kSecAttrLabel as String        : "Piwigo:\(domain)",
                     kSecAttrAccessGroup as String  : getAccessGroup(),
                     kSecValueRef as String         : certificate] as [String : Any]
        let status: OSStatus = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess { logOSStatus(status) }
    }
    
    public class
    func getCertificateInfo(_ certificate: SecCertificate, for fomain: String) -> String {
        // Initialise string that will be presented to the user.
        var certString = "(" + NetworkVars.domain()
        
        // Add summary, e.g. "QNAP NAS"
        if let summary = SecCertificateCopySubjectSummary(certificate) as? String,
           summary.isEmpty == false, summary != NetworkVars.domain() {
            certString.append(", " + summary)
        }
        
        // Add contact email, e.g. support@qnap.com
        if #available(iOS 10.3, *) {
            var emailAddresses: CFArray!
            let status: OSStatus = SecCertificateCopyEmailAddresses(certificate, &emailAddresses)
            if status == errSecSuccess, CFArrayGetCount(emailAddresses) > 0 {
                if let address = (emailAddresses as Array).first {
                    certString.append(", " + address.string)
                }
            }
        }
        certString.append(")")
        return certString
    }
}
