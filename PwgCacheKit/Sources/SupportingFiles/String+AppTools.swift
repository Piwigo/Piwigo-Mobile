//
//  String+AppTools.swift
//  PwgCacheKit
//
//  Created by Eddy Lelièvre-Berna on 25/12/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

extension String
{
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
    
    public var containsHTML: Bool {
        let lowerCaseText = self.lowercased()
        if lowerCaseText.hasPrefix("<!doctype html") ||
            lowerCaseText.hasPrefix("<html") ||
            (lowerCaseText.contains("<html") && lowerCaseText.contains("</html>")) {
            return true
        }
        return false
    }
    
    public var attributedHTML: NSAttributedString {
        // Remove any white space or newline located at the beginning or end
        let trimmedText = self.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check provided string
        guard trimmedText.isEmpty == false
        else { return NSAttributedString() }
        
        // Detect if its contains HTML text
        guard trimmedText.containsHTML
        else { return NSAttributedString() }
        
        // Convert string to data
        guard let data = trimmedText.data(using: .utf8)
        else { return NSAttributedString() }
        
        // Decode HTML if possible
        let options: [NSAttributedString.DocumentReadingOptionKey : Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        guard let attributed = try? NSMutableAttributedString(
            data: data, options: options, documentAttributes: nil)
        else { return NSAttributedString() }
        
        // Replace default HTML font if not specified
        if trimmedText.contains("font-family") == false {
            let systemFont = UIFont.preferredFont(forTextStyle: .body)
            let wholeRange = NSRange(location: 0, length: attributed.length)
            attributed.enumerateAttribute(.font, in: wholeRange) { font, range, _ in
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
                    attributed.addAttribute(.font, value: replacementFont, range: range)
                }
            }
        }

        // Removes superfluous line feed
        while !attributed.string.isEmpty
                && CharacterSet.newlines.contains(attributed.string.unicodeScalars.last!) {
            attributed.deleteCharacters(in: NSRange(location: attributed.length - 1, length: 1))
        }

        return attributed
    }
}
