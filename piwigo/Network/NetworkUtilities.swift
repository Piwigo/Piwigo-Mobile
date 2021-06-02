//
//  NetworkUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 29/12/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

@objc
class NetworkUtilities: NSObject {
    
    @objc
    class func utf8mb4String(from string: String?) -> String? {
        // Return empty string is nothing provided
        guard let strToConvert = string else {
            return ""
        }
        // Convert string to UTF-8 encoding
        let serverEncoding = String.Encoding(rawValue: NetworkVars.shared.stringEncoding )
        if let strData = strToConvert.data(using: serverEncoding, allowLossyConversion: true) {
            return String(data: strData, encoding: .utf8)
        }
        return ""
    }

    // Piwigo supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
    // See https://github.com/Piwigo/Piwigo-Mobile/issues/429, https://github.com/Piwigo/Piwigo/issues/750
    @objc
    class func utf8mb3String(from string: String?) -> String? {
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
