//
//  PwgSession+Utilities.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 08/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import os
import CoreData
import Foundation
import UIKit

extension PwgSession {
    // MARK: Session Management
    public static
    func requestServerMethods(completion: @escaping () -> Void,
                              didRejectCertificate: @escaping (PwgKitError) -> Void,
                              didFailHTTPauthentication: @escaping (PwgKitError) -> Void,
                              didFailSecureConnection: @escaping (PwgKitError) -> Void,
                              failure: @escaping (PwgKitError) -> Void) {
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
            if error.failedAuthentication || NetworkVars.shared.didFailHTTPauthentication {
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
                      failure: @escaping (PwgKitError) -> Void) {
        
        // Check if the session is still active and update the server status
        // every 60 seconds or more
        let secondsSinceLastCheck = Date.timeIntervalSinceReferenceDate - (user?.lastUsed ?? 0.0)
        if PwgSession.shared.hasNetworkConnectionChanged == false,
           NetworkVars.shared.applicationShouldRelogin == false,
           secondsSinceLastCheck < 60 {
            completion()
            return
        }
        
        // Determine if the session is still active
        PwgSession.shared.hasNetworkConnectionChanged = false
        logger.notice("Session: starting checking… \(NetworkVars.shared.isConnectedToWiFi ? "WiFi" : "Cellular")")
        let oldToken = NetworkVars.shared.pwgToken
        PwgSession.shared.sessionGetStatus { pwgUser in
#if DEBUG
            logger.notice("Session: \"\(NetworkVars.shared.user, privacy: .public)\" vs \"\(pwgUser, privacy: .public)\", \"\(oldToken, privacy: .public)\" vs \"\(NetworkVars.shared.pwgToken, privacy: .public)\"")
#else
            logger.notice("Session: \"\(NetworkVars.shared.user, privacy: .private(mask: .hash))\" vs \"\(pwgUser, privacy: .private(mask: .hash))\", \"\(oldToken, privacy: .private(mask: .hash))\" vs \"\(NetworkVars.shared.pwgToken, privacy: .private(mask: .hash))\"")
#endif
            if pwgUser != NetworkVars.shared.user || oldToken.isEmpty || NetworkVars.shared.pwgToken != oldToken {
                // Collect list of methods supplied by Piwigo server
                // => Determine if Community extension 2.9a or later is installed and active
                requestServerMethods {
                    // Known methods, perform re-login
                    // Don't use userStatus as it may not be known after Core Data migration
                    if NetworkVars.shared.username.isEmpty || NetworkVars.shared.username.lowercased() == "guest" {
                        logger.notice("Session: logged as Guest")
                        // Session now opened
                        getPiwigoConfig(forUser: user) {
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
#if DEBUG
                            logger.notice("Session: logged as \(NetworkVars.shared.username, privacy: .public)")
#else
                            logger.notice("Session: logged as \(NetworkVars.shared.username, privacy: .private(mask: .hash))")
#endif
                            // Session now opened
                            getPiwigoConfig(forUser: user) {
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
    
    fileprivate static
    func getPiwigoConfig(forUser user: User?,
                         completion: @escaping () -> Void,
                         failure: @escaping (PwgKitError) -> Void) {
        // Check Piwigo version, get token, available sizes, etc.
        if NetworkVars.shared.usesCommunityPluginV29 {
            PwgSession.shared.communityGetStatus {
                getPiwigoStatus(forUser: user, completion: completion, failure: failure)
            }
            failure: { error in
                failure(error)
            }
        } else {
            getPiwigoStatus(forUser: user, completion: completion, failure: failure)
        }
    }
    
    fileprivate static
    func getPiwigoStatus(forUser user: User?,
                         completion: @escaping () -> Void,
                         failure: @escaping (PwgKitError) -> Void)
    {
        PwgSession.shared.sessionGetStatus { userName in
            // Set Piwigo user
            NetworkVars.shared.user = userName
            
            // Are cached data associated to an API public key?
            if NetworkVars.shared.fixUserIsAPIKeyV412, let userID = user?.objectID {
                DispatchQueue.global(qos: .background).async {
                    // Attribute upload requests to appropriate user if necessary
                    logger.debug("Session: attributing API Key upload requests to user…")
                    UploadProvider.shared.attributeAPIKeyUploadRequests(toUserWithID: userID)
                    
                    // Delete API Key user (and albums in cascade)
                    logger.debug("Session: deleting API Key user…")
                    UserProvider.shared.deleteUser(withName: NetworkVars.shared.username)
                    
                    // Job completed
                    logger.debug("Session: API Key user deleted")
                    NetworkVars.shared.fixUserIsAPIKeyV412 = false
                    
                    // Try to resume upload requests if the low power mode is not enabled
                    let name = Notification.Name.NSProcessInfoPowerStateDidChange
                    NotificationCenter.default.post(name: name, object: nil)
                }
            }
            
            // Pursue logging in without waiting for the fix to complete
            completion()
        }
        failure: { error in
            failure(error)
        }
    }
    
    
    // MARK: - Clean URLs of Images
    public static
    func encodedImageURL(_ originalURL: String?) -> NSURL? {
        // Return nil if originalURL is nil or empty
        guard let okURL = originalURL, !okURL.isEmpty else { return nil }
        
        // TEMPORARY PATCH for case where $conf['original_url_protection'] = 'images' or 'all';
        /// See https://github.com/Piwigo/Piwigo-Mobile/issues/503
        /// Seems not to be an issue with all servers or since iOS 17 or 18.
        var patchedURL = ""
        if #available(iOS 16.0, *) {
            patchedURL = okURL.replacing("&amp;part=", with: "&part=")
                              .replacing("&amp;pwg_token=", with: "&pwg_token=")
                              .replacing("&amp;download", with: "&download")
                              .replacing("&amp;filter_image_id=", with: "&filter_image_id=")
                              .replacing("&amp;sync_metadata=1", with: "&sync_metadata=1")
        } else {
            // Fallback on earlier versions
            patchedURL = okURL.replacingOccurrences(of: "&amp;part=", with: "&part=")
                              .replacingOccurrences(of: "&amp;pwg_token=", with: "&pwg_token=")
                              .replacingOccurrences(of: "&amp;download", with: "&download")
                              .replacingOccurrences(of: "&amp;filter_image_id=", with: "&filter_image_id=")
                              .replacingOccurrences(of: "&amp;sync_metadata=1", with: "&sync_metadata=1")
        }
        var serverComponents: URLComponents
        
        if let components = URLComponents(string: patchedURL) {
            serverComponents = components
        } else {
            // URL not RFC compliant! - Try to fix it manually
            PwgSession.logger.notice("Received invalid URL: \(originalURL ?? "", privacy: .public)")
            
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
        if let originalURL = originalURL,
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


// MARK: - API Key Management
extension String
{
    public
    func isValidPublicKey() -> Bool {
        if #available(iOS 16.0, *) {
            let pattern = /^pkid-\d{8}-[a-z0-9]{20}$/
            return self.wholeMatch(of: pattern.ignoresCase()) != nil
        } else {
            // Fallback on previous version
            let pattern = "^pkid-\\d{8}-[a-z0-9]{20}$"
            return self.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }
}

extension URLRequest
{
    public mutating
    func setAPIKeyHTTPHeader(for method: String) {
        // Piwigo server managing API keys
        // and method not prohibited with API keys?
        guard NetworkVars.shared.usesAPIkeys,
              NetworkVars.shared.apiKeysProhibitedMethods.contains(method) == false
        else { return }
        
        // API key available?
        let publicKey = NetworkVars.shared.username
        guard publicKey.isValidPublicKey()
        else { return }
        
        // Set HTTP header from keys
        let secretKey = KeychainUtilities.password(forService: NetworkVars.shared.serverPath,
                                                   account: NetworkVars.shared.username)
        setValue("\(publicKey):\(secretKey)", forHTTPHeaderField: HTTPAPIKey)
    }
}
