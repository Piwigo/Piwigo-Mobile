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
    func checkSession(ofUser user: User?, systematically: Bool = false,
                      completion: @escaping () -> Void,
                      failure: @escaping (Error) -> Void) {
        // Check if the session is still active every 60 seconds or more
        if systematically == false {
            let secondsSinceLastCheck = Date.timeIntervalSinceReferenceDate - (user?.lastUsed ?? 0.0)
            if secondsSinceLastCheck < 60,
               PwgSession.shared.wasConnectedToWifi == NetworkVars.shared.isConnectedToWiFi(),
               NetworkVars.shared.applicationShouldRelogin == false {
                completion()
                return
            }
        }
        
        // Determine if the session is still active
        if #available(iOSApplicationExtension 14.0, *) {
            if NetworkVars.shared.isConnectedToWiFi() {
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
                            PwgSession.shared.wasConnectedToWifi = NetworkVars.shared.isConnectedToWiFi()
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
                                PwgSession.shared.wasConnectedToWifi = NetworkVars.shared.isConnectedToWiFi()
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
        guard let strToConvert = string, strToConvert.isEmpty == false else {
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
    public static
    func utf8mb3String(from string: String?) -> String {
        // Return empty string if nothing provided
        guard let strToFilter = string, strToFilter.isEmpty == false else {
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

    
    // MARK: - Clean URLs of Images
    public static
    func encodedImageURL(_ originalURL: String?) -> NSURL? {
        // Return nil if originalURL is nil
        guard let okURL = originalURL else { return nil }
        
        // TEMPORARY PATCH for case where $conf['original_url_protection'] = 'images' or 'all';
        /// See https://github.com/Piwigo/Piwigo-Mobile/issues/503
        /// Seems not to be an issue with all servers or sinnce iOS 17 or 18.
        let patchedURL = okURL.replacingOccurrences(of: "&amp;part=", with: "&part=")
                              .replacingOccurrences(of: "&amp;pwg_token=", with: "&pwg_token=")
                              .replacingOccurrences(of: "&amp;download", with: "&download")
                              .replacingOccurrences(of: "&amp;filter_image_id=", with: "&filter_image_id=")
                              .replacingOccurrences(of: "&amp;sync_metadata=1", with: "&sync_metadata=1")
        var serverURL: NSURL? = NSURL(string: patchedURL)
        
        // Servers may return incorrect URLs
        // See https://tools.ietf.org/html/rfc3986#section-2
        if serverURL == nil {
            // URL not RFC compliant!
            if #available(iOSApplicationExtension 14.0, *) {
                PwgSession.logger.notice("Received invalid URL: \(originalURL ?? "", privacy: .public)")
            }
            var leftURL = patchedURL

            // Remove protocol header
            if patchedURL.hasPrefix("http://") { leftURL.removeFirst(7) }
            if patchedURL.hasPrefix("https://") { leftURL.removeFirst(8) }
            
            // Retrieve authority
            guard let endAuthority = leftURL.firstIndex(of: "/") else {
                // No path, incomplete URL —> return nil
                return nil
            }
            let authority = String(leftURL.prefix(upTo: endAuthority))
            leftURL.removeFirst(authority.count)

            // The Piwigo server may not be in the root e.g. example.com/piwigo/…
            // So we remove the path to avoid a duplicate if necessary
            if let loginURL = URL(string: NetworkVars.shared.service),
               loginURL.path.count > 0, leftURL.hasPrefix(loginURL.path) {
                leftURL.removeFirst(loginURL.path.count)
            }

            // Retrieve path
            if let endQuery = leftURL.firstIndex(of: "?") {
                // URL contains a query
                let query = (String(leftURL.prefix(upTo: endQuery)) + "?").replacingOccurrences(of: "??", with: "?")
                guard let newQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                    // Could not apply percent encoding —> return nil
                    return nil
                }
                leftURL.removeFirst(query.count)
                guard let newPath = leftURL.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
                    // Could not apply percent encoding —> return image.jpg but should never happen
                    return nil
                }
                serverURL = NSURL(string: NetworkVars.shared.service + newQuery + newPath)
            } else {
                // No query -> remaining string is a path
                let newPath = String(leftURL.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!)
                serverURL = NSURL(string: NetworkVars.shared.service + newPath)
            }
            
            // Last check
            if serverURL == nil {
                // Could not apply percent encoding —> return nil
                return nil
            }
        }
        
        // Servers may return image URLs different from those used to login (e.g. wrong server settings)
        // We only keep the path+query because we only accept to download images from the same server.
        guard var cleanPath = serverURL?.path else {
            return nil
        }
        if let paramStr = serverURL?.parameterString {
            cleanPath.append(paramStr)
        }
        if let query = serverURL?.query {
            cleanPath.append("?" + query)
        }
        if let fragment = serverURL?.fragment {
            cleanPath.append("#" + fragment)
        }

        // The Piwigo server may not be in the root e.g. example.com/piwigo/…
        // and images may not be in the same path
        var loginPath = NetworkVars.shared.service
        if let loginURL = URL(string: loginPath), loginURL.path.count > 0 {
            if cleanPath.hasPrefix(loginURL.path) {
                // Remove the path to avoid a duplicate
                cleanPath.removeFirst(loginURL.path.count)
            } else {
                // Different paths
                loginPath.removeLast(loginURL.path.count)
            }
        }
        
        // Remove the .php?, i? prefixes if any
        var prefix = ""
        if let pos = cleanPath.range(of: "?") {
            // The path contains .php? or i?
            prefix = String(cleanPath.prefix(upTo: pos.upperBound))
            cleanPath.removeFirst(prefix.count)
        }

        // Path may not be encoded
        if let decodedPath = cleanPath.removingPercentEncoding, cleanPath == decodedPath,
           let test = cleanPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
            cleanPath = test
        }

        // Compile final URL using the one provided at login
        let encodedImageURL = "\(loginPath)\(prefix)\(cleanPath)"
        #if DEBUG
        if #available(iOSApplicationExtension 14.0, *),
           encodedImageURL != originalURL {
            PwgSession.logger.notice("Invalid URL \"\(originalURL ?? "", privacy: .public)\" replaced by \(encodedImageURL.debugDescription, privacy: .public) where path=\"\(serverURL?.path ?? "", privacy: .public)\", parameterString=\"\(serverURL?.parameterString ?? "", privacy: .public)\", query=\"\(serverURL?.query ?? "", privacy: .public)\", fragment=\"\(serverURL?.fragment ?? "", privacy: .public)\"")
        }
        #endif
        return NSURL(string: encodedImageURL)
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
