//
//  KeychainUtilities.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 09/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

public final class KeychainUtilities: NSObject {
    
    // Access group
    private static
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
    public static
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
    
    public static
    func password(forService service:String, account:String) -> String {
        // Check input parameters
        guard service.isEmpty == false, account.isEmpty == false else { return "" }

        // Prepare query
        var query = [kSecClass as String                : kSecClassGenericPassword,
                     kSecAttrService as String          : service,
                     kSecAttrAccount as String          : account,
                     kSecAttrAccessGroup as String      : getAccessGroup(),
                     kSecAttrSynchronizable as String   : kSecAttrSynchronizableAny,
                     kSecReturnData as String           : kCFBooleanTrue!,
                     kSecMatchLimit as String           : kSecMatchLimitOne] as [String: Any]

        // Apply the query
        var dataRef: CFTypeRef?
        var status = SecItemCopyMatching(query as CFDictionary, &dataRef)

        // Results?
        if status == errSecSuccess {
            guard let data = dataRef as? Data,
                  let password = String(data: data, encoding: .utf8),
                  password.isEmpty == false else {
                logOSStatus(status)
                return ""
            }
            return password
        }
        
        // Should we try the old method?
        if status != errSecItemNotFound {
            logOSStatus(status)
            return ""
        }
        
        // Security item not found -> try old method
        /// Piwigo credentials are identified in the Keychain with:
        /// - generic: "PiwigoLogin"
        /// - attribute: <username>
        let kKeychainAppID = "PiwigoLogin"
        query = [kSecClass as String            : kSecClassGenericPassword,
                 kSecAttrGeneric as String      : kKeychainAppID,
                 kSecReturnAttributes as String : kCFBooleanTrue!,
                 kSecMatchLimit as String       : kSecMatchLimitOne] as [String: Any]

        status = SecItemCopyMatching(query as CFDictionary, &dataRef)
        guard status == errSecSuccess else {
            logOSStatus(status)
            return ""
        }
        
        // Old query successful
        guard let data = dataRef as? Data,
              let username = String(data: data, encoding: .utf8),
              username.isEmpty == false else { return "" }

        // Did found non-empty username
        if username != NetworkVars.shared.username {
            // No known password
            return ""
        }
        
        // Retrieve password
        query = [kSecClass as String            : kSecClassGenericPassword,
                 kSecAttrGeneric as String      : kKeychainAppID,
                 kSecAttrAccount as String      : username,
                 kSecAttrAccessGroup as String  : getAccessGroup(),
                 kSecMatchLimit as String       : kSecMatchLimitOne] as [String: Any]

        status = SecItemCopyMatching(query as CFDictionary, &dataRef)
        guard status == errSecSuccess else {
            logOSStatus(status)
            return ""
        }
        guard let data = dataRef as? Data,
              let password = String(data: data, encoding: .utf8),
              password.isEmpty == false else { return "" }
        return password
    }
    
    public static
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
    
    public static
    func logOSStatus(_ status:OSStatus) {
        #if DEBUG
        if #available(iOSApplicationExtension 11.3, *) {
            let msg = SecCopyErrorMessageString(status, nil)
            debugPrint("••> OSStatus Error #\(status): \(msg as String?)")
        } else {
            let url = "https://www.osstatus.com/search/results?platform=all&framework=all&search=\(status)"
            debugPrint("••> OSStatus Error #\(status): \(url)")
        }
        #endif
    }

    
    // MARK: - SSL Certificate Validation
    public static
    func isSSLtransactionValid(inState serverTrust: SecTrust,
                               for domain: String) -> (Bool) {
        // Define policy for validating domain name
        let policy = SecPolicyCreateSSL(true, domain as CFString)
        let status = SecTrustSetPolicies(serverTrust, policy)
        if status != 0 { return false }     // Could not set policy
        
        // Evaluate certificate
        return SecTrustEvaluateWithError(serverTrust, nil)
    }
    
    public static
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
    
    public static
    func deleteCertificate(for domain: String) {
        // Certificates are stored in the Keychain with label "Piwigo:<host>"
        let query = [kSecClass as String            : kSecClassCertificate,
                     kSecAttrLabel as String        : "Piwigo:\(domain)",
                     kSecAttrAccessGroup as String  : getAccessGroup()] as [String : Any]
        let status: OSStatus = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess { logOSStatus(status) }
    }
    
    public static
    func storeCertificate(_ certificate: SecCertificate, for domain: String) {
        // Certificates are stored in the Keychain with label "Piwigo:<host>"
        let query = [kSecClass as String            : kSecClassCertificate,
                     kSecAttrLabel as String        : "Piwigo:\(domain)",
                     kSecAttrAccessGroup as String  : getAccessGroup(),
                     kSecValueRef as String         : certificate] as [String : Any]
        let status: OSStatus = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess { logOSStatus(status) }
    }
    
    public static
    func getCertificateInfo(_ certificate: SecCertificate, for fomain: String) -> String {
        // Initialise string that will be presented to the user.
        var certString = "(" + NetworkVars.shared.domain()
        
        // Add summary, e.g. "QNAP NAS"
        if let summary = SecCertificateCopySubjectSummary(certificate) as? String,
           summary.isEmpty == false, summary != NetworkVars.shared.domain() {
            certString.append(", " + summary)
        }
        
        // Add contact email, e.g. support@qnap.com
        var emailAddresses: CFArray!
        let status: OSStatus = SecCertificateCopyEmailAddresses(certificate, &emailAddresses)
        if status == errSecSuccess, emailAddresses != nil,
           CFArrayGetCount(emailAddresses) > 0,
           let address = (emailAddresses as Array).first as? String {
            certString.append(", " + address)
        }
        certString.append(")")
        return certString
    }
}
