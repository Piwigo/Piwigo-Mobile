//
//  NetworkUtilities.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 08/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

public class NetworkUtilities: NSObject {
    
    // MARK: - UTF-8 encoding on 3 and 4 bytes
    public class
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
    public class
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
    public class
    func encodedImageURL(_ originalURL:String?) -> String? {
        // Return nil if originalURL is nil and a placeholder will be used
        guard let okURL = originalURL else { return nil }
        
        // Servers may return incorrect URLs
        // See https://tools.ietf.org/html/rfc3986#section-2
        var serverURL = NSURL(string: okURL)
        if serverURL == nil {
            // URL not RFC compliant!
            var leftURL = okURL

            // Remove protocol header
            if okURL.hasPrefix("http://") { leftURL.removeFirst(7) }
            if okURL.hasPrefix("https://") { leftURL.removeFirst(8) }
            
            // Retrieve authority
            guard let range1 = leftURL.range(of: "/") else {
                // No path, incomplete URL —> return image.jpg but should never happen
                return "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)/image.jpg"
            }
            let authority = String(leftURL.prefix(upTo: range1.upperBound))
            leftURL.removeFirst(authority.count - 1)

            // The Piwigo server may not be in the root e.g. example.com/piwigo/…
            // So we remove the path to avoid a duplicate if necessary
            if let loginURL = URL(string: "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)"),
               loginURL.path.count > 0, leftURL.hasPrefix(loginURL.path) {
                leftURL.removeFirst(loginURL.path.count)
            }

            // Retrieve path
            if let range2 = leftURL.range(of: "?") {
                // URL seems to contain a query
                let path = String(leftURL.prefix(upTo: range2.upperBound)) + "?"
                guard let finalPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
                    // Could not apply percent encoding —> return image.jpg but should never happen
                    return "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)/image.jpg"
                }
                leftURL.removeFirst(path.count)
                guard let leftURL = leftURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                    // Could not apply percent encoding —> return image.jpg but should never happen
                    return "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)/image.jpg"
                }
                serverURL = NSURL(string: "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)\(finalPath)\(leftURL)")
            } else {
                // No query -> remaining string is a path
                let finalPath = String(leftURL.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!)
                serverURL = NSURL(string: "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)\(finalPath)")
            }
            
            // Last check
            if serverURL == nil {
                // Could not apply percent encoding —> return image.jpg but should never happen
                return "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)/image.jpg"
            }
        }
        
        // Servers may return image URLs different from those used to login (e.g. wrong server settings)
        // We only keep the path+query because we only accept to download images from the same server.
        guard var cleanPath = serverURL?.path else {
            return "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)/image.jpg"
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
        // So we remove the path to avoid a duplicate if necessary
        if let loginURL = URL(string: "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)"),
           loginURL.path.count > 0, cleanPath.hasPrefix(loginURL.path) {
            cleanPath.removeFirst(loginURL.path.count)
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
        let encodedImageURL = "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)\(prefix)\(cleanPath)"
        #if DEBUG
        if encodedImageURL != originalURL {
            print("=> originalURL:\(String(describing: originalURL))")
            print("    encodedURL:\(encodedImageURL)")
            print("    path=\(String(describing: serverURL?.path)), parameterString=\(String(describing: serverURL?.parameterString)), query:\(String(describing: serverURL?.query)), fragment:\(String(describing: serverURL?.fragment))")
        }
        #endif
        return encodedImageURL;
    }
}

