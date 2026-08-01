//
//  ImageGetInfo.swift
//  PwgCacheKit
//
//  Created by Eddy Lelièvre-Berna on 17/05/2026.
//

import Foundation
import PwgKit

extension ImageGetInfo {
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
            debugPrint("Received invalid URL: \(originalURL ?? "")")
            guard let fixedComponents = fixInvalidURL(patchedURL) else {
                return nil
            }
            serverComponents = fixedComponents
        }
        
        // Servers may return image URLs different from those used to login
        // We only accept downloads from the same server, so reconstruct with login service
        guard let loginComponents = URLComponents(string: ServerVars.shared.service) else {
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
            debugPrint("Invalid URL \"\(originalURL)\" replaced by \(finalURL.absoluteString)")
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
        if let loginURL = URL(string: ServerVars.shared.service),
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
