//
//  NetworkUtilities.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 08/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import os
import Foundation
import UIKit

public class NetworkUtilities: NSObject {
    
    // Logs networking activities
    /// sudo log collect --device --start '2023-04-07 15:00:00' --output piwigo.logarchive
    @available(iOSApplicationExtension 14.0, *)
    static let logger = Logger(subsystem: "org.piwigoKit", category: "Networking")


    // MARK: - Sessionn Management
    public static
    func requestServerMethods(completion: @escaping () -> Void,
                              didRejectCertificate: @escaping (NSError) -> Void,
                              didFailHTTPauthentication: @escaping (NSError) -> Void,
                              didFailSecureConnection: @escaping (NSError) -> Void,
                              failure: @escaping (NSError) -> Void) {
        // Collect list of methods supplied by Piwigo server
        // => Determine if Community extension 2.9a or later is installed and active
        PwgSession.shared.getMethods {
            // Known methods, pursue logging in…
            completion()
        } failure: { error in
            // If Piwigo uses a non-trusted certificate, ask permission
            if NetworkVars.didRejectCertificate {
                // The SSL certificate is not trusted
                didRejectCertificate(error)
                return
            }

            // HTTP Basic authentication required?
            if (error as NSError).code == 401 || (error as NSError).code == 403 || NetworkVars.didFailHTTPauthentication {
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
                if NetworkVars.serverProtocol == "https://" {
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
                      failure: @escaping (NSError) -> Void) {
        if #available(iOSApplicationExtension 14.0, *) {
            logger.notice("Start checking session…")
        }
        // Determine if the session is active and for how long before fetching
        let oldToken = NetworkVars.pwgToken
        PwgSession.shared.sessionGetStatus { username in
            if #available(iOSApplicationExtension 14.0, *) {
                logger.notice("Expected user: \(NetworkVars.username, privacy: .private(mask: .hash))")
                logger.notice("Current user: \(username, privacy: .private(mask: .hash))")
                logger.notice("Old token: \(oldToken, privacy: .private(mask: .hash))")
                logger.notice("New token: \(NetworkVars.pwgToken, privacy: .private(mask: .hash))")
            }
            if username != NetworkVars.username || oldToken.isEmpty || NetworkVars.pwgToken != oldToken {
                let dateOfLogin = Date.timeIntervalSinceReferenceDate
                // Collect list of methods supplied by Piwigo server
                // => Determine if Community extension 2.9a or later is installed and active
                requestServerMethods {
                    // Known methods, perform re-login
                    // Don't use userStatus as it may not be known after Core Data migration
                    if NetworkVars.username.isEmpty || NetworkVars.username.lowercased() == "guest" {
                        if #available(iOSApplicationExtension 14.0, *) {
                            logger.notice("Session opened for Guest")
                        }
                        // Session now opened
                        getPiwigoConfig {
                            // Update date of accesss to the server by guest
                            user?.lastUsed = dateOfLogin
                            user?.server?.lastUsed = dateOfLogin
                            user?.status = NetworkVars.userStatus.rawValue
                            completion()
                        } failure: { error in
                            failure(error)
                        }
                    } else {
                        // Perform login
                        let username = NetworkVars.username
                        let password = KeychainUtilities.password(forService: NetworkVars.serverPath, account: username)
                        if #available(iOSApplicationExtension 14.0, *) {
                            logger.notice("Create session for \(username, privacy: .private(mask: .hash))")
                        }
                        PwgSession.shared.sessionLogin(withUsername: username, password: password) {
                            // Session now opened
                            getPiwigoConfig {
                                // Update date of accesss to the server by user
                                user?.lastUsed = dateOfLogin
                                user?.server?.lastUsed = dateOfLogin
                                user?.status = NetworkVars.userStatus.rawValue
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
                completion()
            }
        } failure: { error in
            failure(error)
        }
    }
    
    static func getPiwigoConfig(completion: @escaping () -> Void,
                                failure: @escaping (NSError) -> Void) {
        // Check Piwigo version, get token, available sizes, etc.
        if NetworkVars.usesCommunityPluginV29 {
            PwgSession.shared.communityGetStatus {
                PwgSession.shared.sessionGetStatus { _ in
                    completion()
                } failure: { error in
                    failure(error)
                }
            } failure: { error in
                failure(error)
            }
        } else {
            PwgSession.shared.sessionGetStatus { _ in
                completion()
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
        let serverEncoding = String.Encoding(rawValue: NetworkVars.stringEncoding )
        if let strData = strToConvert.data(using: serverEncoding, allowLossyConversion: true) {
            return String(data: strData, encoding: .utf8) ?? strToConvert
        }
        return ""
    }

    // Piwigo supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
    // See https://github.com/Piwigo/Piwigo-Mobile/issues/429, https://github.com/Piwigo/Piwigo/issues/750
    public static
    func utf8mb3String(from string: String?) -> String {
        // Return empty string is nothing provided
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
    func encodedImageURL(_ originalURL:String?) -> NSURL? {
        // Return nil if originalURL is nil and a placeholder will be used
        guard let okURL = originalURL else { return nil }
        
        // TEMPORARY PATCH for case where $conf['original_url_protection'] = 'images';
        /// See https://github.com/Piwigo/Piwigo-Mobile/issues/503
        let patchedURL = okURL.replacingOccurrences(of: "&amp;part=", with: "&part=")
        var serverURL: NSURL? = NSURL(string: patchedURL)
        
        // Servers may return incorrect URLs
        // See https://tools.ietf.org/html/rfc3986#section-2
        if serverURL == nil {
            // URL not RFC compliant!
            var leftURL = patchedURL

            // Remove protocol header
            if patchedURL.hasPrefix("http://") { leftURL.removeFirst(7) }
            if patchedURL.hasPrefix("https://") { leftURL.removeFirst(8) }
            
            // Retrieve authority
            guard let endAuthority = leftURL.firstIndex(of: "/") else {
                // No path, incomplete URL —> return image.jpg but should never happen
                return nil
            }
            let authority = String(leftURL.prefix(upTo: endAuthority))
            leftURL.removeFirst(authority.count)

            // The Piwigo server may not be in the root e.g. example.com/piwigo/…
            // So we remove the path to avoid a duplicate if necessary
            if let loginURL = URL(string: NetworkVars.service),
               loginURL.path.count > 0, leftURL.hasPrefix(loginURL.path) {
                leftURL.removeFirst(loginURL.path.count)
            }

            // Retrieve path
            if let endQuery = leftURL.firstIndex(of: "?") {
                // URL contains a query
                let query = (String(leftURL.prefix(upTo: endQuery)) + "?").replacingOccurrences(of: "??", with: "?")
                guard let newQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                    // Could not apply percent encoding —> return image.jpg but should never happen
                    return nil
                }
                leftURL.removeFirst(query.count)
                guard let newPath = leftURL.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
                    // Could not apply percent encoding —> return image.jpg but should never happen
                    return nil
                }
                serverURL = NSURL(string: NetworkVars.service + newQuery + newPath)
            } else {
                // No query -> remaining string is a path
                let newPath = String(leftURL.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!)
                serverURL = NSURL(string: NetworkVars.service + newPath)
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
        var loginPath = NetworkVars.service
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
        if encodedImageURL != originalURL {
            print("=> originalURL:\(String(describing: originalURL))")
            print("    encodedURL:\(encodedImageURL)")
            print("    path=\(String(describing: serverURL?.path)), parameterString=\(String(describing: serverURL?.parameterString)), query:\(String(describing: serverURL?.query)), fragment:\(String(describing: serverURL?.fragment))")
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
