//
//  Data+AppTools.swift
//  PwgAPIKit
//
//  Created by Eddy Lelièvre-Berna on 06/02/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import CryptoKit
import PwgKit

public let JSONprefix = "JSON "
public let JSONextension = ".txt"

extension Data
{
    // MARK: - Piwgo Response Checker
    public mutating func extractingBalancedBraces() -> Bool {
        // Get data as string
        let dataStr = String(decoding: self, as: UTF8.self)

        // Look for the first opening brace
        guard let firstBrace = dataStr.firstIndex(of: "{")
        else { return false }
        
        var braceCount = 0
        var endIndex: String.Index?
        
        for (index, char) in dataStr[firstBrace...].enumerated() {
            let currentIndex = dataStr.index(firstBrace, offsetBy: index)
            
            if char == "{" {
                braceCount += 1
            } else if char == "}" {
                braceCount -= 1
                if braceCount == 0 {
                    endIndex = dataStr.index(after: currentIndex)
                    break
                }
            }
        }
        
        if let end = endIndex {
            let filteredDataStr = String(dataStr[firstBrace..<end])
            if let filteredData = filteredDataStr.data(using: String.Encoding.utf8) {
                self = filteredData
                return true
            }
        }
        
        return false
    }


    // MARK: - Piwgo Response Checker
    func saveInvalidJSON(for method: String) {
        // Prepare file name from current date (UTC time)
        let fileName = JSONprefix + DateUtilities.logsDateFormatter.string(from: Date()) + " " + method + JSONextension
        
        // Logs are saved in the /tmp directory and will be deleted:
        // - by the app if the user kills it
        // - by the system after a certain amount of time
        let filePath = NSTemporaryDirectory().appending(fileName)
        if FileManager.default.fileExists(atPath: filePath) {
            try? FileManager.default.removeItem(atPath: filePath)
        }
        FileManager.default.createFile(atPath: filePath, contents: self)
    }
}
