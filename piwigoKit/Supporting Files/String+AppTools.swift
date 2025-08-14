//
//  String+AppTools.swift
//  piwigoKit
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
        let serverEncoding = String.Encoding(rawValue: NetworkVars.shared.stringEncoding )
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

    
    // MARK: - HTML Conversion
    public var attributedPlain: NSAttributedString {
        // Remove any white space or newline located at the beginning or end
        // and then spaces located at the beginning or end of each line
        let trimmedText = self.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .map({ $0.trimmingCharacters(in: .whitespaces) })
            .joined(separator: "\n")

        // Check provided string
        guard trimmedText.isEmpty == false
        else { return NSAttributedString() }

        // Return attributed string
        return NSAttributedString(string: trimmedText)
    }

    public func containsHTML() -> Bool {
        let lowerCaseText = self.lowercased()
        if lowerCaseText.hasPrefix("<!doctype html") ||
            lowerCaseText.hasPrefix("<html") ||
            (lowerCaseText.contains("<html") && lowerCaseText.contains("</html>")) {
            return true
        }
        return false
    }
    
    public func attributedHTML() -> NSAttributedString {
        // Remove any white space or newline located at the beginning or end
        let trimmedText = self.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check provided string
        guard trimmedText.isEmpty == false
        else { return NSAttributedString() }
        
        // Detect if its contains HTML text
        guard trimmedText.containsHTML()
        else { return NSAttributedString() }
        
        // Decode HTML code if possible
        guard let data = trimmedText.data(using: .utf8)
        else { return NSAttributedString() }
        do {
            let options: [NSAttributedString.DocumentReadingOptionKey : Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
            let attributedHTML = try NSMutableAttributedString(data: data, options: options, documentAttributes: nil)
            
            // Replace default HTML font if not specified
            if trimmedText.contains("font-family") == false {
                let systemFont = UIFont.systemFont(ofSize: UIFont.systemFontSize, weight: .regular)
                let wholeRange = NSRange(location: 0, length: attributedHTML.length)
                attributedHTML.enumerateAttribute(.font, in: wholeRange) { font, range, _ in
                    if let currentFont = font as? UIFont {
                        // Preserve bold and italic traits
                        var traits: UIFontDescriptor.SymbolicTraits = []
                        if currentFont.fontDescriptor.symbolicTraits.contains(.traitBold) {
                            traits.insert(.traitBold)
                        }
                        if currentFont.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                            traits.insert(.traitItalic)
                        }
                        // Preserve font size
                        let newFontDescriptor = systemFont.fontDescriptor.withSymbolicTraits(traits) ?? systemFont.fontDescriptor
                        let replacementFont = UIFont(descriptor: newFontDescriptor, size: currentFont.pointSize)
                        // Apply font
                        attributedHTML.addAttribute(.font, value: replacementFont, range: range)
                    }
                }
            }
            
            // Removes superfluous line feed
            while !attributedHTML.string.isEmpty
                    && CharacterSet.newlines.contains(attributedHTML.string.unicodeScalars.last!) {
                attributedHTML.deleteCharacters(in: NSRange(location: attributedHTML.length - 1, length: 1))
            }
            return attributedHTML
        }
        catch {
            // Could not decode data as HTML code
            return NSAttributedString()
        }
    }
}
