//
//  String+AppTools.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 26/03/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

extension String {

    // MARK: - Passcode Encryption
    func encrypted() -> String {
        let encoded = (Int64(self)! + Int64(2323)) * Int64(7777) + Int64(3141592657)
        let key = String(encoded, radix: 23, uppercase: true)
        return String(repeating: "0", count: max(0, 8 - key.count)) + key
    }

    func decrypted() -> String {
        guard let key = Int64(self, radix: 23) else {
            // No known passscode -> empty string
            return ""
        }
        let decoded = String(((key - Int64(3141592657)) / Int64(7777)) - Int64(2323))
        return String(repeating: "0", count: max(0, 6 - decoded.count)) + decoded
    }
    
    // MARK: - HTML conversion
    var htmlToAttributedString: NSAttributedString {

        // Remove any white space or newline located at the beginning or end of the description
        var comment = self
        while comment.count > 0, comment.first!.isNewline || comment.first!.isWhitespace {
            comment.removeFirst()
        }
        while comment.count > 0, comment.last!.isNewline || comment.last!.isWhitespace  {
            comment.removeLast()
        }

        // Convert HTML code
        guard let data = comment.data(using: .utf8) else { return NSAttributedString(string: "") }
        do {
            let attributedStr = try NSMutableAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding:String.Encoding.utf8.rawValue], documentAttributes: nil)
            let wholeRange = NSRange(location: 0, length: attributedStr.string.count)
            attributedStr.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: wholeRange)
            let style = NSMutableParagraphStyle()
            style.alignment = NSTextAlignment.center
            attributedStr.addAttribute(.paragraphStyle, value: style, range: wholeRange)
            
            // Removes superfluous line feed
            while !attributedStr.string.isEmpty
                    && CharacterSet.newlines.contains(attributedStr.string.unicodeScalars.last!) {
                attributedStr.deleteCharacters(in: NSRange(location: attributedStr.length - 1, length: 1))
            }
            return attributedStr
        } catch {
            return NSAttributedString(string: self)
        }
    }
    
    var htmlToString: String {
        return htmlToAttributedString.string
    }
}
