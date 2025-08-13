//
//  PwgSession+Utilities.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 08/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import os
import Foundation
import UIKit

extension PwgSession {
    // MARK: - Sessionn Management
    public static
    func requestServerMethods(completion: @escaping () -> Void,
                              didRejectCertificate: @escaping (Error) -> Void,
                              didFailHTTPauthentication: @escaping (Error) -> Void,
                              didFailSecureConnection: @escaping (Error) -> Void,
                              failure: @escaping (Error) -> Void) {
        // Collect list of methods supplied by Piwigo server
        // => Determine if Community extension 2.9a or later is installed and active
        PwgSession.shared.getMethods {
            // Known methods, pursue logging in…
            completion()
        } failure: { error in
            // If Piwigo uses a non-trusted certificate, ask permission
            if NetworkVars.shared.didRejectCertificate {
                // The SSL certificate is not trusted
                didRejectCertificate(error)
                return
            }

            // HTTP Basic authentication required?
            if (error as NSError).code == 401 || (error as NSError).code == 403 || NetworkVars.shared.didFailHTTPauthentication {
                // Without prior knowledge, the app already tried Piwigo credentials
                // but unsuccessfully, so we request HTTP credentials
                didFailHTTPauthentication(error)
                return
            }

            switch (error as NSError).code {
            case NSURLErrorUserAuthenticationRequired:
                // Without prior knowledge, the app already tried Piwigo credentials
                // but unsuccessfully, so must now request HTTP credentials
                didFailHTTPauthentication(error)
                return
            case NSURLErrorUserCancelledAuthentication:
                failure(error)
                return
            case NSURLErrorBadServerResponse, NSURLErrorBadURL, NSURLErrorCallIsActive, NSURLErrorCannotDecodeContentData, NSURLErrorCannotDecodeRawData, NSURLErrorCannotFindHost, NSURLErrorCannotParseResponse, NSURLErrorClientCertificateRequired, NSURLErrorDataLengthExceedsMaximum, NSURLErrorDataNotAllowed, NSURLErrorDNSLookupFailed, NSURLErrorHTTPTooManyRedirects, NSURLErrorInternationalRoamingOff, NSURLErrorNetworkConnectionLost, NSURLErrorNotConnectedToInternet, NSURLErrorRedirectToNonExistentLocation, NSURLErrorRequestBodyStreamExhausted, NSURLErrorTimedOut, NSURLErrorUnknown, NSURLErrorUnsupportedURL, NSURLErrorZeroByteResource:
                failure(error)
                return
            case NSURLErrorCannotConnectToHost,    // Happens when the server does not reply to the request (HTTP or HTTPS)
                NSURLErrorSecureConnectionFailed:
                // HTTPS request failed ?
                if NetworkVars.shared.serverProtocol == "https://" {
                    // Suggest HTTP connection if HTTPS attempt failed
                    didFailSecureConnection(error)
                    return
                }
                return
            case NSURLErrorClientCertificateRejected, NSURLErrorServerCertificateHasBadDate, NSURLErrorServerCertificateHasUnknownRoot, NSURLErrorServerCertificateNotYetValid, NSURLErrorServerCertificateUntrusted:
                // The SSL certificate is not trusted
                didRejectCertificate(error)
                return
            default:
                break
            }

            // Display error message
            failure(error)
        }
    }
    
    // Re-login if session was closed
    public static
    func checkSession(ofUser user: User?,
                      completion: @escaping () -> Void,
                      failure: @escaping (Error) -> Void) {
        // Check if the session is still active every 60 seconds or more
        let secondsSinceLastCheck = Date.timeIntervalSinceReferenceDate - (user?.lastUsed ?? 0.0)
        if PwgSession.shared.hasNetworkConnectionChanged == false,
           NetworkVars.shared.applicationShouldRelogin == false,
           secondsSinceLastCheck < 60 {
            completion()
            return
        }
        
        // Determine if the session is still active
        PwgSession.shared.hasNetworkConnectionChanged = false
        if #available(iOSApplicationExtension 14.0, *) {
            if NetworkVars.shared.isConnectedToWiFi {
                logger.notice("Start checking session… (WiFi)")
            } else {
                logger.notice("Start checking session… (Cellular)")
            }
        }
        let oldToken = NetworkVars.shared.pwgToken
        PwgSession.shared.sessionGetStatus { username in
            if #available(iOSApplicationExtension 14.0, *) {
                #if DEBUG
                logger.notice("Session: \(NetworkVars.shared.username, privacy: .public)/\(username, privacy: .public), \(oldToken, privacy: .public)/\(NetworkVars.shared.pwgToken, privacy: .public)")
                #else
                logger.notice("Session: \(NetworkVars.shared.username, privacy: .private(mask: .hash))/\(username, privacy: .private(mask: .hash)), \(oldToken, privacy: .private(mask: .hash))/\(NetworkVars.shared.pwgToken, privacy: .private(mask: .hash))")
                #endif
            }
            if username != NetworkVars.shared.username || oldToken.isEmpty || NetworkVars.shared.pwgToken != oldToken {
                // Collect list of methods supplied by Piwigo server
                // => Determine if Community extension 2.9a or later is installed and active
                requestServerMethods {
                    // Known methods, perform re-login
                    // Don't use userStatus as it may not be known after Core Data migration
                    if NetworkVars.shared.username.isEmpty || NetworkVars.shared.username.lowercased() == "guest" {
                        if #available(iOSApplicationExtension 14.0, *) {
                            logger.notice("Session opened for Guest")
                        }
                        // Session now opened
                        getPiwigoConfig {
                            // Update date of accesss to the server by guest
                            DispatchQueue.main.async {
                                user?.setLastUsedToNow()
                                user?.status = NetworkVars.shared.userStatus.rawValue
                            }
                            NetworkVars.shared.applicationShouldRelogin = false
                            completion()
                        } failure: { error in
                            failure(error)
                        }
                    } else {
                        // Perform login
                        let username = NetworkVars.shared.username
                        let password = KeychainUtilities.password(forService: NetworkVars.shared.serverPath, account: username)
                        PwgSession.shared.sessionLogin(withUsername: username, password: password) {
                            // Session now opened
                            getPiwigoConfig {
                                // Update date of accesss to the server by user
                                DispatchQueue.main.async {
                                    user?.setLastUsedToNow()
                                    user?.status = NetworkVars.shared.userStatus.rawValue
                                }
                                NetworkVars.shared.applicationShouldRelogin = false
                                completion()
                            } failure: { error in
                                failure(error)
                            }
                        } failure: { error in
                            failure(error)
                        }
                    }
                } didRejectCertificate: { error in
                    failure(error)
                } didFailHTTPauthentication: { error in
                    failure(error)
                } didFailSecureConnection: { error in
                    failure(error)
                } failure: { error in
                    failure(error)
                }
            } else {
                DispatchQueue.main.async {
                    user?.setLastUsedToNow()
                }
                completion()
            }
        } failure: { error in
            failure(error)
        }
    }
    
    static func getPiwigoConfig(completion: @escaping () -> Void,
                                failure: @escaping (Error) -> Void) {
        // Check Piwigo version, get token, available sizes, etc.
        if NetworkVars.shared.usesCommunityPluginV29 {
            PwgSession.shared.communityGetStatus {
                PwgSession.shared.sessionGetStatus { _ in
                    // Check Piwigo server version
                    if NetworkVars.shared.pwgVersion.compare(NetworkVars.shared.pwgMinVersion, options: .numeric) == .orderedAscending {
                        failure(PwgSessionError.incompatiblePwgVersion) }
                    else {
                        completion()
                    }
                } failure: { error in
                    failure(error)
                }
            } failure: { error in
                failure(error)
            }
        } else {
            PwgSession.shared.sessionGetStatus { _ in
                // Check Piwigo server version
                if NetworkVars.shared.pwgVersion.compare(NetworkVars.shared.pwgMinVersion, options: .numeric) == .orderedAscending {
                    failure(PwgSessionError.incompatiblePwgVersion) }
                else {
                    completion()
                }
            } failure: { error in
                failure(error)
            }
        }
    }


    // MARK: - UTF-8 encoding on 3 and 4 bytes
    public static
    func utf8mb4String(from string: String?) -> String {
        // Return empty string if nothing provided
        guard let strToConvert = string, strToConvert.isEmpty == false
        else { return "" }
        
        // Convert string to UTF-8 encoding
        let serverEncoding = String.Encoding(rawValue: NetworkVars.shared.stringEncoding )
        if let strData = strToConvert.data(using: serverEncoding, allowLossyConversion: true) {
            return String(data: strData, encoding: .utf8) ?? strToConvert
        }
        return ""
    }

    // Piwigo supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
    // See https://github.com/Piwigo/Piwigo-Mobile/issues/429, https://github.com/Piwigo/Piwigo/issues/750
    public static
    func utf8mb3String(from string: String?) -> String {
        // Return empty string if nothing provided
        guard let strToFilter = string, strToFilter.isEmpty == false
        else { return "" }

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

    
    // MARK: - Clean URLs of Images
    public static
    func encodedImageURL(_ originalURL: String?) -> NSURL? {
        // Return nil if originalURL is nil or empty
        guard let okURL = originalURL, !okURL.isEmpty else { return nil }
        
        // TEMPORARY PATCH for case where $conf['original_url_protection'] = 'images' or 'all';
        /// See https://github.com/Piwigo/Piwigo-Mobile/issues/503
        /// Seems not to be an issue with all servers or since iOS 17 or 18.
        let patchedURL = okURL.replacingOccurrences(of: "&amp;part=", with: "&part=")
                              .replacingOccurrences(of: "&amp;pwg_token=", with: "&pwg_token=")
                              .replacingOccurrences(of: "&amp;download", with: "&download")
                              .replacingOccurrences(of: "&amp;filter_image_id=", with: "&filter_image_id=")
                              .replacingOccurrences(of: "&amp;sync_metadata=1", with: "&sync_metadata=1")
        
        var serverComponents: URLComponents
        
        if let components = URLComponents(string: patchedURL) {
            serverComponents = components
        } else {
            // URL not RFC compliant! - Try to fix it manually
            if #available(iOSApplicationExtension 14.0, *) {
                PwgSession.logger.notice("Received invalid URL: \(originalURL ?? "", privacy: .public)")
            }
            
            guard let fixedComponents = fixInvalidURL(patchedURL) else {
                return nil
            }
            serverComponents = fixedComponents
        }
        
        // Servers may return image URLs different from those used to login
        // We only accept downloads from the same server, so reconstruct with login service
        guard let loginComponents = URLComponents(string: NetworkVars.shared.service) else {
            return nil
        }
        
        var finalComponents = loginComponents
        
        // Preserve the path from server URL, handling Piwigo subdirectory installations
        var serverPath = serverComponents.path
        if loginComponents.path.count > 0 && serverPath.hasPrefix(loginComponents.path) {
            // Remove login path to avoid duplication
            serverPath.removeFirst(loginComponents.path.count)
        }
        
        // Combine paths
        finalComponents.path = loginComponents.path + serverPath
        
        // Handle query parameters using URLQueryItem
        if let serverQueryItems = serverComponents.queryItems, !serverQueryItems.isEmpty {
            finalComponents.queryItems = serverQueryItems
        }
        
        // Preserve fragment if present
        if let fragment = serverComponents.fragment {
            finalComponents.fragment = fragment
        }
        
        guard let finalURL = finalComponents.url else {
            return nil
        }
        
        #if DEBUG
        if #available(iOSApplicationExtension 14.0, *),
           let originalURL = originalURL,
           finalURL.absoluteString != originalURL {
            PwgSession.logger.notice("Invalid URL \"\(originalURL, privacy: .public)\" replaced by \(finalURL.absoluteString, privacy: .public)")
        }
        #endif
        
        return finalURL as NSURL
    }

    private static
    func fixInvalidURL(_ urlString: String) -> URLComponents? {
        var leftURL = urlString
        
        // Remove protocol header
        var scheme = "https"
        if urlString.hasPrefix("http://") {
            scheme = "http"
            leftURL.removeFirst(7)
        } else if urlString.hasPrefix("https://") {
            leftURL.removeFirst(8)
        }
        
        // Retrieve authority (host)
        guard let endAuthority = leftURL.firstIndex(of: "/") else {
            // No path, incomplete URL
            return nil
        }
        let authority = String(leftURL.prefix(upTo: endAuthority))
        leftURL.removeFirst(authority.count)
        
        // Handle Piwigo subdirectory installations
        if let loginURL = URL(string: NetworkVars.shared.service),
           loginURL.path.count > 0, leftURL.hasPrefix(loginURL.path) {
            leftURL.removeFirst(loginURL.path.count)
        }
        
        var components = URLComponents()
        components.scheme = scheme
        components.host = authority
        
        // Parse path, query, and fragment
        if let queryStart = leftURL.firstIndex(of: "?") {
            // Has query parameters
            let path = String(leftURL.prefix(upTo: queryStart))
            let queryAndFragment = String(leftURL.suffix(from: leftURL.index(after: queryStart)))
            
            components.path = path
            
            // Separate query from fragment
            if let fragmentStart = queryAndFragment.firstIndex(of: "#") {
                let queryString = String(queryAndFragment.prefix(upTo: fragmentStart))
                let fragment = String(queryAndFragment.suffix(from: queryAndFragment.index(after: fragmentStart)))
                
                let queryItems = parseQueryString(queryString)
                if !queryItems.isEmpty {
                    components.queryItems = queryItems
                }
                
                if !fragment.isEmpty {
                    components.fragment = fragment
                }
            } else {
                // No fragment, just query
                let queryItems = parseQueryString(queryAndFragment)
                if !queryItems.isEmpty {
                    components.queryItems = queryItems
                }
            }
        } else {
            // Check if there's a fragment without query
            if let fragmentStart = leftURL.firstIndex(of: "#") {
                let path = String(leftURL.prefix(upTo: fragmentStart))
                let fragment = String(leftURL.suffix(from: leftURL.index(after: fragmentStart)))
                
                components.path = path
                if !fragment.isEmpty {
                    components.fragment = fragment
                }
            } else {
                // No query or fragment, just path
                components.path = leftURL
            }
        }
        
        // Validate the components can create a valid URL
        guard components.url != nil else {
            return nil
        }
        
        return components
    }

    private static
    func parseQueryString(_ queryString: String) -> [URLQueryItem] {
        var queryItems: [URLQueryItem] = []
        
        // Separate query from fragment
        let parts = queryString.components(separatedBy: "#")
        let actualQuery = parts[0]
        
        // Split by & to get individual parameters
        let parameters = actualQuery.components(separatedBy: "&")
        
        for parameter in parameters {
            if parameter.isEmpty { continue }
            
            let keyValue = parameter.components(separatedBy: "=")
            let key = keyValue[0]
            let value = keyValue.count > 1 ? keyValue[1] : ""
            
            // URLQueryItem handles percent encoding automatically
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        
        return queryItems
    }
}


// MARK: - RFC 3986 allowed characters
extension CharacterSet {
    /// Creates a CharacterSet from RFC 3986 allowed characters.
    ///
    /// https://datatracker.ietf.org/doc/html/rfc3986/#section-2.2
    /// Section 2.2 states that the following characters are "reserved" characters.
    ///
    /// - General Delimiters: ":", "#", "[", "]", "@", "?", "/"
    /// - Sub-Delimiters: "!", "$", "&", "'", "(", ")", "*", "+", ",", ";", "="
    ///
    /// https://datatracker.ietf.org/doc/html/rfc3986/#section-3.4
    /// Section 3.4 states that the "?" and "/" characters should not be escaped to allow
    /// query strings to include a URL. Therefore, all "reserved" characters with the exception of "?" and "/"
    /// should be percent-escaped in the query string.
    ///
    public static let pwgURLQueryAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@"
        let subDelimitersToEncode = "!$&'()*+,;="
        let encodableDelimiters = CharacterSet(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")

        return CharacterSet.urlQueryAllowed.subtracting(encodableDelimiters)
    }()
}
