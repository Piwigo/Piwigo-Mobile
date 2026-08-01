//
//  String+AppTools.swift
//  PwgKit
//
//  Created by Eddy Lelièvre-Berna on 25/12/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

extension String
{
    // MARK: - UTF-8 encoding on 3 and 4 bytes
    public var utf8mb4Encoded: String {
        // Return empty string if nothing provided
        guard self.isEmpty == false
        else { return "" }
        
        // Convert string to UTF-8 encoding
        let serverEncoding = String.Encoding(rawValue: ServerVars.shared.stringEncoding )
        if let strData = self.data(using: serverEncoding, allowLossyConversion: true) {
            return String(data: strData, encoding: .utf8) ?? self
        }
        return ""
    }
    
    public var utf8mb3Encoded: String {
        // Return empty string if nothing provided
        guard self.isEmpty == false
        else { return "" }
        
        // Replace characters encoded on 4 bytes
        var utf8mb3String = ""
        for char in self {
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
