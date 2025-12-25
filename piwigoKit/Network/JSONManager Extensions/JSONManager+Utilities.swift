//
//  JSONManager+Utilities.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 08/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import os
import CoreData
import Foundation
import UIKit

extension JSONManager {
    
    // MARK: Piwigo Session Management
    // Re-login if session was closed
    @concurrent
    public func checkSession(ofUserWithID objectID: NSManagedObjectID,
                             lastConnected lastUsed: TimeInterval) async throws(PwgKitError) {
                
        // Check if the session is still active and update the server status
        // every 60 seconds or more
        let secondsSinceLastCheck = Date.timeIntervalSinceReferenceDate - lastUsed
        if NetworkVars.shared.hasNetworkConnectionChanged == false,
           NetworkVars.shared.applicationShouldRelogin == false,
           secondsSinceLastCheck < 60 {
            return
        }
        
        // Determine if the session is still active
        NetworkVars.shared.hasNetworkConnectionChanged = false
        JSONManager.logger.notice("Session: starting checking… \(NetworkVars.shared.isConnectedToWiFi ? "WiFi" : "Cellular")")
        let oldToken = NetworkVars.shared.pwgToken
        let pwgUser = try await JSONManager.shared.sessionGetStatus()
#if DEBUG
        JSONManager.logger.notice("Session: \"\(NetworkVars.shared.user, privacy: .public)\" vs \"\(pwgUser, privacy: .public)\", \"\(oldToken, privacy: .public)\" vs \"\(NetworkVars.shared.pwgToken, privacy: .public)\"")
#else
        JSONManager.shared.logger.notice("Session: \"\(NetworkVars.shared.user, privacy: .private(mask: .hash))\" vs \"\(pwgUser, privacy: .private(mask: .hash))\", \"\(oldToken, privacy: .private(mask: .hash))\" vs \"\(NetworkVars.shared.pwgToken, privacy: .private(mask: .hash))\"")
#endif
        if pwgUser != NetworkVars.shared.user || oldToken.isEmpty || NetworkVars.shared.pwgToken != oldToken {
            // Collect list of methods supplied by Piwigo server
            // => Determine if Community extension 2.9a or later is installed and active
            try await getMethods()
            
            // Known methods, perform re-login
            // Don't use userStatus as it may not be known after Core Data migration
            if NetworkVars.shared.username.isEmpty || NetworkVars.shared.username.lowercased() == "guest" {
                
                // Session opened for guest
                JSONManager.logger.notice("Session: logged as Guest")
                try await getPiwigoConfigForUser(withID: objectID)
                
                // Update date of accesss to the server by guest
                updateUser(withID: objectID, includingStatus: true)
                NetworkVars.shared.applicationShouldRelogin = false
            }
            else {
                // Perform login
                let username = NetworkVars.shared.username
                let password = KeychainUtilities.password(forService: NetworkVars.shared.serverPath, account: username)
                try await sessionLogin(withUsername: username, password: password)
#if DEBUG
                JSONManager.logger.notice("Session: logged as \(NetworkVars.shared.username, privacy: .public)")
#else
                JSONManager.logger.notice("Session: logged as \(NetworkVars.shared.username, privacy: .private(mask: .hash))")
#endif
                // Session now opened
                try await getPiwigoConfigForUser(withID: objectID)
                
                // Update date of accesss to the server by guest
                updateUser(withID: objectID, includingStatus: true)
                NetworkVars.shared.applicationShouldRelogin = false
            }
        }
        else {
            updateUser(withID: objectID, includingStatus: false)
        }
    }
    
    fileprivate func updateUser(withID objectID: NSManagedObjectID, includingStatus status: Bool) {
        let bckgContext = DataController.shared.newTaskContext()
        UserProvider().updateUser(withID: objectID,status: status, inContext: bckgContext)
    }
    
    fileprivate func getPiwigoConfigForUser(withID objectID: NSManagedObjectID) async throws(PwgKitError) {
        // Check Piwigo version, get token, available sizes, etc.
        if NetworkVars.shared.usesCommunityPluginV29 {
            try await JSONManager.shared.communityGetStatus()
        }
        try await getPiwigoStatusForUser(withID: objectID)
    }
    
    fileprivate func getPiwigoStatusForUser(withID objectID: NSManagedObjectID) async throws(PwgKitError)
    {
        // Retrieve the username
        let userName = try await JSONManager.shared.sessionGetStatus()
        
        // Set Piwigo user
        NetworkVars.shared.user = userName
        
        // Are cached data associated to an API public key?
        // (pursue logging in without waiting for the fix to complete)
        if NetworkVars.shared.fixUserIsAPIKeyV412 {
            DispatchQueue.global(qos: .background).async {
                // Retrieve background context
                let bckgContext = DataController.shared.newTaskContext()
                
                // Attribute upload requests to appropriate user if necessary
                JSONManager.logger.debug("Session: attributing API Key upload requests to user…")
                UploadProvider().attributeAPIKeyUploadRequests(toUserWithID: objectID,
                                                               inContext: bckgContext)
                
                // Delete API Key user (and albums in cascade)
                JSONManager.logger.debug("Session: deleting API Key user…")
                UserProvider().deleteUser(withUsername: NetworkVars.shared.username,
                                          inContext: bckgContext)
                
                // Job completed
                JSONManager.logger.debug("Session: API Key user deleted")
                NetworkVars.shared.fixUserIsAPIKeyV412 = false
                
                // Try to resume upload requests if the low power mode is not enabled
                let name = Notification.Name.NSProcessInfoPowerStateDidChange
                NotificationCenter.default.post(name: name, object: nil)
            }
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
            JSONManager.logger.notice("Received invalid URL: \(originalURL ?? "", privacy: .public)")
            
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
            JSONManager.logger.notice("Invalid URL \"\(originalURL, privacy: .public)\" replaced by \(finalURL.absoluteString, privacy: .public)")
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
